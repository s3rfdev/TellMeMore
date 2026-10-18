/// Простая локализация интерфейса: RU / EN.
class S {
  S._();

  static String lang = 'ru';

  static String t(String key, [String? p0]) {
    final row = _d[key];
    var s = row == null ? key : (row[lang] ?? row['ru'] ?? key);
    if (p0 != null) s = s.replaceFirst('{0}', p0);
    return s;
  }
}

const Map<String, Map<String, String>> _d = {
  // --- Помощь (верхняя панель) ---
  'helpTitle': {'ru': 'ПОДСКАЗКА', 'en': 'HINT'},
  'thinking': {'ru': 'Думаю…', 'en': 'Thinking…'},
  'generating': {'ru': 'Печатает…', 'en': 'Generating…'},
  'stopGeneration': {'ru': 'Остановить ответ', 'en': 'Stop generation'},
  'hintPlaceholder': {
    'ru':
        'Нажмите «Get answer» (⌥1) — получите короткую подсказку, что сказать дальше.',
    'en': 'Press "Get answer" (⌥1) for a short hint on what to say next.',
  },
  'screenshotAnswer': {
    'ru': 'Скриншот экрана + подсказка (⌥2) (для задач по коду)',
    'en': 'Screen capture + hint (⌥2) (for code challenges)',
  },
  'addScreenshot': {
    'ru': 'Добавить скриншот в каретку (⌥3)',
    'en': 'Add screenshot to queue (⌥3)',
  },
  'sendQueuedScreenshots': {
    'ru': 'Отправить закреплённые скриншоты на анализ (⌥2)',
    'en': 'Send queued screenshots for analysis (⌥2)',
  },
  'clearScreenshots': {
    'ru': 'Очистить каретку скриншотов',
    'en': 'Clear screenshot queue',
  },
  'removeScreenshot': {
    'ru': 'Удалить скриншот',
    'en': 'Remove screenshot',
  },
  'screenshotsAttached': {
    'ru': 'Скриншотов в каретке',
    'en': 'Screenshots in queue',
  },
  'newFollowUpTask': {
    'ru': 'Новая задача (сбросить контекст)',
    'en': 'New task (reset context)',
  },
  'followUpRound': {
    'ru': 'Раунд уточнения',
    'en': 'Follow-up round',
  },
  'chatHistoryMenu': {
    'ru': 'История чата (очистка, экспорт, импорт)',
    'en': 'Chat history (clear, export, import)',
  },
  'clearChat': {'ru': 'Очистить чат', 'en': 'Clear chat'},
  'clearChatTitle': {
    'ru': 'Очистить историю чата?',
    'en': 'Clear chat history?',
  },
  'clearChatConfirm': {
    'ru':
        'Все реплики текущего диалога будут удалены. Это действие нельзя отменить.',
    'en':
        'All turns in the current dialogue will be deleted. This cannot be undone.',
  },
  'clearAction': {'ru': 'Очистить', 'en': 'Clear'},
  'chatCleared': {'ru': 'История чата очищена', 'en': 'Chat history cleared'},
  'chatEmptyExport': {
    'ru': 'Чат пуст — нечего экспортировать',
    'en': 'Chat is empty — nothing to export',
  },
  'exportChat': {'ru': 'Экспорт чата…', 'en': 'Export chat…'},
  'importChat': {'ru': 'Импорт чата…', 'en': 'Import chat…'},
  'exportSuccess': {
    'ru': 'Чат успешно сохранён',
    'en': 'Chat saved successfully',
  },
  'exportFailed': {
    'ru': 'Ошибка при сохранении чата',
    'en': 'Failed to save chat',
  },
  'importSuccess': {
    'ru': 'Загружено реплик: {0}',
    'en': 'Imported {0} turns',
  },
  'importFailed': {'ru': 'Ошибка импорта чата', 'en': 'Chat import failed'},
  'importEmptyError': {
    'ru': 'Файл не содержит распознанных реплик диалога',
    'en': 'File does not contain valid dialogue turns',
  },
  'settings': {'ru': 'Настройки', 'en': 'Settings'},

  // --- Транскрипция (нижняя панель) ---
  'transcriptTitle': {'ru': 'ТРАНСКРИПЦИЯ', 'en': 'TRANSCRIPT'},
  'statusIdle': {'ru': 'Остановлено', 'en': 'Stopped'},
  'statusConnecting': {'ru': 'Подключение…', 'en': 'Connecting…'},
  'statusListening': {'ru': 'Слушаю…', 'en': 'Listening…'},
  'startStream': {'ru': 'Начать стрим', 'en': 'Start Stream'},
  'stop': {'ru': 'Остановить', 'en': 'Stop'},
  'you': {'ru': 'Me', 'en': 'Me'},
  'interviewer': {'ru': 'Оппонент', 'en': 'Оппонент'},
  'emptyTranscript': {
    'ru':
        'Нажмите «Начать стрим» и говорите —\nздесь появится текст разговора с метками спикеров.',
    'en':
        'Press "Start Stream" and talk —\nthe live transcript will appear here.',
  },

  // --- Сообщения сессии ---
  'errNoKey': {
    'ru': 'Ключ {0} не задан — откройте настройки (⚙) и вставьте ключ.',
    'en': 'The {0} API key is not set — open Settings (⚙) and paste the key.',
  },
  'errEmptyTranscript': {
    'ru': 'Стенограмма пуста — сначала включите стрим и говорите.',
    'en': 'The transcript is empty — start the stream and talk first.',
  },
  'errMicDenied': {
    'ru':
        'Нет доступа к микрофону — разрешите запись при запросе или в Системных настройках',
    'en':
        'No microphone access — allow recording when prompted, or in System Settings',
  },
  'errDgClosed': {
    'ru': 'Соединение с Deepgram закрыто',
    'en': 'Deepgram connection closed',
  },

  // --- Настройки ---
  'settingsTitle': {'ru': 'Настройки', 'en': 'Settings'},
  'tabContext': {'ru': 'Контекст', 'en': 'Context'},
  'tabUi': {'ru': 'Вид', 'en': 'UI'},
  'sectionText': {'ru': 'ТЕКСТ', 'en': 'TEXT'},
  'sectionLlm': {'ru': 'НЕЙРОСЕТЬ ДЛЯ ПОДСКАЗОК', 'en': 'HINT PROVIDER'},
  'provider': {'ru': 'Провайдер', 'en': 'Provider'},
  'model': {'ru': 'Модель', 'en': 'Model'},
  'customModel': {'ru': 'Своя модель…', 'en': 'Custom model…'},
  'addModel': {'ru': 'Добавить', 'en': 'Add'},
  'modelIdHint': {
    'ru': 'ID модели, напр. glm-5.3',
    'en': 'model ID, e.g. glm-5.3',
  },
  'deleteModel': {
    'ru': 'Удалить свою модель из списка',
    'en': 'Remove custom model from list',
  },
  'answerLang': {'ru': 'ЯЗЫК ОТВЕТОВ', 'en': 'ANSWER LANGUAGE'},
  'langAuto': {'ru': 'Авто', 'en': 'Auto'},
  'langRu': {'ru': 'Русский', 'en': 'Russian'},
  'langEn': {'ru': 'Английский', 'en': 'English'},
  'uiLanguage': {'ru': 'ЯЗЫК ИНТЕРФЕЙСА', 'en': 'INTERFACE LANGUAGE'},
  'sectionAudio': {'ru': 'АУДИО', 'en': 'AUDIO'},
  'sectionContext': {'ru': 'КОНТЕКСТ ДЛЯ ПОДСКАЗОК', 'en': 'HINT CONTEXT'},
  'sectionLook': {'ru': 'ВНЕШНИЙ ВИД', 'en': 'APPEARANCE'},
  'bgOpacity': {'ru': 'Прозрачность окна', 'en': 'Window transparency'},
  'titlebarMode': {'ru': 'Шапка окна', 'en': 'Titlebar'},
  'tbTransparent': {'ru': 'Прозрачная', 'en': 'Translucent'},
  'tbOpaque': {'ru': 'Плотная', 'en': 'Solid'},
  'tbHidden': {'ru': 'Скрытая', 'en': 'Hidden'},
  'winMinimize': {'ru': 'Свернуть', 'en': 'Minimize'},
  'winClose': {'ru': 'Закрыть', 'en': 'Close'},
  'mySource': {'ru': 'Ваш микрофон', 'en': 'Your microphone'},
  'deviceDefault': {'ru': 'По умолчанию в системе', 'en': 'System default'},
  'themSource': {'ru': 'Голос собеседника', 'en': 'Interviewer voice'},
  'deviceNone': {
    'ru': 'Отключено (только микрофон)',
    'en': 'Disabled (mic only)',
  },
  'llmContextTurns': {
    'ru': 'Реплик диалога в запросе к LLM',
    'en': 'Recent dialogue turns sent to LLM',
  },
  'llmContextTurnsHint': {
    'ru': 'Рекомендуется 8–10 (4–5 раундов вопрос-ответ). Они всегда передаются дословно.',
    'en': 'Recommended 8–10 (4–5 Q&A rounds). These are always sent verbatim.',
  },
  'autoCompressContext': {
    'ru': 'Автокомпрессия длинного диалога',
    'en': 'Auto-compress long conversation',
  },
  'autoCompressContextSub': {
    'ru': 'Сжимает старые реплики в ёмкое резюме при накоплении текста',
    'en': 'Summarizes older dialogue when text volume reaches threshold',
  },
  'compressThreshold': {
    'ru': 'Порог сжатия по объёму текста: {0} симв.',
    'en': 'Compression text volume threshold: {0} chars',
  },
  'compressThresholdHint': {
    'ru': '~2500 символов — это 6–10 содержательных реплик старого диалога',
    'en': '~2500 characters is roughly 6–10 substantive turns of older dialogue',
  },
  'compressKeepRecent': {
    'ru': 'Хранить свежих реплик без сжатия: {0}',
    'en': 'Keep recent live turns verbatim: {0}',
  },
  'compressKeepRecentHint': {
    'ru': 'Эти последние реплики отправляются в нейросеть дословно',
    'en': 'These recent turns are sent to the LLM verbatim and never compressed',
  },
  'compressNow': {
    'ru': 'Сжать историю сейчас',
    'en': 'Compress history now',
  },
  'compressing': {
    'ru': 'Сжатие диалога…',
    'en': 'Compressing dialogue…',
  },
  'activeSummary': {
    'ru': 'Резюме активно ({0} симв.)',
    'en': 'Active summary ({0} chars)',
  },
  'noSummaryYet': {
    'ru': 'Резюме пока нет',
    'en': 'No summary yet',
  },
  'resetSummary': {
    'ru': 'Сбросить резюме',
    'en': 'Reset summary',
  },
  'unsummarizedVolume': {
    'ru': 'Накоплено без сжатия: {0} / {1} симв.',
    'en': 'Unsummarized buffer: {0} / {1} chars',
  },
  'showKey': {'ru': 'Показать ключ', 'en': 'Show key'},
  'hideKey': {'ru': 'Скрыть ключ', 'en': 'Hide key'},
  'checkModel': {'ru': 'Проверить ключ и модель', 'en': 'Test key & model'},
  'checkOk': {'ru': 'Работает', 'en': 'Works'},
  'checkRunning': {'ru': 'Проверяю…', 'en': 'Checking…'},
  'checkFail': {'ru': 'Ошибка', 'en': 'Error'},
  'titlebarTransparent': {
    'ru': 'Прозрачная шапка окна',
    'en': 'Transparent titlebar',
  },
  'textColor': {'ru': 'Цвет текста', 'en': 'Text color'},
  'brightness': {'ru': 'Яркость / тон', 'en': 'Text brightness / shade'},
  'customColor': {'ru': 'Свой цвет', 'en': 'Custom color'},
  'hue': {'ru': 'Оттенок', 'en': 'Hue'},
  'saturation': {'ru': 'Насыщенность', 'en': 'Saturation'},
  'fontSize': {'ru': 'Размер шрифта', 'en': 'Font size'},
  'boldText': {'ru': 'Жирный шрифт', 'en': 'Bold text'},
  'resizeHint': {
    'ru': 'Потяните, чтобы изменить размер панелей',
    'en': 'Drag to resize panels',
  },
  'keySet': {'ru': 'Ключ задан', 'en': 'Key is set'},
  'keyMissing': {'ru': 'Ключ не задан', 'en': 'Key is not set'},
  'startTooltip': {
    'ru': 'Включить транскрибацию',
    'en': 'Turn on transcription',
  },
  'stopTooltip': {
    'ru': 'Выключить транскрибацию',
    'en': 'Turn off transcription',
  },
  'deepgramToken': {'ru': 'Deepgram API Token', 'en': 'Deepgram API Token'},
  'geminiKey': {'ru': 'Google Gemini API Key', 'en': 'Google Gemini API Key'},
  'zaiKey': {'ru': 'Z.ai (GLM) API Key', 'en': 'Z.ai (GLM) API Key'},
  'openaiKey': {'ru': 'OpenAI API Key', 'en': 'OpenAI API Key'},
  'anthropicKey': {'ru': 'Anthropic API Key', 'en': 'Anthropic API Key'},
  'myProfile': {
    'ru': 'Обо мне',
    'en': 'About me',
  },
  'myProfileHint': {
    'ru': 'опыт, навыки, позиция, контекст — чтобы подсказки были от вашего лица',
    'en': 'experience, skills, context — hints will speak in your voice',
  },
  'interviewerProfile': {
    'ru': 'Об оппоненте',
    'en': 'About the opponent',
  },
  'interviewerHint': {
    'ru': 'роль, компания, позиция, стиль общения, цели на переговорах',
    'en': 'role, company, position, style, negotiation goals',
  },
  'goals': {
    'ru': 'Мои цели и критерии (учитываются в подсказках)',
    'en': 'My goals & criteria (used for hints)',
  },
  'load': {'ru': 'Загрузить', 'en': 'Load'},
  'loadFailed': {
    'ru': 'Не удалось прочитать файл',
    'en': 'Could not read the file',
  },
  'cancel': {'ru': 'Отмена', 'en': 'Cancel'},
  'save': {'ru': 'Сохранить', 'en': 'Save'},
  'turnSpacing': {
    'ru': 'Отступ между репликами',
    'en': 'Spacing between turns',
  },
  'checkAction': {'ru': 'Тест', 'en': 'Test'},
  'checkSuccessTitle': {
    'ru': 'Проверка успешна',
    'en': 'Check successful',
  },
  'checkErrorTitle': {
    'ru': 'Ошибка проверки',
    'en': 'Check failed',
  },
  'checkSuccessDesc': {
    'ru': 'Ключ и выбранная модель работают корректно. Ответ получен.',
    'en': 'API key and model are working properly. Response received.',
  },
  'closeDialog': {'ru': 'Закрыть', 'en': 'Close'},
  'hideFromScreenShare': {
    'ru': 'Скрыть от демонстрации экрана',
    'en': 'Hide from screen sharing',
  },
  'hideFromScreenShareSub': {
    'ru': 'Невидимо в Zoom, Meet, Teams и скриншотах, но видно вам',
    'en': 'Invisible in Zoom, Meet, Teams and screenshots, visible to you',
  },
  'alwaysOnTop': {
    'ru': 'Поверх всех окон',
    'en': 'Always on top',
  },
  'alwaysOnTopSub': {
    'ru': 'Окно остаётся поверх браузера и других приложений',
    'en': 'Keeps window above browser and other apps',
  },
  'sectionHotkeys': {
    'ru': 'ГОРЯЧИЕ КЛАВИШИ (MAC)',
    'en': 'GLOBAL SHORTCUTS (MAC)',
  },
  'hotkeyGetAnswer': {'ru': 'Получить ответ', 'en': 'Get answer'},
  'hotkeyGetAnswerDesc': {
    'ru': 'Работает глобально, даже когда окно не в фокусе',
    'en': 'Works globally even when app is in background',
  },
  'hotkeyScreenshot': {
    'ru': 'Ответ со скриншотом экрана',
    'en': 'Answer with screen capture',
  },
  'hotkeyScreenshotDesc': {
    'ru': 'Скриншот экрана + код задачи в LLM',
    'en': 'Screen capture + code challenge to LLM',
  },
};
