import 'dart:convert';
import 'dart:io';

import 'llm_service.dart';

/// Локальные настройки приложения (роль SharedPreferences).
/// Хранятся в ~/.sobes_helper.json — всё, включая раскладку панелей и прозрачность.

/// Специальное значение themDeviceId: системный звук через ScreenCaptureKit (устаревшее).
const kSystemAudioDeviceId = '__sckit__';

class AppConfig {
  AppConfig({
    this.deepgramToken = defaultDeepgramToken,
    this.provider = LlmProvider.gemini,
    this.geminiKey = '',
    this.zaiKey = '',
    this.openaiKey = '',
    this.anthropicKey = '',
    this.geminiModel = kDefaultGeminiModel,
    this.zaiModel = kDefaultZaiModel,
    this.openaiModel = kDefaultOpenaiModel,
    this.anthropicModel = kDefaultAnthropicModel,
    Map<String, List<String>>? customModels,
    this.goals = defaultGoals,
    this.myProfile = '',
    this.interviewerProfile = '',
    this.deepgramModel = defaultDeepgramModel,
    this.languageHint = defaultLanguageHint,
    this.uiLang = 'ru',
    this.answerLang = 'auto',
    this.windowOpacity = 1.0,
    this.splitRatio = 0.34,
    this.hintColor = 0xFFE8EAED,
    this.fontSize = 14.0,
    this.boldText = false,
    this.turnSpacing = 5.0,
    this.llmContextTurns = defaultLlmContextTurns,
    this.autoCompressContext = defaultAutoCompressContext,
    this.compressThresholdChars = defaultCompressThresholdChars,
    this.compressKeepRecentTurns = defaultCompressKeepRecentTurns,
    this.hideFromScreenShare = false,
    this.alwaysOnTop = false,
    this.titlebarMode = 'transparent',
    this.myDeviceId = '',
    this.themDeviceId = '',
  }) : customModels = customModels ?? {};

  static const defaultDeepgramToken = '';
  static const defaultDeepgramModel = 'flux-general-multi';
  static const defaultLanguageHint = 'ru';
  static const defaultLlmContextTurns = 30;
  static const defaultAutoCompressContext = true;
  static const defaultCompressThresholdChars = 3500;
  static const defaultCompressKeepRecentTurns = 12;
  static const defaultGoals =
      'Пройти собеседование успешно и получить оффер: '
      'отвечать уверенно, структурированно (сначала суть, потом детали) и по делу; '
      'подчёркивать релевантный опыт и приводить конкретные примеры с результатами и цифрами; '
      'показывать интерес к компании и позиции; '
      'задавать уточняющие вопросы, если вопрос непонятен или неоднозначен; '
      'не критиковать бывших работодателей и коллег; '
      'если чего-то не знаю — честно сказать и описать, как бы разбирался; ничего не выдумывать.';

  String deepgramToken;
  LlmProvider provider;
  String geminiKey;
  String zaiKey;
  String openaiKey;
  String anthropicKey;
  String geminiModel;
  String zaiModel;
  String openaiModel;
  String anthropicModel;

  /// Добавленные пользователем модели по провайдерам.
  Map<String, List<String>> customModels;

  String goals;
  String myProfile;
  String interviewerProfile;
  String deepgramModel;
  String languageHint;
  String uiLang;

  /// Язык ответов LLM: 'auto' | 'ru' | 'en'.
  String answerLang;

  /// Прозрачность окна: 0.30–1.0.
  double windowOpacity;

  /// Доля высоты верхней панели (0.2–0.8).
  double splitRatio;

  /// Цвет текста подсказки и транскрипции (ARGB int).
  int hintColor;

  /// Размер шрифта текста (12–20).
  double fontSize;

  /// Жирный шрифт текста.
  bool boldText;

  /// Отступ между репликами в пикселях (0–20).
  double turnSpacing;

  /// Количество последних реплик диалога, отправляемых в LLM (5–100).
  int llmContextTurns;

  /// Включить автокомпрессию старой части контекста диалога в краткое резюме.
  bool autoCompressContext;

  /// Порог объёма текста (в символах) для запуска компрессии (1000–20000).
  int compressThresholdChars;

  /// Количество последних реплик диалога, которые никогда не сжимаются (4–50).
  int compressKeepRecentTurns;

