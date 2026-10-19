import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:record/record.dart';

import 'domain/chat_serializer.dart';
import 'domain/prompt_builder.dart';
import 'domain/transcript_turn.dart';
import 'l10n.dart';
import 'services/audio_controller.dart';
import 'services/config_store.dart';
import 'services/deepgram_stream.dart';
import 'services/history_store.dart';
import 'services/hotkey_service.dart';
import 'services/llm_service.dart';
import 'services/window_service.dart';
import 'services/nonverbal/nonverbal_coordinator.dart';
import 'domain/nonverbal/raw_signals.dart';


export 'domain/chat_serializer.dart';
export 'domain/transcript_turn.dart';
export 'domain/nonverbal/raw_signals.dart';
export 'domain/nonverbal/eye_metrics.dart';
export 'domain/nonverbal/micro_events.dart';
export 'domain/nonverbal/behavioral_cluster.dart';
export 'services/nonverbal/temporal_detector.dart';
export 'services/nonverbal/nonverbal_coordinator.dart';

enum SessionStatus { idle, connecting, listening, error }
enum VisionMode { off, screenCrop, simulator }

class Session extends ChangeNotifier {
  AppConfig config = AppConfig();

  final NonverbalCoordinator nonverbal = NonverbalCoordinator();
  VisionMode visionMode = VisionMode.off;
  Rect? cropRect;
  bool isCropAnalyzing = false;
  Timer? _cropTimer;
  Uint8List? latestCropImageBytes;
  String lastBuiltPrompt = '';

  String getCurrentPromptForInspection() => _buildPrompt(
        withScreenshot: latestCropImageBytes != null || pendingScreenshots.isNotEmpty,
        screenshotCount: pendingScreenshots.isNotEmpty
            ? pendingScreenshots.length
            : (latestCropImageBytes != null ? 1 : 0),
        isFaceCrop: visionMode == VisionMode.screenCrop && latestCropImageBytes != null,
      );

  void setVisionMode(VisionMode mode) {
    if (visionMode != mode) {
      visionMode = mode;
      if (mode == VisionMode.off) {
        _stopCropAnalysis();
      }
      notifyListeners();
    }
  }

  void setCropRect(Rect rect) {
    cropRect = rect;
    notifyListeners();
  }

  void toggleCropAnalysis() {
    if (isCropAnalyzing) {
      _stopCropAnalysis();
    } else {
      _startCropAnalysis();
    }
  }

  int _cropTick = 0;

