import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:record/record.dart';

import 'domain/prompt_builder.dart';
import 'domain/transcript_turn.dart';
import 'l10n.dart';
import 'services/config_store.dart';
import 'services/deepgram_stream.dart';
import 'services/history_store.dart';
import 'services/hotkey_service.dart';
import 'services/llm_service.dart';
import 'services/window_service.dart';

export 'domain/transcript_turn.dart';

enum SessionStatus { idle, connecting, listening, error }

/// Результат разбора импортированного файла истории
class ImportedChatResult {
  const ImportedChatResult({
    required this.turns,
    this.conversationSummary = '',
    this.summarizedUpToTurn = 0,
  });

  final List<TranscriptTurn> turns;
  final String conversationSummary;
  final int summarizedUpToTurn;
}

class Session extends ChangeNotifier {
  AppConfig config = AppConfig();

  SessionStatus status = SessionStatus.idle;
  String? statusMessage;

  final List<TranscriptTurn> turns = [];
  String interimMe = '';
  String interimThem = '';

  /// Сжатое резюме предыдущей части диалога (для предотвращения переполнения контекста)
  String conversationSummary = '';

  /// Индекс реплики (в turns), до которой диалог уже вошёл в conversationSummary
  int summarizedUpToTurn = 0;

  /// Флаг фонового процесса сжатия истории
  bool isCompressing = false;

  Timer? _compressDebounce;

  bool helpLoading = false;
  String? helpAnswer;
  String? helpError;
  StreamSubscription<String>? _helpSub;
  http.Client? _activeHelpClient;

  /// Закреплённые скриншоты в каретке для мульти-анализа задачи/кода.
  final List<Uint8List> pendingScreenshots = [];

  /// Флаг процесса захвата скриншота экрана (защита от дребезга кликов).
  bool isCapturingScreenshot = false;

  /// История предыдущих раундов подсказок (многоходовой диалог для уточнений и исправлений).
  final List<LlmMessage> llmHistory = [];

  /// Сбросить контекст уточнений LLM (начать новую задачу с чистого листа).
  void resetLlmHistory() {
    if (llmHistory.isNotEmpty) {
      llmHistory.clear();
      notifyListeners();
    }
  }

  /// Статус второго потока (голос собеседника).
  String? themError;
  bool get themActive => _themStream != null;

  AudioRecorder? _recorder;
  AudioRecorder? _themRecorder;
  Socket? _remoteSocket;
  Process? _remoteAudioProcess;
  DeepgramStream? _micStream;
  DeepgramStream? _themStream;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<dynamic>? _themAudioSub;
  final _eventSubs = <StreamSubscription<dynamic>>[];

  static const int maxTranscriptTurns = 200;

  List<InputDevice> audioDevices = [];

  bool get isStreaming =>
      status == SessionStatus.connecting || status == SessionStatus.listening;

  /// Число символов в старых репликах, ожидающих компрессии
  int get unsummarizedChars {
    final keep = config.compressKeepRecentTurns.clamp(4, 50);
    final eligibleEnd = turns.length - keep;
    if (eligibleEnd <= summarizedUpToTurn) return 0;
    var total = 0;
    for (var i = summarizedUpToTurn; i < eligibleEnd; i++) {
      total += turns[i].text.length;
    }
    return total;
  }

  /// Нужно ли запускать автоматическую компрессию диалога
  bool get shouldCompress {
    if (!config.autoCompressContext) return false;
    if (isCompressing) return false;
    final keep = config.compressKeepRecentTurns.clamp(4, 50);
    if (turns.length <= keep) return false;
    return unsummarizedChars >= config.compressThresholdChars;
  }

  void _scheduleAutoCompress() {
    if (!config.autoCompressContext) return;
    if (!shouldCompress) return;
    _compressDebounce?.cancel();
    _compressDebounce = Timer(const Duration(milliseconds: 1500), () {
      compressHistoryNow();
    });
  }