  /// Скрыть окно от демонстрации экрана и скриншотов (NSWindow.SharingType.none).
  bool hideFromScreenShare;

  /// Держать окно поверх всех остальных окон (NSWindow.Level.floating).
  bool alwaysOnTop;

  /// Шапка окна: 'transparent' | 'opaque' | 'hidden' (свои кнопки закрытия).
  String titlebarMode;

  /// Входное аудиоустройство для своего микрофона ('' = системный по умолчанию).
  String myDeviceId;

  /// Входное аудиоустройство для голоса собеседника ('' = выключено).
  String themDeviceId;

  String modelFor(LlmProvider p) => switch (p) {
    LlmProvider.gemini => geminiModel,
    LlmProvider.zai => zaiModel,
    LlmProvider.openai => openaiModel,
    LlmProvider.anthropic => anthropicModel,
  };

  void setModelFor(LlmProvider p, String model) => switch (p) {
    LlmProvider.gemini => geminiModel = model,
    LlmProvider.zai => zaiModel = model,
    LlmProvider.openai => openaiModel = model,
    LlmProvider.anthropic => anthropicModel = model,
  };

  String keyFor(LlmProvider p) => switch (p) {
    LlmProvider.gemini => geminiKey,
    LlmProvider.zai => zaiKey,
    LlmProvider.openai => openaiKey,
    LlmProvider.anthropic => anthropicKey,
  };

  void setKeyFor(LlmProvider p, String key) => switch (p) {
    LlmProvider.gemini => geminiKey = key,
    LlmProvider.zai => zaiKey = key,
    LlmProvider.openai => openaiKey = key,
    LlmProvider.anthropic => anthropicKey = key,
  };

  /// Полный список моделей провайдера: пресеты + свои.
  List<String> modelsFor(LlmProvider p) => [
    ...kModelPresets[p.name] ?? const [],
    ...customModels[p.name] ?? const [],
  ];

  bool isCustomModel(LlmProvider p, String model) =>
      !(kModelPresets[p.name] ?? const []).contains(model);

  void addCustomModel(LlmProvider p, String model) {
    final list = customModels.putIfAbsent(p.name, () => []);
    if (!list.contains(model)) list.add(model);
  }

  void removeCustomModel(LlmProvider p, String model) =>
      customModels[p.name]?.remove(model);

  AppConfig clone() => AppConfig(
    deepgramToken: deepgramToken,
    provider: provider,
    geminiKey: geminiKey,
    zaiKey: zaiKey,
    openaiKey: openaiKey,
    anthropicKey: anthropicKey,
    geminiModel: geminiModel,
    zaiModel: zaiModel,
    openaiModel: openaiModel,
    anthropicModel: anthropicModel,
    customModels: {
      for (final e in customModels.entries) e.key: List<String>.of(e.value),
    },
    goals: goals,
    myProfile: myProfile,
    interviewerProfile: interviewerProfile,
    deepgramModel: deepgramModel,
    languageHint: languageHint,
    uiLang: uiLang,
    answerLang: answerLang,
    windowOpacity: windowOpacity,
    splitRatio: splitRatio,
    hintColor: hintColor,
    fontSize: fontSize,
    boldText: boldText,
    turnSpacing: turnSpacing,
    llmContextTurns: llmContextTurns,
    autoCompressContext: autoCompressContext,
    compressThresholdChars: compressThresholdChars,
    compressKeepRecentTurns: compressKeepRecentTurns,
    hideFromScreenShare: hideFromScreenShare,
    alwaysOnTop: alwaysOnTop,
    titlebarMode: titlebarMode,
    myDeviceId: myDeviceId,
    themDeviceId: themDeviceId,
  );