  void _startCropAnalysis() {
    isCropAnalyzing = true;
    notifyListeners();
    _cropTimer?.cancel();
    _cropTick = 0;
    _cropTimer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
      if (!isCropAnalyzing) return;
      if (cropRect != null) {
        try {
          final metrics = await WindowService.analyzeFaceCrop(
            x: cropRect!.left,
            y: cropRect!.top,
            width: cropRect!.width,
            height: cropRect!.height,
          );
          if (metrics != null) {
            final snapshot = FaceFrameSnapshot.fromNativeAppleVision(metrics);
            nonverbal.processFrame(snapshot);
          }

          // Раз в 3 такта (~1.3 сек) обновляем кадр для превью в инспекторе
          if (_cropTick++ % 3 == 0) {
            final bytes = await WindowService.captureCrop(
              x: cropRect!.left,
              y: cropRect!.top,
              width: cropRect!.width,
              height: cropRect!.height,
            );
            if (bytes != null && bytes.isNotEmpty) {
              latestCropImageBytes = bytes;
            }
          }
        } catch (_) {}
      }
    });
  }

  void _stopCropAnalysis() {
    isCropAnalyzing = false;
    _cropTimer?.cancel();
    _cropTimer = null;
    notifyListeners();
  }

  /// Симуляция невербальных сценариев (для экспресс-теста интерфейса и подсказок LLM)
  void simulateScenario(String scenario) {
    final now = DateTime.now();
    switch (scenario) {
      case 'skepticism':
        nonverbal.processFrame(FaceFrameSnapshot(
          timestamp: now,
          hasFace: true,
          confidence: 0.95,
          blendshapes: const FaceBlendshapeScores({
            'browDownLeft': 0.65,
            'browDownRight': 0.60,
            'mouthSmileLeft': 0.45,
            'mouthSmileRight': 0.05,
            'eyeSquintLeft': 0.50,
            'eyeSquintRight': 0.50,
          }),
          gaze: GazeVector.center(),
          headPose: const HeadPose(pitch: 5, yaw: -3, roll: 0),
        ));
        break;
      case 'stress':
        nonverbal.processFrame(FaceFrameSnapshot(
          timestamp: now,
          hasFace: true,
          confidence: 0.94,
          blendshapes: const FaceBlendshapeScores({
            'mouthPressLeft': 0.65,
            'mouthPressRight': 0.60,
            'jawOpen': 0.0,
            'eyeBlinkLeft': 0.85,
            'eyeBlinkRight': 0.85,
          }),
          gaze: const GazeVector(yaw: 0.4, pitch: -0.3, direction: GazeDirectionType.averted),
          headPose: const HeadPose(pitch: -5, yaw: 10, roll: 0),
        ));
        break;
      case 'false_agreement':
        nonverbal.processFrame(FaceFrameSnapshot(
          timestamp: now,
          hasFace: true,
          confidence: 0.92,
          blendshapes: const FaceBlendshapeScores({
            'eyeBlinkLeft': 0.90,
            'eyeBlinkRight': 0.90,
            'mouthPressLeft': 0.50,
            'mouthPressRight': 0.50,
          }),
          gaze: GazeVector.center(),
          headPose: const HeadPose(pitch: 0, yaw: -8, roll: 0),
        ));
        break;
      case 'reset':
      default:
        nonverbal.processFrame(FaceFrameSnapshot.empty());
        break;
    }
    notifyListeners();
  }

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

  final AudioController _audioController = AudioController();

  /// Статус второго потока (голос собеседника).
  String? themError;
  bool get themActive => _audioController.themActive;

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
    audioDevices = await _audioController.loadAudioDevices(config);
    notifyListeners();
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
  String exportChatJson() => ChatSerializer.exportJson(
        turns: turns,
        conversationSummary: conversationSummary,
        summarizedUpToTurn: summarizedUpToTurn,
      );

  /// Полный разбор импортированного файла (включая реплики и резюме компрессии)
  static ImportedChatResult parseImportedChatFull(String raw) =>
      ChatSerializer.parseFull(raw);

  /// Разбор импортированного файла (возвращает список реплик)
  static List<TranscriptTurn> parseImportedChat(String raw) =>
      ChatSerializer.parse(raw);

  Future<void> saveConfig() async {
    await config.save();
    notifyListeners();
    applyTitlebar();
    await applyWindowSettings();
  }

  /// Применяет настройки нативного окна: скрытие от захвата экрана, поверх всех окон и прозрачность
  Future<void> applyWindowSettings() async {
    await WindowService.setScreenShareHidden(config.hideFromScreenShare);
    await WindowService.setAlwaysOnTop(config.alwaysOnTop);
    await WindowService.setWindowOpacity(config.windowOpacity);
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
    notifyListeners();
    try {
      await saveConfig();
    } catch (e) {
      debugPrint('[SESSION] error saving config in setUiLang: $e');
    }
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
      await _audioController.startStream(
        config: config,
        onTurnEvent: onTurnEvent,
        onMicError: onStreamError,
        onThemError: _onThemError,
      );
      status = SessionStatus.listening;
    } on PlatformException catch (e, st) {
      debugPrint(
        '[Session.startStream PlatformException]: code=${e.code}, message=${e.message}, details=${e.details}\n$st',
      );
      status = SessionStatus.error;
      statusMessage =
          '${e.message ?? e.code}${e.details != null ? ": ${e.details}" : ""}';
    } catch (e, st) {
      debugPrint('[Session.startStream Error]: $e\n$st');
      status = SessionStatus.error;
      statusMessage = '$e';
    }
    notifyListeners();
  }

  Future<void> stopStream() async {
    status = SessionStatus.idle;
    statusMessage = null;
    notifyListeners();
    await _audioController.teardown();
  }

  void _onThemError(String msg) {
    debugPrint('[THEM error]: $msg');
    themError = msg;
    _audioController.stopThemStream();
    notifyListeners();
  }

  void onStreamError(String msg) {
    if (!isStreaming) return;
    status = SessionStatus.error;
    statusMessage = msg;
    _audioController.teardown();
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
          final tags = e.source == Speaker.them
              ? nonverbal.getCurrentTurnTags()
              : const <String>[];
          final newTurn = TranscriptTurn(
            speaker: e.source,
            text: text,
            timestamp: e.timestamp,
            nonverbalTags: tags,
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

  String _buildPrompt({
    bool withScreenshot = false,
    int screenshotCount = 0,
    bool isFaceCrop = false,
  }) {
    final isVisionActive = visionMode != VisionMode.off;
    final includeDossier = config.showPsychologicalDossier && isVisionActive;

    final prompt = PromptBuilder.build(
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
      isFaceCrop: isFaceCrop,
      nonverbalContext: isVisionActive ? nonverbal.getPromptContextForLlm() : '',
      includeDossier: includeDossier,
    );
    lastBuiltPrompt = prompt;
    return prompt;
  }

  @visibleForTesting
  String buildPrompt({
    bool withScreenshot = false,
    int screenshotCount = 0,
    bool isFaceCrop = false,
  }) =>
      _buildPrompt(
        withScreenshot: withScreenshot,
        screenshotCount: screenshotCount,
        isFaceCrop: isFaceCrop,
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

    debugPrint('=== [MIMIC LLM REQUEST] Провайдер: ${provider.label}, Модель: $model ===');
    debugPrint('[MIMIC] Отправлено изображений: ${images != null ? images.length : (imageBytes != null ? 1 : 0)}');
    debugPrint('[MIMIC PROMPT]:\n$prompt\n=== [MIMIC END PROMPT] ===');

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
        pendingScreenshots.isEmpty) {
      helpError = S.t('errEmptyTranscript');
      notifyListeners();
      return;
    }
    // Get answer всегда начинает новую задачу с чистого листа
    resetLlmHistory();

    final List<Uint8List>? imagesToSend;
    final bool isFaceCrop;
    if (pendingScreenshots.isNotEmpty) {
      imagesToSend = List<Uint8List>.from(pendingScreenshots);
      clearPendingScreenshots();
      isFaceCrop = false;
    } else if (visionMode == VisionMode.screenCrop && latestCropImageBytes != null) {
      // Автоматически прикрепляем свежий визуальный фрейм лица оппонента для мультимодальной оценки
      imagesToSend = [latestCropImageBytes!];
      isFaceCrop = true;
    } else {
      imagesToSend = null;
      isFaceCrop = false;
    }

    await _streamHelp(
      provider: provider,
      apiKey: apiKey,
      model: config.modelFor(provider),
      prompt: _buildPrompt(
        withScreenshot: imagesToSend != null && imagesToSend.isNotEmpty,
        screenshotCount: imagesToSend?.length ?? 0,
        isFaceCrop: isFaceCrop,
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
    // Запрос со скриншотом также начинает новую независимую задачу с чистого листа
    resetLlmHistory();

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

  /// Запросить уточняющий раунд ответа (R2, R3...) с сохранением предыдущего контекста задачи.
  Future<void> getFollowUpHelp() async {
    if (helpLoading || llmHistory.isEmpty) return;
    final provider = config.provider;
    final apiKey = config.keyFor(provider).trim();
    if (apiKey.isEmpty) {
      helpError = S.t('errNoKey', provider.label);
      notifyListeners();
      return;
    }

    final List<Uint8List>? imagesToSend;
    final bool isFaceCrop;
    if (pendingScreenshots.isNotEmpty) {
      imagesToSend = List<Uint8List>.from(pendingScreenshots);
      clearPendingScreenshots();
      isFaceCrop = false;
    } else {
      imagesToSend = null;
      isFaceCrop = false;
    }

    await _streamHelp(
      provider: provider,
      apiKey: apiKey,
      model: config.modelFor(provider),
      prompt: _buildPrompt(
        withScreenshot: imagesToSend != null && imagesToSend.isNotEmpty,
        screenshotCount: imagesToSend?.length ?? 0,
        isFaceCrop: isFaceCrop,
      ),
      images: imagesToSend,
    );
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
    await _audioController.dispose();
    super.dispose();
  }
}
