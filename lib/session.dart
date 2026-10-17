import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:record/record.dart';

import 'l10n.dart';
import 'services/config_store.dart';
import 'services/deepgram_stream.dart';
import 'services/history_store.dart';
import 'services/hotkey_service.dart';
import 'services/llm_service.dart';
import 'services/window_service.dart';

enum SessionStatus { idle, connecting, listening, error }

class TranscriptTurn {
  TranscriptTurn({
    required this.speaker,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final Speaker speaker;
  final String text;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'speaker': speaker.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranscriptTurn.fromJson(Map<String, dynamic> json) {
    final s = json['speaker'];
    final speaker =
        (s == 'them' || s == 'interviewer') ? Speaker.them : Speaker.me;
    final text = (json['text'] as String?) ?? '';
    final timeStr = (json['timestamp'] as String?) ?? '';
    final timestamp = DateTime.tryParse(timeStr) ?? DateTime.now();
    return TranscriptTurn(speaker: speaker, text: text, timestamp: timestamp);
  }
}

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

  /// Статус второго потока (голос собеседника).
  String? themError;
  bool get themActive => _themStream != null;

  AudioRecorder? _recorder;
  AudioRecorder? _themRecorder;
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
      final dialogueSliceBuf = StringBuffer();
      for (final t in slice) {
        final label = t.speaker == Speaker.me ? 'Кандидат' : 'Интервьюер';
        dialogueSliceBuf.writeln('[$label]: ${t.text}');
      }

      final prompt = '''
Ты — интеллектуальный ассистент, выполняющий смысловую компрессию (сжатие) истории живого технического/делового собеседования.
Твоя задача — составить или обновить связное, ёмкое резюме диалога, сохранив ключевую суть:
1. Темы, вопросы и задачи, озвученные интервьюером;
2. Навыки, опыт, архитектурные/технические решения, код и аргументы кандидата;
3. Замечания, требования и текущий статус обсуждения.

Формат резюме:
- Краткие маркированные пункты (тезисно, без «воды»);
- Сохраняй ключевые факты, стек, технологии, формулировки и цифры;
- Не искажай смысл и не добавляй вымышленных деталей;
- Язык резюме: тот же язык, на котором шёл диалог (русский или английский).

<previous_summary>
${conversationSummary.trim().isNotEmpty ? conversationSummary.trim() : 'Нет предыдущего резюме (это начало диалога)'}
</previous_summary>

<new_dialogue_turns_to_compress>
${dialogueSliceBuf.toString().trim()}
</new_dialogue_turns_to_compress>

Верни ТОЛЬКО обновлённое структурированное резюме диалога без вступительных слов и комментариев.
'''.trim();

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
      if (config.myDeviceId.isNotEmpty &&
          !audioDevices.any((d) => d.id == config.myDeviceId)) {
        config.myDeviceId = '';
      }
      _ensureDefaultThemDevice();
      notifyListeners();
    } catch (_) {}
  }

  void _ensureDefaultThemDevice() {
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

  Future<void> startStream() async {
    if (isStreaming) return;
    status = SessionStatus.connecting;
    statusMessage = null;
    themError = null;
    notifyListeners();
    try {
      _recorder = AudioRecorder();
      final granted = await _recorder!.hasPermission();
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

      // Второй поток — голос собеседника (BlackHole или выбранное аудиоустройство).
      if (config.themDeviceId.isNotEmpty &&
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
    await _teardown();
    status = SessionStatus.idle;
    statusMessage = null;
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _themAudioSub?.cancel();
    _themAudioSub = null;
    await _micStream?.stop();
    _micStream = null;
    await _themStream?.stop();
    _themStream = null;
    for (final s in _eventSubs) {
      await s.cancel();
    }
    _eventSubs.clear();
    try {
      await _recorder?.stop();
    } finally {
      await _recorder?.dispose();
      _recorder = null;
    }
    try {
      await _themRecorder?.stop();
    } finally {
      await _themRecorder?.dispose();
      _themRecorder = null;
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

  String _transcriptForPrompt() {
    final buf = StringBuffer();
    List<TranscriptTurn> recent;
    if (config.autoCompressContext && conversationSummary.trim().isNotEmpty) {
      final start = summarizedUpToTurn.clamp(0, turns.length);
      final remaining = turns.sublist(start);
      final limit = config.llmContextTurns.clamp(5, 100);
      recent = remaining.length > limit
          ? remaining.sublist(remaining.length - limit)
          : remaining;
    } else {
      final limit = config.llmContextTurns.clamp(5, 100);
      recent =
          turns.length > limit ? turns.sublist(turns.length - limit) : turns;
    }
    for (final t in recent) {
      final speakerTag = t.speaker == Speaker.me ? 'candidate' : 'interviewer';
      buf.writeln('  <turn speaker="$speakerTag">${t.text}</turn>');
    }
    final live = interimMe.trim();
    if (live.isNotEmpty) {
      buf.writeln(
        '  <turn speaker="candidate" status="speaking_now">$live</turn>',
      );
    }
    return buf.toString().trimRight();
  }

  String _buildPrompt({bool withScreenshot = false}) {
    final situation = switch (lastSpeaker) {
      Speaker.me =>
        'Последнюю реплику говорил я. Помоги мне развить мысль, закончить формулировку или дополнить ответ сильными аргументами.',
      Speaker.them =>
        'Последним говорил оппонент (задал вопрос или сделал реплику). Подскажи мне точный, сильный и выигрышный ответ от моего лица.',
      null =>
        'Разговор только начинается. Помоги уверенно начать диалог.',
    };

    final my = config.myProfile.trim();
    final them = config.interviewerProfile.trim();
    final goals = config.goals.trim();
    final hasSummary =
        config.autoCompressContext && conversationSummary.trim().isNotEmpty;

    final languageInstruction = switch (config.answerLang) {
      'ru' => 'Отвечай строго на русском языке.',
      'en' => 'Answer strictly in English.',
      _ =>
        config.uiLang == 'en'
            ? 'Answer in the same language as the conversation (English if in English, Russian if in Russian).'
            : 'Отвечай на том же языке, на котором говорит собеседник в диалоге (если собеседник говорит по-русски — отвечай по-русски, если по-английски — по-английски).',
    };

    return '''
<system_role>
Ты — интеллектуальный ко-пилот и персональный суфлёр в реальном времени (для переговоров, собеседований и деловых встреч). Твоя задача — мгновенно вооружать пользователя чёткими, уверенными и профессиональными ответами прямо во время разговора.
</system_role>

<candidate_profile>
${my.isNotEmpty ? my : 'Профиль пользователя не указан (опирайся на контекст диалога).'}
</candidate_profile>

<interviewer_profile>
${them.isNotEmpty ? them : 'Профиль оппонента не указан.'}
</interviewer_profile>

<interview_goals>
${goals.isNotEmpty ? goals : 'Провести переговоры / собеседование успешно, отвечать уверенно, точно и структурированно.'}
</interview_goals>
${hasSummary ? '''

<conversation_summary>
${conversationSummary.trim()}
</conversation_summary>
''' : ''}
<live_transcript>
${_transcriptForPrompt()}
</live_transcript>

<current_situation>
$situation
</current_situation>
${withScreenshot ? '''

<screen_context>
К этому запросу прикреплён актуальный скриншот экрана (IDE, окно терминала, веб-платформа с заданием, условие задачи или кодовая база).
ЭТО ВОПРОС ТЕХНИЧЕСКОГО ХАРАКТЕРА! На изображении находится условие задачи, код, архитектурная схема, ошибка или технический вопрос, который решает пользователь прямо сейчас.
</screen_context>
''' : ''}
<instructions>
1. Отвечай от первого лица ("я"), моим голосом — так, чтобы я мог сразу вслух произнести твою подсказку.
2. Строго опирайся на навыки и опыт из <candidate_profile>, если он указан. Не противоречь опыту и не выдумывай несуществующие факты.
3. Учитывай цели из <interview_goals> и особенности оппонента из <interviewer_profile>.
${hasSummary ? '4. Опирайся на контекст из <conversation_summary> (сохранённое резюме предыдущей части собеседования) и актуальные реплики из <live_transcript>.\n' : ''}${withScreenshot ? '''
4. ВНИМАТЕЛЬНО ИЗУЧИ ПРИКРЕПЛЁННЫЙ СКРИНШОТ ЭКРАНА! Распознай код, сигнатуры функций, контекст IDE, условие задачи или ошибку.
5. Если кандидат решает задачу по программированию / алгоритмам / архитектуре / SQL — ДАЙ ГОТОВЫЙ РАБОЧИЙ КОД И ЧЁТКОЕ РЕШЕНИЕ с лаконичным объяснением (почему именно так).
6. Если на экране видна ошибка или упавший тест — объясни причину в одном предложении и дай готовый исправленный код / команду.
7. Кандидат может вслух произнести лишь короткую фразу (например: "вот у меня тут код" или "как это решить?"), поэтому всё необходимое для полного решения бери прямо со скриншота!
''' : '''
4. Формат подсказки: предельно ёмко, 1–3 предложения (или 2–3 коротких ключевых тезиса с готовой речевой фразой).
5. Никаких преамбул, мета-комментариев и вступлений (ЗАПРЕЩЕНО писать: "Вот что вам сказать:", "Вы можете ответить:"). Сразу давай готовую реплику / суть ответа!
'''}
8. $languageInstruction
</instructions>
'''.trim();
  }

  @visibleForTesting
  String buildPrompt({bool withScreenshot = false}) =>
      _buildPrompt(withScreenshot: withScreenshot);

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

  Future<void> _streamHelp({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    await _cancelHelpStream();
    helpLoading = true;
    helpAnswer = null;
    helpError = null;
    notifyListeners();

    final client = http.Client();
    _activeHelpClient = client;
    final completer = Completer<void>();

    try {
      final stream = LlmService.askStream(
        provider: provider,
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        imageBytes: imageBytes,
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
        interimThem.trim().isEmpty) {
      helpError = S.t('errEmptyTranscript');
      notifyListeners();
      return;
    }
    await _streamHelp(
      provider: provider,
      apiKey: apiKey,
      model: config.modelFor(provider),
      prompt: _buildPrompt(),
    );
  }

  /// Получить подсказку с анализом скриншота экрана кандидата (для задач по коду / IDE).
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
      final imageBytes = await WindowService.captureScreen();
      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception(
          S.lang == 'ru'
              ? 'Не удалось сделать скриншот экрана. Проверьте разрешение «Запись экрана» в Системных настройках macOS.'
              : 'Failed to capture screen. Please check "Screen Recording" permission in macOS System Settings.',
        );
      }

      await _streamHelp(
        provider: provider,
        apiKey: apiKey,
        model: config.modelFor(provider),
        prompt: _buildPrompt(withScreenshot: true),
        imageBytes: imageBytes,
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