  /// Запуск компрессии накопленного диалога.
  /// При [force] == true сжимает все реплики старше keepRecent, даже если порог символов ещё не достигнут.
  Future<bool> compressHistoryNow({bool force = false}) async {
    if (isCompressing) return false;
    final keep = config.compressKeepRecentTurns.clamp(4, 50);
    final eligibleEnd = turns.length - keep;
    if (eligibleEnd <= summarizedUpToTurn) return false;

    final chars = unsummarizedChars;
    if (!force && chars < config.compressThresholdChars) return false;

    final provider = config.provider;
    final apiKey = config.keyFor(provider).trim();
    if (apiKey.isEmpty) return false;

    isCompressing = true;
    notifyListeners();

    try {
      final slice = turns.sublist(summarizedUpToTurn, eligibleEnd);
      final prompt = PromptBuilder.buildCompressionPrompt(
        previousSummary: conversationSummary,
        slice: slice,
      );

      final newSummary = await LlmService.ask(
        provider: provider,
        apiKey: apiKey,
        model: config.modelFor(provider),
        prompt: prompt,
      );

      if (newSummary.trim().isNotEmpty) {
        conversationSummary = newSummary.trim();
        summarizedUpToTurn = eligibleEnd;
        _scheduleSaveHistory();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[COMPRESS] failed: $e');
      return false;
    } finally {
      isCompressing = false;
      notifyListeners();
    }
  }

  /// Сброс только сохранённого резюме компрессии (реплики сохраняются)
  void resetSummary() {
    conversationSummary = '';
    summarizedUpToTurn = 0;
    _scheduleSaveHistory();
    notifyListeners();
  }

  Future<void> loadAudioDevices() async {
    try {
      final rec = AudioRecorder();
      final list = await rec.listInputDevices();
      await rec.dispose();
      audioDevices = list.where(_isUserFacingDevice).toList();
      if (config.remoteMacHost.isNotEmpty) {
        audioDevices.insert(
          0,
          const InputDevice(
            id: '__remote_mac__',
            label: 'Звук с Mac (BlackHole по SSH)',
          ),
        );
      }
      if (config.myDeviceId.isNotEmpty &&
          !audioDevices.any((d) => d.id == config.myDeviceId)) {
        config.myDeviceId = '';
      }
      _ensureDefaultThemDevice();
      notifyListeners();
    } catch (_) {}
  }

  void _ensureDefaultThemDevice() {
    if (config.remoteMacHost.isNotEmpty) {
      config.themDeviceId = '__remote_mac__';
      return;
    }
    final currentThemExists = config.themDeviceId.isNotEmpty &&
        config.themDeviceId != '__sckit__' &&
        audioDevices.any((d) => d.id == config.themDeviceId);
    if (!currentThemExists) {
      InputDevice? virtualDevice;
      for (final d in audioDevices) {
        final l = d.label.toLowerCase();
        final id = d.id.toLowerCase();
        if (l.contains('blackhole') ||
            id.contains('blackhole') ||
            l.contains('cable') ||
            id.contains('cable')) {
          virtualDevice = d;
          break;
        }
      }
      if (virtualDevice != null) {
        config.themDeviceId = virtualDevice.id;
      } else {
        config.themDeviceId = '';
      }
    }
  }

  static bool _isUserFacingDevice(InputDevice d) {
    final l = d.label.toLowerCase();
    final id = d.id.toLowerCase();
    if (l.contains('cadefaultdeviceaggregate') || id.contains('cadefaultdeviceaggregate')) return false;
    if (l.contains('aggregate-') || id.contains('aggregate-')) return false;
    return true;
  }

  Timer? _saveDebounce;

  void _scheduleSaveHistory() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      HistoryStore.saveData(
        turns: turns,
        conversationSummary: conversationSummary,
        summarizedUpToTurn: summarizedUpToTurn,
      );
    });
  }

  Future<void> flushHistory() async {
    _saveDebounce?.cancel();
    await HistoryStore.saveData(
      turns: turns,
      conversationSummary: conversationSummary,
      summarizedUpToTurn: summarizedUpToTurn,
    );
  }

  Future<void> loadConfig() async {
    config = await AppConfig.load();
    S.lang = config.uiLang;
    await loadHistory();
    notifyListeners();
    applyTitlebar();
    await applyWindowSettings();
  }

  Future<void> loadHistory() async {
    try {
      final saved = await HistoryStore.loadData();
      turns.clear();
      turns.addAll(saved.turns);
      conversationSummary = saved.conversationSummary;
      summarizedUpToTurn = saved.summarizedUpToTurn.clamp(0, turns.length);
      notifyListeners();
    } catch (_) {}
  }

  /// Полная очистка текущего чата
  Future<void> clearChat() async {
    _saveDebounce?.cancel();
    _compressDebounce?.cancel();
    turns.clear();
    conversationSummary = '';
    summarizedUpToTurn = 0;
    isCompressing = false;
    interimMe = '';
    interimThem = '';
    resetLlmHistory();
    clearPendingScreenshots();
    await HistoryStore.clear();
    notifyListeners();
  }

  /// Импорт реплик чата (перезаписывает текущую историю)
  Future<void> importChat(
    List<TranscriptTurn> newTurns, {
    String conversationSummary = '',
    int summarizedUpToTurn = 0,
  }) async {
    _saveDebounce?.cancel();
    _compressDebounce?.cancel();
    turns.clear();
    turns.addAll(newTurns);
    if (turns.length > maxTranscriptTurns) {
      turns.removeRange(0, turns.length - maxTranscriptTurns);
    }
    this.conversationSummary = conversationSummary;
    this.summarizedUpToTurn = summarizedUpToTurn.clamp(0, turns.length);
    await flushHistory();
    notifyListeners();
  }

  /// Экспорт текущего чата в форматированный JSON со сводкой
  String exportChatJson() {
    final turnsJson = turns.map((t) => {
      'speaker': t.speaker == Speaker.me ? 'candidate' : 'interviewer',
      'speakerRole': t.speaker.name,
      'timestamp': t.timestamp.toIso8601String(),
      'text': t.text,
    }).toList();

    final plainTextBuffer = StringBuffer();
    for (final t in turns) {
      final h = t.timestamp.hour.toString().padLeft(2, '0');
      final m = t.timestamp.minute.toString().padLeft(2, '0');
      final s = t.timestamp.second.toString().padLeft(2, '0');
      final speakerLabel =
          t.speaker == Speaker.me ? 'Вы (Кандидат)' : 'Собеседник';
      plainTextBuffer.writeln('[$h:$m:$s] $speakerLabel: ${t.text}');
    }

    final exportData = {
      'format': 'tellmemore_dialogue_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'TellMeMore',
      'turnsCount': turns.length,
      'conversationSummary': conversationSummary,
      'summarizedUpToTurn': summarizedUpToTurn,
      'plainTranscript': plainTextBuffer.toString(),
      'turns': turnsJson,
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Полный разбор импортированного файла (включая реплики и резюме компрессии)
  static ImportedChatResult parseImportedChatFull(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const ImportedChatResult(turns: []);
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['turns'] is List) {
        final turns = (decoded['turns'] as List).map((e) {
          final m = e as Map<String, dynamic>;
          final s = (m['speaker'] == 'them' ||
                  m['speakerRole'] == 'them' ||
                  m['speaker'] == 'interviewer')
              ? Speaker.them
              : Speaker.me;
          final text = (m['text'] as String?) ?? '';
          final time = DateTime.tryParse((m['timestamp'] as String?) ?? '') ??
              DateTime.now();
          return TranscriptTurn(speaker: s, text: text, timestamp: time);
        }).where((t) => t.text.trim().isNotEmpty).toList();

        final summary = (decoded['conversationSummary'] as String?) ?? '';
        final upTo = (decoded['summarizedUpToTurn'] as num?)?.toInt() ?? 0;
        return ImportedChatResult(
          turns: turns,
          conversationSummary: summary,
          summarizedUpToTurn: upTo.clamp(0, turns.length),
        );
      } else if (decoded is List) {
        final turns = decoded
            .whereType<Map<String, dynamic>>()
            .map(TranscriptTurn.fromJson)
            .where((t) => t.text.trim().isNotEmpty)
            .toList();
        return ImportedChatResult(turns: turns);
      }
    } catch (_) {}

    // Fallback: построчный парсинг текста
    final lines = trimmed.split('\n');
    final result = <TranscriptTurn>[];
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      var speaker = Speaker.them;
      var text = l;
      final matchMe = RegExp(
              r'(?:^|\]\s*|:\s*)\[?(?:вы(?:\s*\(кандидат\))?|candidate|me)\]?\s*:\s*(.*)',
              caseSensitive: false)
          .firstMatch(l);
      final matchThem = RegExp(
              r'(?:^|\]\s*|:\s*)\[?(?:собеседник|interviewer|them|other)\]?\s*:\s*(.*)',
              caseSensitive: false)
          .firstMatch(l);
      if (matchMe != null) {
        speaker = Speaker.me;
        text = matchMe.group(1)?.trim() ?? '';
      } else if (matchThem != null) {
        speaker = Speaker.them;
        text = matchThem.group(1)?.trim() ?? '';
      }
      if (text.isNotEmpty) {
        result.add(TranscriptTurn(speaker: speaker, text: text));
      }
    }
    return ImportedChatResult(turns: result);
  }

  /// Разбор импортированного файла (возвращает список реплик)
  static List<TranscriptTurn> parseImportedChat(String raw) =>
      parseImportedChatFull(raw).turns;

  Future<void> saveConfig() async {
    await config.save();
    notifyListeners();
    applyTitlebar();
    await applyWindowSettings();
  }

  /// Применяет настройки нативного окна: скрытие от захвата экрана и поверх всех окон
  Future<void> applyWindowSettings() async {
    await WindowService.setScreenShareHidden(config.hideFromScreenShare);
    await WindowService.setAlwaysOnTop(config.alwaysOnTop);
  }

  /// Синхронизирует шапку окна с настройкой: прозрачная / плотная / скрытая
  /// (в скрытом режиме нативные кнопки убираются, в приложении — свои).
  void applyTitlebar() {
    if (!Platform.isMacOS) return;
    try {
      WindowManipulator.disableShadow();
      switch (config.titlebarMode) {
        case 'opaque':
          WindowManipulator.makeTitlebarOpaque();
          WindowManipulator.showTitle();
          WindowManipulator.showCloseButton();
          WindowManipulator.showMiniaturizeButton();
          WindowManipulator.showZoomButton();
        case 'hidden':
        case 'transparent':
        default:
          WindowManipulator.makeTitlebarTransparent();
          WindowManipulator.hideTitle();
          WindowManipulator.hideCloseButton();
          WindowManipulator.hideMiniaturizeButton();
          WindowManipulator.hideZoomButton();
      }
    } catch (_) {}
  }

  Future<void> setUiLang(String lang) async {
    S.lang = lang;
    config.uiLang = lang;
    await saveConfig();
  }

  /// Живое применение конфига из диалога (без записи на диск).
  void changed() => notifyListeners();

  /// Подмена всего конфига (кнопка «Отмена» в настройках).
  void applyConfig(AppConfig c) {
    config = c;
    S.lang = c.uiLang;
    notifyListeners();
    applyTitlebar();
    applyWindowSettings();
  }

  void updateSplitRatio(double r) {
    config.splitRatio = r;
    notifyListeners();
  }

  int _sessionGeneration = 0;

  Future<void> startStream() async {
    if (isStreaming) return;
    final gen = ++_sessionGeneration;
    status = SessionStatus.connecting;
    statusMessage = null;
    themError = null;
    notifyListeners();
    try {
      _recorder = AudioRecorder();
      final granted = await _recorder!.hasPermission();
      if (_sessionGeneration != gen) {
        await _teardown();
        return;
      }
      if (!granted) {
        throw Exception(S.t('errMicDenied'));
      }

      _micStream = DeepgramStream(
        source: Speaker.me,
        token: config.deepgramToken,
        model: config.deepgramModel,
        languageHint: config.languageHint,
        diarize: false,
      );
      _eventSubs.add(_micStream!.events.listen(onTurnEvent));
      _eventSubs.add(_micStream!.errors.listen(onStreamError));
      await _micStream!.start();

      final audio = await _recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          device:
              config.myDeviceId.isNotEmpty
                  ? InputDevice(id: config.myDeviceId, label: config.myDeviceId)
                  : null,
        ),
      );
      var micChunks = 0;
      debugPrint('[AUDIO me] stream started');
      _audioSub = audio.listen((chunk) {
        micChunks++;
        if (micChunks % 50 == 1) {
          debugPrint('[AUDIO me] chunk #$micChunks ${chunk.length}B');
        }
        _micStream?.send(chunk);
      }, onError: (Object e) => onStreamError('Микрофон: $e'));

      // Второй поток — голос собеседника (BlackHole, Remote Mac через SSH или выбранное аудиоустройство).
      if (config.themDeviceId == '__remote_mac__' &&
          config.remoteMacHost.isNotEmpty) {
        try {
          debugPrint('[THEM remote] ssh stream starting from ${config.remoteMacHost}...');
          _themStream = DeepgramStream(
            source: Speaker.them,
            token: config.deepgramToken,
            model: config.deepgramModel,
            languageHint: config.languageHint,
            diarize: false,
          );
          _eventSubs.add(_themStream!.events.listen(onTurnEvent));
          _eventSubs.add(_themStream!.errors.listen(_onThemError));
          await _themStream!.start();
          debugPrint('[THEM remote] ws requested');

          var themChunks = 0;
          final themBuffer = BytesBuilder(copy: false);
          const targetChunkSize = 3200; // 100ms at 16kHz 16-bit mono

          void handleData(List<int> chunk) {
            themBuffer.add(chunk);
            while (themBuffer.length >= targetChunkSize) {
              final bytes = themBuffer.takeBytes();
              final toSend = bytes.sublist(0, targetChunkSize);
              if (bytes.length > targetChunkSize) {
                themBuffer.add(bytes.sublist(targetChunkSize));
              }
              themChunks++;
              if (themChunks % 50 == 1) {
                debugPrint(
                    '[AUDIO them remote] chunk #$themChunks ${toSend.length}B');
              }
              _themStream?.send(toSend);
            }
          }

          try {
            debugPrint('[THEM remote] connecting to TCP ${config.remoteMacHost}:5005...');
            final socket = await Socket.connect(
              config.remoteMacHost,
              5005,
              timeout: const Duration(milliseconds: 2000),
            );
            _remoteSocket = socket;
            debugPrint('[THEM remote] TCP connected successfully!');
            _themAudioSub = socket.listen(
              handleData,
              onError: (Object e) => _onThemError('Собеседник (Mac TCP): $e'),
              onDone: () => debugPrint('[THEM remote] TCP disconnected'),
            );
          } catch (e) {
            debugPrint('[THEM remote] TCP connect failed ($e), falling back to SSH...');
            final user =
                config.remoteMacUser.isNotEmpty ? config.remoteMacUser : 'vanmac';
            _remoteAudioProcess = await Process.start('ssh', [
              '-T',
              '-q',
              '-o',
              'StrictHostKeyChecking=no',
              '$user@${config.remoteMacHost}',
              "/usr/local/bin/ffmpeg -nostdin -loglevel error -f avfoundation -i ':BlackHole 2ch' -ar 16000 -ac 1 -f s16le -",
            ]);
            _remoteAudioProcess!.stderr.listen((err) {
              debugPrint('[THEM remote stderr] ${String.fromCharCodes(err)}');
            });
            _remoteAudioProcess!.exitCode.then((code) {
              debugPrint('[THEM remote] ssh exited with code $code');
            });
            _themAudioSub = _remoteAudioProcess!.stdout.listen(
              handleData,
              onError: (Object e) => _onThemError('Собеседник (Mac): $e'),
            );
          }
        } catch (e) {
          _onThemError('Собеседник (Mac): $e');
        }
      } else if (config.themDeviceId.isNotEmpty &&
          config.themDeviceId != kSystemAudioDeviceId) {
        try {
          debugPrint('[THEM] init: device=${config.themDeviceId}');
          _themStream = DeepgramStream(
            source: Speaker.them,
            token: config.deepgramToken,
            model: config.deepgramModel,
            languageHint: config.languageHint,
            diarize: false,
          );
          _eventSubs.add(_themStream!.events.listen(onTurnEvent));
          _eventSubs.add(_themStream!.errors.listen(_onThemError));
          await _themStream!.start();
          debugPrint('[THEM] ws requested');
          _themRecorder = AudioRecorder();
          final themAudio = await _themRecorder!.startStream(
            RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
              device: InputDevice(
                id: config.themDeviceId,
                label: config.themDeviceId,
              ),
            ),
          );
          debugPrint('[THEM] recorder ok');
          var themChunks = 0;
          _themAudioSub = themAudio.listen((chunk) {
            themChunks++;
            if (themChunks % 50 == 1) {
              debugPrint('[AUDIO them] chunk #$themChunks ${chunk.length}B');
            }
            _themStream?.send(chunk);
          }, onError: (Object e) => _onThemError('Собеседник: $e'));
        } catch (e) {
          // Источник собеседника недоступен — продолжаем только с микрофоном.
          _onThemError('Собеседник: $e');
        }
      }
      status = SessionStatus.listening;
    } catch (e) {
      status = SessionStatus.error;
      statusMessage = '$e';
      await _teardown();
    }
    notifyListeners();
  }

  Future<void> stopStream() async {
    _sessionGeneration++;
    status = SessionStatus.idle;
    statusMessage = null;
    notifyListeners();
    await _teardown();
  }

  Future<void> _teardown() async {
    try {
      await _audioSub?.cancel();
    } catch (_) {}
    _audioSub = null;

    try {
      await _themAudioSub?.cancel();
    } catch (_) {}
    _themAudioSub = null;

    try {
      _remoteSocket?.destroy();
    } catch (_) {}
    _remoteSocket = null;

    try {
      _remoteAudioProcess?.kill();
    } catch (_) {}
    _remoteAudioProcess = null;

    final mic = _micStream;
    _micStream = null;
    if (mic != null) {
      try {
        await mic.stop().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
    }

    final them = _themStream;
    _themStream = null;
    if (them != null) {
      try {
        await them.stop().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
    }

    for (final s in _eventSubs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _eventSubs.clear();

    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      try {
        await rec.stop().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
      try {
        await rec.dispose().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
    }

    final themRec = _themRecorder;
    _themRecorder = null;
    if (themRec != null) {
      try {
        await themRec.stop().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
      try {
        await themRec.dispose().timeout(const Duration(milliseconds: 300),
            onTimeout: () => null);
      } catch (_) {}
    }
  }

  void _onThemError(String msg) {
    debugPrint('[THEM error]: $msg');
    themError = msg;
    try {
      _themAudioSub?.cancel();
      _themAudioSub = null;
      _themStream?.stop();
      _themStream = null;
      _themRecorder?.stop();
      _themRecorder?.dispose();
      _themRecorder = null;
    } catch (_) {}
    notifyListeners();
  }

  void onStreamError(String msg) {
    if (!isStreaming) return;
    status = SessionStatus.error;
    statusMessage = msg;
    _teardown();
    notifyListeners();
  }

  void onTurnEvent(DeepgramTurnEvent e) {
    switch (e.phase) {
      case TurnPhase.start:
        _setInterim(e.source, '');
      case TurnPhase.update:
        _setInterim(e.source, e.transcript);
      case TurnPhase.end:
        final text =
            (e.transcript.isNotEmpty ? e.transcript : _interimOf(e.source))
                .trim();
        if (text.isNotEmpty) {
          final newTurn = TranscriptTurn(
            speaker: e.source,
            text: text,
            timestamp: e.timestamp,
          );
          // Вставляем реплику по временной метке для сохранения строгой хронологии
          final insertIdx = turns.indexWhere(
            (t) => t.timestamp.isAfter(newTurn.timestamp),
          );
          if (insertIdx == -1) {
            turns.add(newTurn);
          } else {
            turns.insert(insertIdx, newTurn);
          }
          // Ограничиваем историю чата для защиты от утечек памяти и разрастания
          if (turns.length > maxTranscriptTurns) {
            final removeCount = turns.length - maxTranscriptTurns;
            turns.removeRange(0, removeCount);
            summarizedUpToTurn =
                (summarizedUpToTurn - removeCount).clamp(0, turns.length);
          }
          _scheduleSaveHistory();
          _scheduleAutoCompress();
        }
        _setInterim(e.source, '');
    }
    notifyListeners();
  }

  String _interimOf(Speaker s) => s == Speaker.me ? interimMe : interimThem;

  void _setInterim(Speaker s, String v) {
    if (s == Speaker.me) {
      interimMe = v;
    } else {
      interimThem = v;
    }
  }

  Speaker? get lastSpeaker => turns.isEmpty ? null : turns.last.speaker;

  String _buildPrompt({bool withScreenshot = false, int screenshotCount = 0}) {
    return PromptBuilder.build(
      config: config,
      turns: turns,
      lastSpeaker: lastSpeaker,
      conversationSummary: conversationSummary,
      summarizedUpToTurn: summarizedUpToTurn,
      interimMe: interimMe,
      followUpRound: llmHistory.isNotEmpty ? (llmHistory.length ~/ 2 + 1) : 1,
      isFollowUp: llmHistory.isNotEmpty,
      withScreenshot: withScreenshot,
      screenshotCount: screenshotCount,
    );
  }

  @visibleForTesting
  String buildPrompt({bool withScreenshot = false, int screenshotCount = 0}) =>
      _buildPrompt(
        withScreenshot: withScreenshot,
        screenshotCount: screenshotCount,
      );

  /// Остановка текущей потоковой генерации ответа пользователем.
  void stopHelp() {
    if (!helpLoading) return;
    _cancelHelpStream();
    helpLoading = false;
    notifyListeners();
  }

  Future<void> _cancelHelpStream() async {
    final sub = _helpSub;
    _helpSub = null;
    await sub?.cancel();
    _activeHelpClient?.close();
    _activeHelpClient = null;
  }

  /// Добавить текущий снимок экрана в каретку закреплённых скриншотов.
  Future<void> addPendingScreenshot() async {
    if (isCapturingScreenshot || helpLoading) return;
    isCapturingScreenshot = true;
    notifyListeners();
    try {
      final imageBytes = await WindowService.captureScreen(
        remoteMacHost: config.remoteMacHost,
        remoteMacUser: config.remoteMacUser,
      );
      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception(
          S.lang == 'ru'
              ? 'Не удалось сделать скриншот экрана. Проверьте разрешение «Запись экрана».'
              : 'Failed to capture screen. Please check screen recording permissions.',
        );
      }
      pendingScreenshots.add(imageBytes);
    } catch (e) {
      debugPrint('[SCREENSHOT] capture error: $e');
      helpError = '$e';
    } finally {
      isCapturingScreenshot = false;
      notifyListeners();
    }
  }

  /// Удалить скриншот из каретки по индексу.
  void removePendingScreenshot(int index) {
    if (index >= 0 && index < pendingScreenshots.length) {
      pendingScreenshots.removeAt(index);
      notifyListeners();
    }
  }

  /// Полностью очистить каретку скриншотов.
  void clearPendingScreenshots() {
    if (pendingScreenshots.isNotEmpty) {
      pendingScreenshots.clear();
      notifyListeners();
    }
  }

  Future<void> _streamHelp({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
    Uint8List? imageBytes,
    List<Uint8List>? images,
  }) async {
    await _cancelHelpStream();
    helpLoading = true;
    helpAnswer = null;
    helpError = null;
    notifyListeners();

    final client = http.Client();
    _activeHelpClient = client;
    final completer = Completer<void>();
    final currentHistory = List<LlmMessage>.from(llmHistory);

    try {
      final stream = LlmService.askStream(
        provider: provider,
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        imageBytes: imageBytes,
        images: images,
        history: currentHistory,
        client: client,
      );

      _helpSub = stream.listen(
        (chunk) {
          if (helpAnswer == null) {
            helpAnswer = chunk;
          } else {
            helpAnswer = helpAnswer! + chunk;
          }
          notifyListeners();
        },
        onError: (e) {
          helpError = '$e';
          helpLoading = false;
          _activeHelpClient = null;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if ((helpAnswer ?? '').trim().isEmpty && helpError == null) {
            helpError = 'LLM вернул пустой ответ';
          } else if (helpAnswer != null &&
              helpAnswer!.trim().isNotEmpty &&
              helpError == null) {
            final sentImages = images ??
                (imageBytes != null && imageBytes.isNotEmpty
                    ? [imageBytes]
                    : const <Uint8List>[]);
            llmHistory.add(LlmMessage(
              role: 'user',
              text: prompt,
              images: sentImages,
            ));
            llmHistory.add(LlmMessage(
              role: 'assistant',
              text: helpAnswer!.trim(),
            ));
            // Ограничиваем историю (до 8 сообщений = 4 раунда):
            // сохраняем базовый контекст задачи (0-1 с картинками) и 2 последних раунда уточнений
            if (llmHistory.length > 8) {
              final baseUser = llmHistory[0];
              final baseAssistant = llmHistory[1];
              final tail = llmHistory.sublist(llmHistory.length - 4);
              llmHistory.clear();
              llmHistory.addAll([baseUser, baseAssistant, ...tail]);
            }
          }
          helpLoading = false;
          _activeHelpClient = null;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
    } catch (e) {
      helpError = '$e';
      helpLoading = false;
      _activeHelpClient = null;
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  Future<void> getHelp() async {
    if (helpLoading) return;
    final provider = config.provider;
    final apiKey = config.keyFor(provider).trim();
    if (apiKey.isEmpty) {
      helpError = S.t('errNoKey', provider.label);
      notifyListeners();
      return;
    }
    if (turns.isEmpty &&
        interimMe.trim().isEmpty &&
        interimThem.trim().isEmpty &&
        llmHistory.isEmpty) {
      helpError = S.t('errEmptyTranscript');
      notifyListeners();
      return;
    }
    final List<Uint8List>? imagesToSend;
    if (pendingScreenshots.isNotEmpty) {
      imagesToSend = List<Uint8List>.from(pendingScreenshots);
      clearPendingScreenshots();
    } else {
      imagesToSend = null;
    }

    await _streamHelp(
      provider: provider,
      apiKey: apiKey,
      model: config.modelFor(provider),
      prompt: _buildPrompt(
        withScreenshot: imagesToSend != null && imagesToSend.isNotEmpty,
        screenshotCount: imagesToSend?.length ?? 0,
      ),
      images: imagesToSend,
    );
  }

  /// Получить подсказку с анализом скриншота экрана кандидата (для задач по коду / IDE).
  /// Если в каретке (pendingScreenshots) закреплено 1 или более фоток, берутся они.
  /// Если ничего не закреплено, делается 1 свежий скриншот экрана и отправляется.
  Future<void> getHelpWithScreenshot() async {
    if (helpLoading) return;
    final provider = config.provider;
    final apiKey = config.keyFor(provider).trim();
    if (apiKey.isEmpty) {
      helpError = S.t('errNoKey', provider.label);
      notifyListeners();
      return;
    }
    helpLoading = true;
    helpAnswer = null;
    helpError = null;
    notifyListeners();
    try {
      final List<Uint8List> imagesToSend;
      if (pendingScreenshots.isNotEmpty) {
        imagesToSend = List<Uint8List>.from(pendingScreenshots);
        clearPendingScreenshots();
      } else {
        final imageBytes = await WindowService.captureScreen(
          remoteMacHost: config.remoteMacHost,
          remoteMacUser: config.remoteMacUser,
        );
        if (imageBytes == null || imageBytes.isEmpty) {
          throw Exception(
            S.lang == 'ru'
                ? 'Не удалось сделать скриншот экрана. Проверьте разрешение «Запись экрана» в Системных настройках macOS.'
                : 'Failed to capture screen. Please check "Screen Recording" permission in macOS System Settings.',
          );
        }
        imagesToSend = [imageBytes];
      }

      await _streamHelp(
        provider: provider,
        apiKey: apiKey,
        model: config.modelFor(provider),
        prompt: _buildPrompt(
          withScreenshot: true,
          screenshotCount: imagesToSend.length,
        ),
        images: imagesToSend,
      );
    } on PlatformException catch (e) {
      helpError = e.message ?? e.code;
      helpLoading = false;
      notifyListeners();
    } catch (e) {
      helpError = '$e';
      helpLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    await _cancelHelpStream();
    await HotkeyService.unregisterAll();
    _saveDebounce?.cancel();
    _compressDebounce?.cancel();
    await HistoryStore.saveData(
      turns: turns,
      conversationSummary: conversationSummary,
      summarizedUpToTurn: summarizedUpToTurn,
    );
    await _teardown();
    super.dispose();
  }
}
