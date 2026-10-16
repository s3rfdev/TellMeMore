// ==========================================================================
// TellMeMore Ecosystem — Core Application Script
// Deep Azure & Cognitive Profiling Theme
// Bilingual (RU/EN with auto-detect), Dark/Light mode, Interactive AI Inspector
// ==========================================================================

(function () {
  'use strict';

  // ==================== I18N DICTIONARIES ====================
  const translations = {
    ru: {
      navProducts: 'Продукты',
      navPhilosophy: 'Суть',
      navRoadmap: 'Роадмап',
      kickerText: 'СЛУШАЙ  •  ЧИТАЙ  •  ПОНИМАЙ',
      heroTitleLead: 'Глубокий анализ',
      heroTitleFocus: 'собеседника.',
      heroSubtitle: 'ИИ-инструменты для распознавания эмоций, намерений и скрытых мотивов — в живом разговоре и переписке.',
      btnExplore: 'Изучить продукты →',
      btnDemoText: 'Демо',
      facesCaption: 'ЭМОЦИИ  •  НАМЕРЕНИЯ  •  НАСТОЯЩИЕ МОТИВЫ',
      tabChat: 'Анализ переписки',
      tabVoice: 'Анализ разговора',
      chatSender: 'Александр',
      chatMsgText: '«Мне кажется, это не лучшая идея... Но я всё равно попробую.»',
      inspectorBreakdownTitle: 'Анализ сообщения',
      metricConfidence: 'Уверенность',
      metricDoubt: 'Сомнение',
      metricInterest: 'Интерес',
      metricHiddenGoal: 'Скрытая цель',
      goalCardTitle: 'Возможная цель:',
      goalCardDesc: 'Сохранить контроль, но согласиться',
      voiceInterviewerLabel: 'Интервьюер (Tech Lead):',
      voiceInterviewerMsg: '«Как вы решали проблему деградации базы данных при резких всплесках трафика на прошлом проекте?»',
      voiceWhispererLabel: 'Подсказка суфлёра (голос кандидата):',
      voiceWhispererHint: '«В микросервисах на Go мы вынесли кэш в Redis Cluster с LRU, сократив p99 latency с 450мс до 12мс при 20k RPS».',
      voiceLatencyLabel: 'Задержка слуха:',
      voiceLatencyVal: '<300 мс (Deepgram)',
      voiceStealthLabel: 'Невидимость экрана:',
      voiceStealthVal: '100% Zoom / Meet',
      sectionPhilosophyPill: 'В ЧЁМ СУТЬ ИДЕИ',
      sectionPhilosophyTitle: 'Коммуникация как точный инструмент',
      sectionPhilosophySub: 'Побеждает не тот, кто говорит громче, а тот, кто отсекает лишний шум, контролирует скрытый контекст и не отходит от поставленной цели.',
      pillar1Title: 'Не отходить от объекта',
      pillar1Desc: 'В спорах и интервью нас постоянно уводят в сторону встречными вопросами. TellMeMore непрерывно держит главную цель в фокусе и возвращает диалог в нужное русло.',
      pillar2Title: 'Удалить лишний шум',
      pillar2Desc: 'Никаких долгих пауз, растерянности и размытых фраз. ИИ мгновенно вычленяет суть и формулирует лаконичную, сильную реплику прямо в процессе диалога.',
      pillar3Title: 'Скрытый контекст и подтекст',
      pillar3Desc: 'Люди редко говорят то, что думают на самом деле. Система анализирует подтекст, скрытые сомнения, пассивную агрессию и истинные мотивы собеседника.',
      pillar4Title: 'Защита от манипуляций',
      pillar4Desc: 'Выявление психологических уловок и ловушек. При необходимости — выдача стратегических реплик для перехвата инициативы и управления исходом беседы.',
      sectionProductsPill: 'ЛИНЕЙКА ПРОДУКТОВ',
      sectionProductsTitle: 'Единая экосистема для голоса и текста',
      sectionProductsSub: 'Бесплатные инструменты с открытым исходным кодом, созданные для победы в любой дискуссии.',
      tmmBadgeStatus: 'v1.1 Универсальный • Голос + Экран',
      tmmTitle: 'TellMeMore',
      tmmDesc: 'Универсальный ИИ-суфлёр реального времени для онлайн-собеседований, live-кодинга и переговоров на macOS. Анализирует речь собеседника и делает мгновенный захват экрана с терминалом или IDE, подсказывая решения задач и точные формулировки прямо во время беседы.',
      tmmFeat1: '<strong>Сверхбыстрый слух (<300 мс):</strong> потоковая транскрибация вашего микрофона и звука собеседника через Deepgram Nova-2 / Flux.',
      tmmFeat2: '<strong>Суфлёр от первого лица:</strong> подсказки голосом кандидата с учётом вашего опыта, резюме и целей встречи.',
      tmmFeat3: '<strong>Универсальное зрение экрана (⌥2):</strong> делает мгновенный снимок IDE/терминала и выдаёт готовый код с объяснением алгоритма.',
      tmmFeat4: '<strong>Умная автокомпрессия диалога:</strong> сжимает часовую беседу по объёму символов в плотную память, предотвращая переполнение контекста.',
      tmmFeat5: '<strong>100% невидимость:</strong> полностью скрыто от демонстрации экрана и записи в Zoom, Google Meet и Teams.',
      tmmBtnDownload: 'Скачать на GitHub →',
      tmmLicenseNote: 'Лицензия MIT • Полностью бесплатно',
      tgBadgeStatus: 'TDLib Core • Свежие апдейты',
      tgPlatformsBadge: 'Android • Win • Linux • macOS',
      tgTitle: 'TellMeMore TG',
      tgDesc: 'Полноценный кроссплатформенный клиент Telegram на базе TDLib со встроенным ИИ-мозгом для глубокого анализа переписок, профайлинга участников, детекции скрытых манипуляций и формирования тактических рекомендаций.',
      tgFeat1: '<strong>Психологический профайлинг:</strong> сканирует историю чатов, составляет карту психотипа, слабых мест и манеры общения собеседника.',
      tgFeat2: '<strong>Радар манипуляций:</strong> мгновенно подсвечивает попытки давления, пассивной агрессии, газлайтинга или увода от темы.',
      tgFeat3: '<strong>Тактический генератор фраз:</strong> предлагает 2–3 варианта ответа — от дипломатичного выхода до решительного перехвата контроля.',
      tgFeat4: '<strong>Архитектура TDLib & CRM:</strong> единое ядро Telegram для мобильных и десктопных систем с базой досье контактов и RAG-памятью.',
      tgBtnFollow: 'Следить за разработкой на GitHub →',
      chromeBadgeStatus: 'v1.0 Релиз • Готово к установке',
      chromePlatformsBadge: 'Facebook Messenger • Telegram Web • Chrome Ext',
      chromeTitle: 'TellMeMore Copilot',
      chromeDesc: 'Легковесное расширение для Chrome (Manifest V3), превращающее веб-версии Facebook Messenger и Telegram Web в мощную переговорную среду. Встроенная боковая панель (SidePanel) сканирует открытый диалог в реальном времени, вычисляет скрытые психологические манипуляции и в один клик вставляет победный тактический ответ прямо в чат.',
      chromeFeat1: '<strong>Радар манипуляций в Facebook & Telegram:</strong> мгновенно выявляет газлайтинг, искусственную спешку, ложный дефицит, пассивную агрессию и смещение рамок.',
      chromeFeat2: '<strong>Стратегический метод «Сэндвича» в 1 клик:</strong> формирует варианты ответа (удержание границ, деэскалация, контрпредложение) и вставляет выбранный текст в поле ввода сообщения.',
      chromeFeat3: '<strong>Поддержка web.telegram.org & facebook.com/messages:</strong> нативные реактивные наблюдатели (MutationObserver) для динамических веб-чатов без задержек.',
      chromeFeat4: '<strong>Мульти-LLM ядро & голосовой ввод:</strong> выбор между Gemini 3.7/3.5 Flash, GLM-4.5/5, GPT-4o, Grok, локальными моделями Ollama/vLLM и диктовкой через Deepgram / Whisper.',
      chromeFeat5: '<strong>100% приватность (Zero-Cloud):</strong> API-ключи, история чатов и досье контактов сохраняются исключительно в локальном хранилище браузера (IndexedDB / chrome.storage).',
      chromeBtnDownload: 'Открыть репозиторий на GitHub →',
      chromeLicenseNote: 'Manifest V3 • Лицензия MIT • Полностью бесплатно',
      roadmapPill: 'ПЛАН РАЗВИТИЯ',
      roadmapTitle: 'Дорожная карта экосистемы',
      roadmapSub: 'От локального суфлёра собеседований на macOS до глобальной мультиязычной платформы осознанной коммуникации.',
      q4Period: 'Q4 2026 • ЗАВЕРШЕНО',
      q4Title: 'TellMeMore macOS — Универсальный живой суфлёр',
      q4Desc: 'Потоковое распознавание Deepgram (<300 мс), Gemini 3.8/Claude 3.5, решение задач с экрана (⌥2), скрытность в Zoom/Meet, автокомпрессия контекста.',
      q4ChromePeriod: 'Q4 2026 • ЗАВЕРШЕНО',
      q4ChromeTitle: 'TellMeMore Copilot — Chrome Extension для Facebook & Telegram',
      q4ChromeDesc: 'Расширение Manifest V3 для веб-чатов: встроенная боковая панель (SidePanel), радар психологических манипуляций, детекция тактик в Facebook Messenger и Telegram Web, авто-вставка ответов в 1 клик.',
      q1Period: 'Q1 2027 • В РАЗРАБОТКЕ',
      q1Title: 'TellMeMore TG — Кроссплатформенный Telegram с ИИ-профайлингом',
      q1Desc: 'Клиент Telegram на TDLib для Android, Windows, Linux и macOS. Глубокий аудит собеседников, радар манипуляций Sherlock и тактическое сопровождение переписок.',
      q2Period: 'Q2 2027 • ЗАПЛАНИРОВАНО',
      q2Title: 'TellMeMore Desktop для Windows и Linux',
      q2Desc: 'Перенос универсального суфлёра и визуального анализатора экрана с macOS на Windows и Linux (WASAPI / PipeWire).',
      footerTagline: 'Создано для того, чтобы убрать шум и всегда добиваться поставленных целей.',
      footerRepo: 'TellMeMore (macOS)',
      footerRepoTG: 'TellMeMore TG',
      footerRepoChrome: 'TellMeMore Chrome',
      footerProfile: 'Профиль разработчика',
      tmmTab1: 'Live HUD',
      tmmTab1Desc: 'Сверхбыстрый суфлёр поверх окон с подсказками от первого лица и разделением спикеров',
      tmmTab2: 'Профиль',
      tmmTab2Desc: 'Заполнение резюме, заметки об интервьюере и формулирование целей встречи',
      tmmTab3: 'LLM & Память',
      tmmTab3Desc: 'Выбор Gemini / Claude, скользящее окно и умное сжатие истории диалога',
      tmmTab4: 'Скрытность',
      tmmTab4Desc: '100% невидимость в Zoom/Meet, прозрачность 0–100% и хоткеи ⌥1 / ⌥2',
      tgTab1: 'Мессенджер',
      tgTab1Desc: 'Полнофункциональный клиент Telegram с панелью быстрых ИИ-действий (автоответ, Copilot)',
      tgTab2: 'AI Copilot',
      tgTab2Desc: 'Персональный рабочий диалог с ассистентом, радар манипуляций и анализ мотивов',
      tgTab3: 'Sherlock',
      tgTab3Desc: 'Глубинный психологический аудит, детекция ловушек для эго и выработка тактики ответа',
      tgTab4: 'CRM Досье',
      tgTab4Desc: 'Психотип контакта, Tone of Voice, цели коммуникации и реестр ключевых договоренностей',
      chromeTab1: 'Facebook Messenger',
      chromeTab1Desc: 'Copilot SidePanel в Facebook Messenger: радар манипуляций, расчет риска и стратегические реплики с быстрой вставкой',
      chromeTab2: 'Telegram Web',
      chromeTab2Desc: 'Интеграция с Telegram Web (версии A и K): анализ входящих сообщений собеседника и генерация тактических ответов',
      chromeTab3: 'Модели & Голос',
      chromeTab3Desc: 'Выбор LLM-провайдеров (Google Gemini, Z-AI, OpenAI, xAI, Local Ollama) и параметров голосового ввода (Deepgram, Groq)',
      zoomHint: 'Нажмите для увеличения'
    },
    en: {
      navProducts: 'Products',
      navPhilosophy: 'Philosophy',
      navRoadmap: 'Roadmap',
      kickerText: 'LISTEN  •  READ  •  UNDERSTAND',
      heroTitleLead: 'Deep Analysis',
      heroTitleFocus: 'of Any Participant.',
      heroSubtitle: 'AI tools to decode emotions, hidden intentions, and tactical subtext — in live speech and messaging.',
      btnExplore: 'Explore Products →',
      btnDemoText: 'Demo',
      facesCaption: 'EMOTIONS  •  INTENTIONS  •  TRUE MOTIVES',
      tabChat: 'Chat Analysis',
      tabVoice: 'Voice Co-Pilot',
      chatSender: 'Alexander',
      chatMsgText: '“I feel like this might not be the best idea... But I will try anyway.”',
      inspectorBreakdownTitle: 'Message Breakdown',
      metricConfidence: 'Confidence',
      metricDoubt: 'Doubt',
      metricInterest: 'Interest',
      metricHiddenGoal: 'Hidden Agenda',
      goalCardTitle: 'Identified Intent:',
      goalCardDesc: 'Maintain control while agreeing',
      voiceInterviewerLabel: 'Interviewer (Tech Lead):',
      voiceInterviewerMsg: '“How did you handle database degradation during sudden traffic spikes in your previous project?”',
      voiceWhispererLabel: 'Whisperer Co-Pilot (in candidate voice):',
      voiceWhispererHint: '“In our Go microservices, we offloaded hot caching to Redis Cluster with LRU, shrinking p99 latency from 450ms down to 12ms at 20k RPS.”',
      voiceLatencyLabel: 'Speech Latency:',
      voiceLatencyVal: '<300 ms (Deepgram)',
      voiceStealthLabel: 'Screen Stealth:',
      voiceStealthVal: '100% Zoom / Meet',
      sectionPhilosophyPill: 'THE CORE PHILOSOPHY',
      sectionPhilosophyTitle: 'Communication as a Precision Instrument',
      sectionPhilosophySub: 'The winner is not who talks the loudest, but who cuts the noise, reads the subtext, and never deviates from the target.',
      pillar1Title: 'Stay on Target',
      pillar1Desc: 'In heated debates and interviews, tricky questions constantly derail you. TellMeMore anchors the main objective and steers the conversation back to your agenda.',
      pillar2Title: 'Eliminate the Noise',
      pillar2Desc: 'No awkward silences, panic, or vague fluff. The AI extracts the essence instantly and formulates a razor-sharp, confident response on the fly.',
      pillar3Title: 'Hidden Context & Subtext',
      pillar3Desc: 'People rarely say what they actually mean. The system analyzes subtext, passive aggression, unstated doubts, and the true motivations of the other party.',
      pillar4Title: 'Shield & Strategic Influence',
      pillar4Desc: 'Spot psychological traps, guilt trips, and deflections. When needed, deploy strategic phrasing to seize the initiative and guide the outcome.',
      sectionProductsPill: 'PRODUCT LINEUP',
      sectionProductsTitle: 'Unified Ecosystem for Voice and Text',
      sectionProductsSub: 'Free open-source tools engineered to help you triumph in any high-stakes interaction.',
      tmmBadgeStatus: 'v1.1 Universal • Voice + Screen Vision',
      tmmTitle: 'TellMeMore',
      tmmDesc: 'Universal real-time AI co-pilot for online job interviews, live coding, and negotiations on macOS. Combines ultra-low latency voice transcription with instant screen capture of IDE/terminal windows, generating optimal solutions and razor-sharp talking points on the fly.',
      tmmFeat1: '<strong>Ultra-low latency (<300 ms):</strong> live streaming transcription of your mic and interviewer voice via Deepgram Nova-2 / Flux.',
      tmmFeat2: '<strong>First-person whisperer:</strong> crafts confident answers in your voice based on your resume, experience, and interview goals.',
      tmmFeat3: '<strong>Universal Screen Vision (⌥2):</strong> captures your IDE, terminal, or slide window and delivers working code solutions with step-by-step explanations.',
      tmmFeat4: '<strong>Smart text volume auto-compression:</strong> condenses hours of dialogue into dense structured memory, preventing context overflow.',
      tmmFeat5: '<strong>100% invisible:</strong> excluded from screen recording and sharing in Zoom, Google Meet, and Microsoft Teams.',
      tmmBtnDownload: 'Download on GitHub →',
      tmmLicenseNote: 'MIT License • 100% Free & Open Source',
      tgBadgeStatus: 'TDLib Core • Recent Updates',
      tgPlatformsBadge: 'Android • Win • Linux • macOS',
      tgTitle: 'TellMeMore TG',
      tgDesc: 'A full-featured cross-platform Telegram client built on TDLib with built-in AI profiling, manipulation detection, and real-time tactical suggestions for chat negotiation.',
      tgFeat1: '<strong>Psychological profiling:</strong> analyzes chat history to chart the temperament, vulnerabilities, and communication style of any user.',
      tgFeat2: '<strong>Manipulation radar:</strong> flags gaslighting, passive aggression, guilt-tripping, and deflection in real time.',
      tgFeat3: '<strong>Tactical reply generator:</strong> offers calibrated replies — from graceful de-escalation to decisive dominance.',
      tgFeat4: '<strong>TDLib Core & CRM Architecture:</strong> native Telegram engine across mobile and desktop systems with a contact dossier database and RAG memory.',
      tgBtnFollow: 'Follow Development on GitHub →',
      chromeBadgeStatus: 'v1.0 Release • Ready to Install',
      chromePlatformsBadge: 'Facebook Messenger • Telegram Web • Chrome Ext',
      chromeTitle: 'TellMeMore Copilot',
      chromeDesc: 'Lightweight browser extension (Manifest V3) that empowers Facebook Messenger and Telegram Web with real-time AI negotiation intelligence. Operating in a native SidePanel, it observes active chats, calculates manipulation risk scores, and inserts winning tactical replies into the input field with a single click.',
      chromeFeat1: '<strong>Manipulation Radar in Facebook & Telegram:</strong> real-time detection of gaslighting, artificial urgency, false scarcity, passive aggression, and shifting goalposts.',
      chromeFeat2: '<strong>Strategic "Sandwich" Replies with 1-Click Insert:</strong> crafts multi-angle tactical counter-moves and pastes them straight into the chat input.',
      chromeFeat3: '<strong>Facebook Messenger & Telegram Web Support:</strong> reactive DOM mutation adapters for seamless chat syncing without page reloads.',
      chromeFeat4: '<strong>Multi-LLM & Voice STT Engine:</strong> connect Gemini 3.7/3.5, GLM-4.5/5, GPT-4o, Grok, local Ollama/vLLM, plus instant voice dictation via Deepgram / Whisper.',
      chromeFeat5: '<strong>100% Zero-Cloud Privacy:</strong> API keys, dossiers, and chat histories stay strictly inside your browser storage (IndexedDB / chrome.storage) without telemetry.',
      chromeBtnDownload: 'Open Repository on GitHub →',
      chromeLicenseNote: 'Manifest V3 • MIT License • 100% Free & Open Source',
      roadmapPill: 'ECOSYSTEM ROADMAP',
      roadmapTitle: 'Development Roadmap',
      roadmapSub: 'From a local interview co-pilot on macOS to a global cross-platform suite for conscious communication.',
      q4Period: 'Q4 2026 • COMPLETED',
      q4Title: 'TellMeMore macOS — Universal Live Co-Pilot',
      q4Desc: 'Deepgram streaming (<300 ms), Gemini 3.8/Claude 3.5, on-screen solver (⌥2), screen recording stealth for Zoom/Meet, context auto-compression.',
      q4ChromePeriod: 'Q4 2026 • COMPLETED',
      q4ChromeTitle: 'TellMeMore Copilot — Chrome Extension for Facebook & Telegram',
      q4ChromeDesc: 'Manifest V3 extension for web messaging: native SidePanel, psychological manipulation radar, real-time tactics detection in Facebook Messenger and Telegram Web, 1-click reply injection.',
      q1Period: 'Q1 2027 • IN DEVELOPMENT',
      q1Title: 'TellMeMore TG — Multiplatform Telegram Client with AI Profiling',
      q1Desc: 'TDLib-based Telegram client for Android, Windows, Linux, and macOS. Deep participant profiling, Sherlock manipulation radar, and tactical dialogue prompts.',
      q2Period: 'Q2 2027 • PLANNED',
      q2Title: 'TellMeMore Desktop for Windows & Linux',
      q2Desc: 'Expanding the universal voice co-pilot and on-screen visual solver from macOS to Windows and Linux (WASAPI / PipeWire).',
      footerTagline: 'Engineered to eliminate noise and always achieve your target.',
      footerRepo: 'TellMeMore (macOS)',
      footerRepoTG: 'TellMeMore TG',
      footerRepoChrome: 'TellMeMore Chrome',
      footerProfile: 'Developer Profile',
      tmmTab1: 'Live HUD',
      tmmTab1Desc: 'Ultra-low latency floating HUD with first-person interview prompts and dual-stream transcription',
      tmmTab2: 'Profile',
      tmmTab2Desc: 'Candidate resume context, target company intel, and strategic evaluation goals',
      tmmTab3: 'LLM & Memory',
      tmmTab3Desc: 'Multi-LLM engine (Gemini/Claude), sliding dialogue window, and auto-compression',
      tmmTab4: 'Stealth & UI',
      tmmTab4Desc: '100% Zoom/Meet stealth mode, window transparency (0–100%), and global hotkeys ⌥1 / ⌥2',
      tgTab1: 'Messenger',
      tgTab1Desc: 'Full-featured Telegram client with quick AI actions bar (Auto-reply, Copilot chat)',
      tgTab2: 'AI Copilot',
      tgTab2Desc: 'Dedicated contact AI assistant workspace, manipulation radar, and tactical prompts',
      tgTab3: 'Sherlock',
      tgTab3Desc: 'Deep psychological breakdown, ego trap detection, and strategic negotiation tactics',
      tgTab4: 'CRM Dossier',
      tgTab4Desc: 'Contact psychotype map, Tone of Voice selector, goals, and agreed terms registry',
      chromeTab1: 'Facebook Messenger',
      chromeTab1Desc: 'Copilot SidePanel in Facebook Messenger: manipulation radar, risk score analysis, and strategic 1-click reply injection',
      chromeTab2: 'Telegram Web',
      chromeTab2Desc: 'Telegram Web integration (A & K clients): real-time interlocutor message breakdown and multi-angle reply generation',
      chromeTab3: 'Models & Voice',
      chromeTab3Desc: 'Flexible LLM providers (Google Gemini, Z-AI, OpenAI, xAI, Local Ollama) and voice transcription settings (Deepgram, Groq)',
      zoomHint: 'Click to expand'
    }
  };

  // ==================== STATE MANAGEMENT ====================
  const LANG_STORAGE_KEY = 'tellmemore_lang';
  const THEME_STORAGE_KEY = 'tellmemore_theme';
  const htmlEl = document.documentElement;

  let currentLang = 'ru';

  function detectLanguage() {
    const saved = localStorage.getItem(LANG_STORAGE_KEY);
    if (saved === 'ru' || saved === 'en') {
      return saved;
    }
    const browserLang = (navigator.language || navigator.userLanguage || '').toLowerCase();
    return browserLang.startsWith('ru') || browserLang.startsWith('be') || browserLang.startsWith('uk') ? 'ru' : 'en';
  }

  function setLanguage(lang) {
    if (!translations[lang]) return;
    currentLang = lang;
    localStorage.setItem(LANG_STORAGE_KEY, lang);
    htmlEl.setAttribute('lang', lang);

    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (translations[lang][key]) {
        el.innerHTML = translations[lang][key];
      }
    });

    document.querySelectorAll('.lang-btn').forEach(btn => {
      if (btn.getAttribute('data-lang') === lang) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  }

  // ==================== THEME MANAGEMENT ====================
  function detectTheme() {
    const saved = localStorage.getItem(THEME_STORAGE_KEY);
    if (saved === 'dark' || saved === 'light') {
      return saved;
    }
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  }

  function setTheme(theme) {
    htmlEl.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_STORAGE_KEY, theme);

    const heroFacesImg = document.getElementById('hero-faces-img');
    if (heroFacesImg) {
      heroFacesImg.src = theme === 'light' ? 'assets/hero-faces-light.jpg' : 'assets/hero-faces.jpg';
    }

    const themeIcon = document.getElementById('theme-icon');
    if (themeIcon) {
      if (theme === 'dark') {
        themeIcon.innerHTML = `
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>
        `;
      } else {
        themeIcon.innerHTML = `
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5"></circle>
            <line x1="12" y1="1" x2="12" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="23"></line>
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
            <line x1="1" y1="12" x2="3" y2="12"></line>
            <line x1="21" y1="12" x2="23" y2="12"></line>
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
          </svg>
        `;
      }
    }
  }

  // ==================== INTERACTIVE INSPECTOR TABS ====================
  function initInspectorTabs() {
    const tabBtns = document.querySelectorAll('.inspector-tab-btn');
    const chatView = document.getElementById('chat-inspector-view');
    const voiceView = document.getElementById('voice-inspector-view');

    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const mode = btn.getAttribute('data-tab');
        if (mode === 'chat') {
          if (chatView) {
            chatView.classList.remove('hidden');
            chatView.style.display = 'block';
          }
          if (voiceView) {
            voiceView.classList.remove('active');
            voiceView.style.display = 'none';
          }
        } else {
          if (chatView) {
            chatView.classList.add('hidden');
            chatView.style.display = 'none';
          }
          if (voiceView) {
            voiceView.classList.add('active');
            voiceView.style.display = 'block';
          }
        }
      });
    });
  }

  // ==================== PRODUCT SCREENSHOT GALLERIES ====================
  function initProductGalleries() {
    const tabBtns = document.querySelectorAll('.gallery-tab-btn');

    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const galleryName = btn.getAttribute('data-gallery');
        const targetImgSrc = btn.getAttribute('data-img');
        const descKey = btn.getAttribute('data-desc-key');

        // Deactivate siblings in this gallery
        document.querySelectorAll(`.gallery-tab-btn[data-gallery="${galleryName}"]`).forEach(b => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');

        // Target image & container
        const imgEl = document.getElementById(`${galleryName}-gallery-img`);
        const descEl = document.getElementById(`${galleryName}-gallery-desc`);
        const viewportEl = document.getElementById(`${galleryName}-viewport`);

        if (imgEl && targetImgSrc) {
          imgEl.style.opacity = '0.25';
          setTimeout(() => {
            imgEl.src = targetImgSrc;
            imgEl.style.opacity = '1';
          }, 140);
        }

        if (viewportEl && targetImgSrc) {
          viewportEl.setAttribute('data-lightbox-src', targetImgSrc);
        }

        if (descEl && descKey) {
          descEl.setAttribute('data-i18n', descKey);
          if (translations[currentLang] && translations[currentLang][descKey]) {
            descEl.textContent = translations[currentLang][descKey];
          }
        }
      });
    });
  }

  // ==================== LIGHTBOX MODAL ====================
  function initLightbox() {
    const lightbox = document.getElementById('image-lightbox');
    const lightboxImg = document.getElementById('lightbox-img');
    const lightboxCaption = document.getElementById('lightbox-caption');
    const closeBtn = document.getElementById('lightbox-close');

    if (!lightbox || !lightboxImg) return;

    function openLightbox(src, caption) {
      lightboxImg.src = src;
      if (lightboxCaption) {
        lightboxCaption.textContent = caption || '';
      }
      lightbox.classList.add('active');
      lightbox.setAttribute('aria-hidden', 'false');
      document.body.style.overflow = 'hidden';
    }

    function closeLightbox() {
      lightbox.classList.remove('active');
      lightbox.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
      setTimeout(() => {
        lightboxImg.src = '';
      }, 250);
    }

    document.querySelectorAll('.gallery-viewport').forEach(vp => {
      vp.addEventListener('click', () => {
        const src = vp.getAttribute('data-lightbox-src');
        const gallery = vp.id ? vp.id.replace('-viewport', '') : 'tmm';
        const descEl = document.getElementById(`${gallery}-gallery-desc`);
        const caption = descEl ? descEl.textContent.trim() : '';
        if (src) {
          openLightbox(src, caption);
        }
      });
    });

    if (closeBtn) {
      closeBtn.addEventListener('click', closeLightbox);
    }

    lightbox.addEventListener('click', (e) => {
      if (e.target === lightbox) {
        closeLightbox();
      }
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && lightbox.classList.contains('active')) {
        closeLightbox();
      }
    });
  }

  // ==================== INITIALIZATION ====================
  document.addEventListener('DOMContentLoaded', () => {
    // 1. Language Setup
    const initialLang = detectLanguage();
    setLanguage(initialLang);

    document.querySelectorAll('.lang-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const targetLang = btn.getAttribute('data-lang');
        setLanguage(targetLang);
      });
    });

    // 2. Theme Setup
    const initialTheme = detectTheme();
    setTheme(initialTheme);

    const themeToggleBtn = document.getElementById('theme-toggle');
    if (themeToggleBtn) {
      themeToggleBtn.addEventListener('click', () => {
        const current = htmlEl.getAttribute('data-theme') || 'dark';
        const next = current === 'dark' ? 'light' : 'dark';
        setTheme(next);
      });
    }

    // 3. Tab Switchers
    initInspectorTabs();
    initProductGalleries();
    initLightbox();

    // 4. Smooth Anchor Scrolling
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        const id = this.getAttribute('href');
        if (id === '#') return;
        const target = document.querySelector(id);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });
    });
  });
})();