  Map<String, dynamic> toJson() => {
    'deepgramToken': deepgramToken,
    'provider': provider.name,
    'geminiKey': geminiKey,
    'zaiKey': zaiKey,
    'openaiKey': openaiKey,
    'anthropicKey': anthropicKey,
    'geminiModel': geminiModel,
    'zaiModel': zaiModel,
    'openaiModel': openaiModel,
    'anthropicModel': anthropicModel,
    'customModels': customModels,
    'goals': goals,
    'myProfile': myProfile,
    'interviewerProfile': interviewerProfile,
    'deepgramModel': deepgramModel,
    'languageHint': languageHint,
    'uiLang': uiLang,
    'answerLang': answerLang,
    'windowOpacity': windowOpacity,
    'splitRatio': splitRatio,
    'hintColor': hintColor,
    'fontSize': fontSize,
    'boldText': boldText,
    'turnSpacing': turnSpacing,
    'llmContextTurns': llmContextTurns,
    'autoCompressContext': autoCompressContext,
    'compressThresholdChars': compressThresholdChars,
    'compressKeepRecentTurns': compressKeepRecentTurns,
    'hideFromScreenShare': hideFromScreenShare,
    'alwaysOnTop': alwaysOnTop,
    'titlebarMode': titlebarMode,
    'myDeviceId': myDeviceId,
    'themDeviceId': themDeviceId,
  };

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
    deepgramToken: (j['deepgramToken'] as String?) ?? defaultDeepgramToken,
    provider: LlmProviderMeta.fromName(j['provider'] as String?),
    geminiKey: (j['geminiKey'] as String?) ?? '',
    zaiKey: (j['zaiKey'] as String?) ?? '',
    openaiKey: (j['openaiKey'] as String?) ?? '',
    anthropicKey: (j['anthropicKey'] as String?) ?? '',
    geminiModel: (j['geminiModel'] as String?) ?? kDefaultGeminiModel,
    zaiModel: (j['zaiModel'] as String?) ?? kDefaultZaiModel,
    openaiModel: (j['openaiModel'] as String?) ?? kDefaultOpenaiModel,
    anthropicModel: (j['anthropicModel'] as String?) ?? kDefaultAnthropicModel,
    customModels: (j['customModels'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    ),
    goals: (j['goals'] as String?) ?? defaultGoals,
    myProfile: (j['myProfile'] as String?) ?? '',
    interviewerProfile: (j['interviewerProfile'] as String?) ?? '',
    deepgramModel: (j['deepgramModel'] as String?) ?? defaultDeepgramModel,
    languageHint: (j['languageHint'] as String?) ?? defaultLanguageHint,
    uiLang: (j['uiLang'] as String?) ?? 'ru',
    answerLang: (j['answerLang'] as String?) ?? 'auto',
    windowOpacity: ((j['windowOpacity'] as num?) ?? 1.0).toDouble().clamp(
      0.0,
      1.0,
    ),
    splitRatio: ((j['splitRatio'] as num?) ?? 0.34).toDouble().clamp(0.2, 0.8),
    hintColor: (j['hintColor'] as int?) ?? 0xFFE8EAED,
    fontSize: ((j['fontSize'] as num?) ?? 14.0).toDouble().clamp(6.0, 24.0),
    boldText: (j['boldText'] as bool?) ?? false,
    turnSpacing:
        ((j['turnSpacing'] as num?) ?? 5.0).toDouble().clamp(0.0, 20.0),
    llmContextTurns:
        ((j['llmContextTurns'] as num?) ?? defaultLlmContextTurns)
            .toInt()
            .clamp(5, 100),
    autoCompressContext:
        (j['autoCompressContext'] as bool?) ?? defaultAutoCompressContext,
    compressThresholdChars:
        ((j['compressThresholdChars'] as num?) ?? defaultCompressThresholdChars)
            .toInt()
            .clamp(1000, 20000),
    compressKeepRecentTurns:
        ((j['compressKeepRecentTurns'] as num?) ??
                defaultCompressKeepRecentTurns)
            .toInt()
            .clamp(4, 50),
    hideFromScreenShare: (j['hideFromScreenShare'] as bool?) ?? false,
    alwaysOnTop: (j['alwaysOnTop'] as bool?) ?? false,
    titlebarMode:
        (j['titlebarMode'] as String?) ??
        (((j['titlebarTransparent'] as bool?) ?? true)
            ? 'transparent'
            : 'opaque'),
    myDeviceId: (j['myDeviceId'] as String?) ?? '',
    themDeviceId: () {
      final dev = (j['themDeviceId'] as String?) ?? '';
      return dev == '__sckit__' ? '' : dev;
    }(),
  );

  static File get _file =>
      File('${Platform.environment['HOME']}/.sobes_helper.json');

  static Future<AppConfig> load() async {
    try {
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return AppConfig.fromJson(j);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> save() async {
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }
}
