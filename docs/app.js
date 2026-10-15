// ==========================================================================
// TellMeMore Landing Page Scripts
// Theme switcher, smooth scroll, micro-interactions
// ==========================================================================

(function () {
  'use strict';

  // 1. Theme Management (Dark / Light)
  const THEME_STORAGE_KEY = 'tellmemore_theme';
  const htmlEl = document.documentElement;
  const themeToggleBtn = document.getElementById('theme-toggle');
  const themeIcon = document.getElementById('theme-icon');

  function getPreferredTheme() {
    const saved = localStorage.getItem(THEME_STORAGE_KEY);
    if (saved === 'dark' || saved === 'light') {
      return saved;
    }
    // Check OS preference
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches
      ? 'light'
      : 'dark';
  }

  function applyTheme(theme) {
    htmlEl.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_STORAGE_KEY, theme);

    if (themeIcon) {
      if (theme === 'dark') {
        // Moon icon
        themeIcon.innerHTML = `
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>
        `;
        themeToggleBtn.setAttribute('title', 'Включить светлую тему');
      } else {
        // Sun icon
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
        themeToggleBtn.setAttribute('title', 'Включить тёмную тему');
      }
    }
  }

  // Initialize theme immediately
  const initialTheme = getPreferredTheme();
  applyTheme(initialTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const current = htmlEl.getAttribute('data-theme') || 'dark';
      const next = current === 'dark' ? 'light' : 'dark';
      applyTheme(next);
    });
  }

  // Listen to OS theme changes if user hasn't explicitly set preference
  if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem(THEME_STORAGE_KEY)) {
        applyTheme(e.matches ? 'dark' : 'light');
      }
    });
  }

  // 2. Smooth scrolling for internal anchor links
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;
      const targetEl = document.querySelector(targetId);
      if (targetEl) {
        e.preventDefault();
        targetEl.scrollIntoView({
          behavior: 'smooth',
          block: 'start',
        });
      }
    });
  });

  // 3. Interactive mockup micro-effect (HUD simulation)
  const hintTextEl = document.querySelector('.hud-hint-text');
  if (hintTextEl) {
    const hints = [
      '«Да, в моём опыте с высоконагруженными сервисами на Go мы вынесли кэширование в Redis Cluster с LRU, что сократило latency p99 с 450мс до 12мс».',
      '«Для этой задачи оптимально использовать очередь с приоритетом (Min-Heap). Временная сложность O(N log K), пространственная O(K)».',
      '«Хороший вопрос. Прежде чем писать архитектуру, уточните: какой планируется RPS и допустимо ли eventual consistency при репликации?»'
    ];
    let hintIdx = 0;
    setInterval(() => {
      hintIdx = (hintIdx + 1) % hints.length;
      hintTextEl.style.opacity = '0';
      setTimeout(() => {
        hintTextEl.textContent = hints[hintIdx];
        hintTextEl.style.opacity = '1';
      }, 250);
    }, 7000);
    hintTextEl.style.transition = 'opacity 0.25s ease';
  }
})();
