import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:record/record.dart';

import 'l10n.dart';
import 'services/config_store.dart';
import 'services/deepgram_stream.dart';
import 'services/llm_service.dart';

enum SessionStatus { idle, connecting, listening, error }

class TranscriptTurn {
  TranscriptTurn({required this.speaker, required this.text});

  final Speaker speaker;
  final String text;
}

class Session extends ChangeNotifier {
  AppConfig config = AppConfig();

  SessionStatus status = SessionStatus.idle;
  String? statusMessage;

  final List<TranscriptTurn> turns = [];
  String interimMe = '';
  String interimThem = '';

  bool helpLoading = false;
  String? helpAnswer;
  String? helpError;

  /// Статус второго потока (голос собеседника).
  String? themError;
  bool get themActive => _themStream != null;

  AudioRecorder? _recorder;
  AudioRecorder? _themRecorder;
  DeepgramStream? _micStream;
  DeepgramStream? _themStream;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<Uint8List>? _themAudioSub;
  final _eventSubs = <StreamSubscription<dynamic>>[];

  bool get isStreaming =>
      status == SessionStatus.connecting || status == SessionStatus.listening;

  Future<void> loadConfig() async {
    config = await AppConfig.load();
    S.lang = config.uiLang;
    notifyListeners();
  }

  Future<void> saveConfig() async {
    await config.save();
    notifyListeners();
    applyTitlebar();
  }

  /// Синхронизирует шапку окна с настройкой: прозрачная / плотная / скрытая
  /// (в скрытом режиме нативные кнопки убираются, в приложении — свои).
  void applyTitlebar() {
    try {
      switch (config.titlebarMode) {
        case 'hidden':
          WindowManipulator.makeTitlebarTransparent();
          WindowManipulator.hideCloseButton();
          WindowManipulator.hideMiniaturizeButton();
          WindowManipulator.hideZoomButton();
        case 'opaque':
          WindowManipulator.makeTitlebarOpaque();
          WindowManipulator.showCloseButton();
          WindowManipulator.showMiniaturizeButton();
          WindowManipulator.showZoomButton();
        default:
          WindowManipulator.makeTitlebarTransparent();
          WindowManipulator.showCloseButton();
          WindowManipulator.showMiniaturizeButton();
          WindowManipulator.showZoomButton();
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
        // Простой режим (устройство собеседника не выбрано): один микрофон,
        // спикеров разделяет диаризация Deepgram (v1, nova-3).
        diarize: config.themDeviceId.isEmpty,
      );
      _eventSubs.add(_micStream!.events.listen(onTurnEvent));
      _eventSubs.add(_micStream!.errors.listen(onStreamError));
      await _micStream!.start();

      final audio = await _recorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      var micChunks = 0;
      debugPrint('[AUDIO me] stream started');
      _audioSub = audio.listen(
        (chunk) {
          micChunks++;
          if (micChunks % 50 == 1) {
            debugPrint('[AUDIO me] chunk #$micChunks ${chunk.length}B');
          }
          _micStream?.send(chunk);
        },
        onError: (Object e) => onStreamError('Микрофон: $e'),
      );

      // Второй поток — голос собеседника (системный звук, напр. BlackHole).
      if (config.themDeviceId.isNotEmpty) {
        try {
          _themStream = DeepgramStream(
            source: Speaker.them,
            token: config.deepgramToken,
            model: config.deepgramModel,
            languageHint: config.languageHint,
          );
          _eventSubs.add(_themStream!.events.listen(onTurnEvent));
          _eventSubs.add(_themStream!.errors.listen(onStreamError));
          await _themStream!.start();
          _themRecorder = AudioRecorder();
          final themAudio = await _themRecorder!.startStream(RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            device: InputDevice(id: config.themDeviceId, label: config.themDeviceId),
          ));
          _themAudioSub = themAudio.listen(
            (chunk) => _themStream?.send(chunk),
            onError: (Object e) => onStreamError('Собеседник: $e'),
          );
        } catch (e) {
          // Источник собеседника недоступен — продолжаем только с микрофоном.
          themError = '$e';
          try {
            await _themAudioSub?.cancel();
            await _themStream?.stop();
            await _themRecorder?.dispose();
          } catch (_) {}
          _themAudioSub = null;
          _themStream = null;
          _themRecorder = null;
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
          turns.add(TranscriptTurn(speaker: e.source, text: text));
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
    final recent =
        turns.length > 30 ? turns.sublist(turns.length - 30) : turns;
    for (final t in recent) {
      buf.writeln(
          '${t.speaker == Speaker.me ? 'Speaker 1 (я, кандидат)' : 'Speaker 2 (собеседник)'}: ${t.text}');
    }
    final live = interimMe.trim();
    if (live.isNotEmpty) {
      buf.writeln(
          'Speaker 1 (я, кандидат) — говорит прямо сейчас, фразу не закончил: $live');
    }
    return buf.toString().trim();
  }

  String _buildPrompt() {
    final lastLine = switch (lastSpeaker) {
      Speaker.me => 'Последнюю реплику говорил я (кандидат) — помоги закончить мысль и продолжить ответ.',
      Speaker.them => 'Последним говорил собеседник — подскажи, что мне ответить.',
      null => 'Разговор только начался.',
    };
    final my = config.myProfile.trim();
    final them = config.interviewerProfile.trim();
    // Язык подсказки = язык интерфейса (переключается кнопкой RU/EN в шапке).
    final answerLine =
        config.uiLang == 'en' ? 'Отвечай по-английски.' : 'Отвечай по-русски.';
    return 'Ты — ассистент кандидата на живом собеседовании (идёт звонок, отвечать нужно мгновенно).\n'
        'Speaker 1 — это я (кандидат). Speaker 2 — собеседник.\n'
        '$lastLine\n'
        'Мои цели и критерии: ${config.goals.trim()}\n'
        '${my.isNotEmpty ? 'Информация обо мне (кандидате): $my\n' : ''}'
        '${them.isNotEmpty ? 'Информация о собеседнике: $them\n' : ''}'
        'Учитывай информацию обо мне и о собеседнике, если она есть.\n\n'
        'Дай краткую подсказку (1–3 предложения, можно с готовой фразой, которую я сразу произнесу). '
        'Без преамбулы и рассуждений — сразу суть. $answerLine\n\n'
        'СТЕНОГРАММА:\n${_transcriptForPrompt()}';
  }

  Future<void> getHelp() async {
    if (helpLoading) return;
    helpAnswer = null;
    final provider = config.provider;
    final apiKey = config.keyFor(provider).trim();
    if (apiKey.isEmpty) {
      helpError = S.t('errNoKey', provider.label);
      notifyListeners();
      return;
    }
    if (turns.isEmpty && interimMe.trim().isEmpty && interimThem.trim().isEmpty) {
      helpError = S.t('errEmptyTranscript');
      notifyListeners();
      return;
    }
    helpLoading = true;
    helpError = null;
    notifyListeners();
    try {
      helpAnswer = await LlmService.ask(
        provider: provider,
        apiKey: apiKey,
        model: config.modelFor(provider),
        prompt: _buildPrompt(),
      );
    } catch (e) {
      helpError = '$e';
    }
    helpLoading = false;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _teardown();
    super.dispose();
  }
}
