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
      btnDemo: '▶ В чём суть?',
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
      tmmBadgeStatus: 'v1.0 Релиз • Готово к загрузке',
      tmmTitle: 'TellMeMore',
      tmmDesc: 'Персональный ИИ-суфлёр реального времени для онлайн-собеседований и переговоров по видео- и аудиосвязи на macOS. Невидимое плавающее окно подсказывает точные формулировки прямо во время речи собеседника.',
      tmmFeat1: '<strong>Сверхбыстрый слух (<300 мс):</strong> потоковая транскрибация вашего микрофона и звука собеседника через Deepgram Nova-2 / Flux.',
      tmmFeat2: '<strong>Суфлёр от первого лица:</strong> подсказки голосом кандидата с учётом вашего опыта, резюме и целей встречи.',
      tmmFeat3: '<strong>Умная автокомпрессия диалога:</strong> сжимает часовую беседу по объёму символов в плотную память, предотвращая переполнение контекста.',
      tmmFeat4: '<strong>Решение задач с экрана (⌥2):</strong> делает мгновенный снимок IDE/терминала и выдаёт готовый код с объяснением.',
      tmmFeat5: '<strong>100% невидимость:</strong> полностью скрыто от демонстрации экрана и записи в Zoom, Google Meet и Teams.',
      tmmBtnDownload: 'Скачать на GitHub →',
      tmmLicenseNote: 'Лицензия MIT • Полностью бесплатно',
      tgBadgeStatus: 'В активной разработке • Скоро',
      tgPlatformsBadge: 'Android • Win • Linux • macOS',
      tgTitle: 'TellMeMore TG',
      tgDesc: 'Полноценный кроссплатформенный клиент Telegram со встроенным ИИ-мозгом для глубокого анализа переписок, профайлинга участников, детекции скрытых манипуляций и формирования тактических рекомендаций.',
      tgFeat1: '<strong>Психологический профайлинг:</strong> сканирует историю чатов, составляет карту психотипа, слабых мест и манеры общения собеседника.',
      tgFeat2: '<strong>Радар манипуляций:</strong> мгновенно подсвечивает попытки давления, пассивной агрессии, газлайтинга или увода от темы.',
      tgFeat3: '<strong>Тактический генератор фраз:</strong> предлагает 2–3 варианта ответа — от дипломатичного выхода до решительного перехвата контроля.',
      tgFeat4: '<strong>Кроссплатформенная база:</strong> работает на смартфонах Android и десктопах Linux, Windows, macOS.',
      tgBtnFollow: 'Следить за разработкой на GitHub →',
      fbBadgeStatus: 'В планах • Roadmap',
      fbTitle: 'TellMeMore FB',
      fbDesc: 'Специализированный ИИ-помощник для коммерческих и деловых переписок в Facebook и Messenger. Ориентирован на продажи, удержание клиентов, холодные переговоры и заключение соглашений без уступок в позициях.',
      fbFeat1: '<strong>Фокус на сделку:</strong> ведение собеседника по стадиям переговоров без навязчивости.',
      fbFeat2: '<strong>Отработка возражений:</strong> моментальный подбор аргументов на «дорого», «подумаем», «не сейчас».',
      fbFeat3: '<strong>Кроссплатформенность:</strong> единая кодовая база на Android, Windows, Linux, macOS.',
      fbNote: 'Старт разработки запланирован после релиза TG-версии',
      roadmapPill: 'ПЛАН РАЗВИТИЯ',
      roadmapTitle: 'Дорожная карта экосистемы',
      roadmapSub: 'От локального суфлёра собеседований на macOS до глобальной мультиязычной платформы осознанной коммуникации.',
      q4Period: 'Q4 2026 • ЗАВЕРШЕНО',
      q4Title: 'TellMeMore macOS — Живой суфлёр для собеседований',
      q4Desc: 'Потоковое распознавание Deepgram (<300 мс), Gemini 3.8/Claude 3.5, режим невидимости от захвата экрана в Zoom/Meet, горячие клавиши ⌥1 / ⌥2, автокомпрессия контекста по объёму символов.',
      q1Period: 'Q1 2027 • В РАЗРАБОТКЕ',
      q1Title: 'TellMeMore TG — Клон Telegram с ИИ-профайлингом',
      q1Desc: 'Полноценный клиент Telegram на Android, Windows, Linux и macOS. Разбор психологического типа собеседников, радар манипуляций и подсказки стратегии ведения дискуссий в чатах.',
      q2Period: 'Q2 2027 • ЗАПЛАНИРОВАНО',
      q2Title: 'TellMeMore Desktop для Windows и Linux',
      q2Desc: 'Перенос голосового суфлёра реального времени с macOS на Windows и Linux (захват системного звука через WASAPI и PulseAudio/PipeWire).',
      q3Period: 'Q3 2027 • ЗАПЛАНИРОВАНО',
      q3Title: 'TellMeMore FB — Ассистент деловых переписок',
      q3Desc: 'Интеграция ИИ-помощника для закрытия сделок, клиентских переговоров и холодных продаж в Facebook Messenger на смартфонах и ПК.',
      footerTagline: 'Создано для того, чтобы убрать шум и всегда добиваться поставленных целей.',
      footerRepo: 'GitHub Репозиторий',
      footerProfile: 'Профиль разработчика'
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
      btnDemo: '▶ Core Philosophy',
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
      tmmBadgeStatus: 'v1.0 Release • Ready to Download',
      tmmTitle: 'TellMeMore',
      tmmDesc: 'Personal real-time AI co-pilot for online job interviews and high-stakes negotiations via voice and video on macOS. An invisible floating HUD whispers exact, winning answers while the other person is speaking.',
      tmmFeat1: '<strong>Ultra-low latency (<300 ms):</strong> live streaming transcription of your mic and interviewer voice via Deepgram Nova-2 / Flux.',
      tmmFeat2: '<strong>First-person whisperer:</strong> crafts confident answers in your voice based on your resume, experience, and interview goals.',
      tmmFeat3: '<strong>Smart text volume auto-compression:</strong> condenses hours of dialogue into dense structured memory, preventing context overflow.',
      tmmFeat4: '<strong>On-screen code solver (⌥2):</strong> captures your IDE or terminal window and produces working solutions with concise rationale.',
      tmmFeat5: '<strong>100% invisible:</strong> excluded from screen recording and sharing in Zoom, Google Meet, and Microsoft Teams.',
      tmmBtnDownload: 'Download on GitHub →',
      tmmLicenseNote: 'MIT License • 100% Free & Open Source',
      tgBadgeStatus: 'In Active Development • Coming Soon',
      tgPlatformsBadge: 'Android • Win • Linux • macOS',
      tgTitle: 'TellMeMore TG',
      tgDesc: 'A full-featured cross-platform Telegram client with built-in AI profiling, manipulation detection, and real-time tactical suggestions for chat negotiation.',
      tgFeat1: '<strong>Psychological profiling:</strong> analyzes chat history to chart the temperament, vulnerabilities, and communication style of any user.',
      tgFeat2: '<strong>Manipulation radar:</strong> flags gaslighting, passive aggression, guilt-tripping, and deflection in real time.',
      tgFeat3: '<strong>Tactical reply generator:</strong> offers calibrated replies — from graceful de-escalation to decisive dominance.',
      tgFeat4: '<strong>Multi-platform codebase:</strong> built for Android smartphones and desktop Linux, Windows, and macOS.',
      tgBtnFollow: 'Follow Development on GitHub →',
      fbBadgeStatus: 'Planned • Roadmap',
      fbTitle: 'TellMeMore FB',
      fbDesc: 'Specialized AI assistant for business messaging and commercial negotiation in Facebook & Messenger. Tuned for social selling, client retention, and closing deals without conceding ground.',
      fbFeat1: '<strong>Deal focus:</strong> guides prospects through negotiation stages without appearing pushy.',
      fbFeat2: '<strong>Objection handling:</strong> instant counter-arguments against “too expensive”, “we need to think”, “not now”.',
      fbFeat3: '<strong>Cross-platform:</strong> unified experience across Android, Windows, Linux, and macOS.',
      fbNote: 'Development begins following the TellMeMore TG release',
      roadmapPill: 'ECOSYSTEM ROADMAP',
      roadmapTitle: 'Development Roadmap',
      roadmapSub: 'From a local interview co-pilot on macOS to a global cross-platform suite for conscious communication.',
      q4Period: 'Q4 2026 • COMPLETED',
      q4Title: 'TellMeMore macOS — Live Voice Co-Pilot for Interviews',
      q4Desc: 'Deepgram streaming (<300 ms), Gemini 3.8/Claude 3.5, screen recording stealth mode for Zoom/Meet, global hotkeys ⌥1 / ⌥2, text volume context compression.',
      q1Period: 'Q1 2027 • IN DEVELOPMENT',
      q1Title: 'TellMeMore TG — Telegram Client with AI Profiling',
      q1Desc: 'Multiplatform Telegram client for Android, Windows, Linux, and macOS. Participant profiling, manipulation radar, and tactical dialogue prompts.',
      q2Period: 'Q2 2027 • PLANNED',
      q2Title: 'TellMeMore Desktop for Windows & Linux',
      q2Desc: 'Expanding the real-time voice co-pilot from macOS to Windows and Linux (system audio capture via WASAPI and PulseAudio/PipeWire).',
      q3Period: 'Q3 2027 • PLANNED',
      q3Title: 'TellMeMore FB — Business Messenger Assistant',
      q3Desc: 'AI deal-closer and sales negotiation advisor integrated into Facebook Messenger across mobile and desktop.',
      footerTagline: 'Engineered to eliminate noise and always achieve your target.',
      footerRepo: 'GitHub Repository',
      footerProfile: 'Developer Profile'
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

    // 3. Tab Switcher
    initInspectorTabs();

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
