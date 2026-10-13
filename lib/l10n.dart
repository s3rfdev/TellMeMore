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
  'hintPlaceholder': {
    'ru':
        'Нажмите «Get answer» — получите короткую подсказку, что сказать дальше.',
    'en': 'Press "Get answer" for a short hint on what to say next.',
  },
  'settings': {'ru': 'Настройки', 'en': 'Settings'},

  // --- Транскрипция (нижняя панель) ---
  'transcriptTitle': {'ru': 'ТРАНСКРИПЦИЯ', 'en': 'TRANSCRIPT'},
  'statusIdle': {'ru': 'Остановлено', 'en': 'Stopped'},
  'statusConnecting': {'ru': 'Подключение…', 'en': 'Connecting…'},
  'statusListening': {'ru': 'Слушаю…', 'en': 'Listening…'},
  'startStream': {'ru': 'Начать стрим', 'en': 'Start Stream'},
  'stop': {'ru': 'Остановить', 'en': 'Stop'},
  'you': {'ru': 'Вы', 'en': 'Me'},
  'interviewer': {'ru': 'Собеседник', 'en': 'Interviewer'},
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
  'deviceOff': {
    'ru': 'Авто: по голосам (один микрофон)',
    'en': 'Auto: by voice (single mic)',
  },
  'deviceSystemAudio': {
    'ru': 'Системный звук (Chrome/YouTube)',
    'en': 'System audio (Chrome/YouTube)',
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
    'ru': 'Информация обо мне (кандидате)',
    'en': 'About me (the candidate)',
  },
  'myProfileHint': {
    'ru': 'опыт, навыки, проекты — чтобы подсказки были от вашего лица',
    'en': 'experience, skills, projects — hints will speak in your voice',
  },
  'interviewerProfile': {
    'ru': 'Информация о собеседнике',
    'en': 'About the interviewer',
  },
  'interviewerHint': {
    'ru': 'роль, компания, что ценит, стиль общения',
    'en': 'role, company, what they value, style',
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
};
