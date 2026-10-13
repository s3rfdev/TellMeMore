#!/usr/bin/env bash
# Tell Memo — установка окружения на macOS.
# Ставит BlackHole (виртуальный аудиокабель для голоса собеседника),
# подтягивает зависимости Flutter и подсказывает оставшиеся шаги.
set -euo pipefail

echo "── Tell Memo setup ─────────────────────────────────────────"

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew не найден. Установите: https://brew.sh — затем повторите скрипт."
  exit 1
fi

# 2. BlackHole (виртуальный аудиодрайвер; установке нужен пароль администратора)
if system_profiler SPAudioDataType 2>/dev/null | grep -qi blackhole; then
  echo "✔ BlackHole уже установлен"
else
  echo "… Устанавливаю BlackHole 2ch (потребуется пароль администратора)"
  if ! brew install --cask blackhole-2ch; then
    echo "⚠ Не удалось установить автоматически. Выполните вручную:"
    echo "   brew install --cask blackhole-2ch"
    echo "   (или: sudo installer -pkg /usr/local/Caskroom/blackhole-2ch/*/BlackHole2ch-*.pkg -target /)"
  fi
fi

# 3. Flutter: в PATH или через fvm
FLUTTER="flutter"
if ! command -v flutter >/dev/null 2>&1; then
  LATEST_FVM="$(ls -d "$HOME"/fvm/versions/*/bin/flutter 2>/dev/null | sort -V | tail -1 || true)"
  if [ -n "${LATEST_FVM}" ]; then
    FLUTTER="${LATEST_FVM}"
    echo "ℹ Flutter не в PATH — использую fvm: ${FLUTTER}"
  else
    echo "❌ Flutter не найден. Установите Flutter 3.29 или fvm (https://fvm.app)."
    exit 1
  fi
fi

# 4. Зависимости
"$FLUTTER" pub get

echo
echo "─────────────────────────────────────────────────────────────"
echo "Осталось вручную (один раз):"
echo " 1. Audio MIDI Setup → «+» → Multi-Output Device →"
echo "    отметьте колонки + BlackHole 2ch (колонки первыми)."
echo " 2. В звонилке (Skype/Zoom/Meet) выберите выводом этот Multi-Output."
echo " 3. В Tell Memo: Настройки → LLM → АУДИО → «Голос собеседника» → BlackHole 2ch."
echo " 4. Вставьте ключи Deepgram и LLM в Настройках (⚙)."
echo
echo "Запуск приложения: ${FLUTTER} run -d macos"
echo "Подробнее — в README.md"
