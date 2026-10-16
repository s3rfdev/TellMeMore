# TellMeMore — Real-Time AI Interview Co-Pilot & Teleprompter

<p align="center">
  <a href="README.md"><b>English</b></a> • <a href="README_RU.md"><b>Русский</b></a>
</p>

<p align="center">
  <img src="assets/screenshots/main.png" alt="TellMeMore Main Window" width="880">
</p>

<p align="center">
  <strong>An undetectable, floating, real-time AI assistant for technical and behavioural interviews on macOS.</strong><br>
  Dual-stream live speech-to-text, zero-latency prompt suggestions, screen-share stealth mode, and multi-LLM support.
</p>

<p align="center">
  <a href="https://github.com/s3rfdev/TellMeMore/releases"><img src="https://img.shields.io/github/v/release/s3rfdev/TellMeMore?color=2FBF71&label=Release" alt="Release"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Flutter-3.29%2B-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/STT-Deepgram%20Nova--3%20%7C%20Flux-green" alt="Deepgram STT">
  <img src="https://img.shields.io/badge/LLMs-Gemini%20%7C%20Claude%20%7C%20OpenAI%20%7C%20GLM-orange" alt="LLMs">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="MIT License"></a>
</p>

---

## Why TellMeMore?

Job interviews are stressful. Even experienced engineers freeze under pressure, forget syntax, or blank on specific system design details. Traditional cheatsheets and second monitors require constant eye movement that is immediately noticeable on camera.

**TellMeMore** acts as your personal, invisible co-pilot:
1. **Listens in real time** to both your microphone and your interviewer's voice via independent audio streams.
2. **Maintains a chronological live transcript** with instant speaker identification ("Me" vs. "Interviewer").
3. **Generates targeted, first-person answers** on demand (`Get answer`), structured around your resume, the interviewer's background, and your target interview goals.
4. **Captures screen code challenges** (`⌥ 2`): snaps code or diagrams from your IDE / browser and provides an immediate solution.
5. **Completely invisible to screen sharing** (`NSWindow.SharingType.none`): even if you share your entire desktop in Zoom, Google Meet, Microsoft Teams, or Slack, TellMeMore remains invisible to participants.

---

## Screenshots

<div align="center">
  <table>
    <tr>
      <td width="50%">
        <img src="assets/screenshots/main.png" alt="Live Dialogue & Teleprompter" /><br />
        <b>1. Live Dialogue & Invisible Teleprompter HUD</b><br />
        <i>Real-time dual-stream transcription, instant first-person answer generation, and active engine status.</i>
      </td>
      <td width="50%">
        <img src="assets/screenshots/1.png" alt="Context & Candidate Profile" /><br />
        <b>2. Tailored Candidate & Interview Context</b><br />
        <i>Custom resume profile, target interviewer notes, and strategic goals/criteria for hint generation.</i>
      </td>
    </tr>
    <tr>
      <td width="50%">
        <img src="assets/screenshots/2.png" alt="LLM & Context Memory Compression" /><br />
        <b>3. Multi-LLM Engine & Context Compression</b><br />
        <i>Google Gemini, Claude, GPT, GLM integration with sliding window and automatic history compression.</i>
      </td>
      <td width="50%">
        <img src="assets/screenshots/3.png" alt="UI & Stealth Customization" /><br />
        <b>4. Stealth & Customization Controls</b><br />
        <i>Hide from screen share, opacity slider (0–100%), global hotkeys (⌥1 / ⌥2), and custom typography.</i>
      </td>
    </tr>
  </table>
</div>

---

## Key Features

- **Dual-Stream Audio Isolation (100% Speaker Accuracy):**
  - Your voice is captured directly from your hardware microphone.
  - The interviewer's voice is routed through [BlackHole](https://existential.audio/blackhole/) (a lightweight, open-source macOS virtual audio driver).
  - Both streams are processed simultaneously via Deepgram Nova-3 WebSocket connections. Zero crosstalk, zero hallucinated speaker labels.
- **Strict Chronological Dialogue Interleaving:**
  - Sentences are timestamped and segmented on natural grammatical boundaries (`.`, `!`, `?`, or length thresholds).
  - Even during rapid back-and-forth dialogue or uninterrupted monologue, turns are rendered in chronological timeline order.
- **Screen Sharing Protection (Stealth Mode):**
  - Integrated macOS native `NSWindow.SharingType.none`.
  - The window is excluded at the window-server level from desktop captures, window shares, and screenshot tools (Zoom, Google Meet, Teams, Slack, OBS).
- **Floating Translucent UI Overlay:**
  - True per-pixel transparency (0–100%) so you can read hints naturally while looking directly at your camera or IDE.
  - Hidden / translucent / solid titlebar modes with custom window dragging areas.
  - Optional `Always on Top` floating window level.
  - Draggable split-ratio handle between hint prompt and transcript.
  - Customizable typography (font size from 6px to 24px, bold toggle, turn spacing, color presets).
- **Multi-LLM Provider Engine:**
  - **Google Gemini** (Gemini 2.5 Flash, 3.8 Flash, Pro, custom models).
  - **Anthropic Claude** (Claude 3.7 Sonnet, Haiku, Opus).
  - **OpenAI** (GPT-4o, GPT-4o-mini, o3-mini).
  - **Z.ai / Zhipu GLM** (GLM-4.7-Flash, GLM-4.5-Flash).
  - Live model testing tool directly inside the settings modal.
- **Configurable Context History:**
  - Adjust dialogue history from 5 to 100 turns via slider.
  - Candidate profile, interviewer notes, and goals are **always attached in full** to every LLM request.
  - Automatic dialogue truncation protects against memory leaks during marathon interview sessions.

---

## Quick Start (Installation)

### Option 1: Download Prebuilt App (Recommended)

1. Download the latest `TellMeMore-macOS.zip` from [Releases](https://github.com/s3rfdev/TellMeMore/releases).
2. Extract the archive and drag `TellMeMore.app` to your `/Applications` folder.
3. Open `TellMeMore.app`. If macOS blocks execution because of Gatekeeper:
   ```bash
   xattr -cr /Applications/TellMeMore.app
   ```

### Option 2: Build from Source

#### Prerequisites
- macOS 13+ (Ventura, Sonoma, Sequoia)
- [Flutter 3.29+](https://flutter.dev) (or via [FVM](https://fvm.app))
- Xcode with Command Line Tools
- [Homebrew](https://brew.sh)

```bash
# 1. Clone the repository
git clone https://github.com/s3rfdev/TellMeMore.git
cd TellMeMore

# 2. Install dependencies
flutter pub get

# 3. Build debug or release bundle
flutter build macos --release

# 4. Launch the application
open build/macos/Build/Products/Release/TellMeMore.app
```

---

## Audio Setup (2-Minute One-Time Configuration)

To capture the interviewer's voice without sending feedback through your microphone, we recommend using **BlackHole 2ch**:

1. **Install BlackHole**:
   ```bash
   brew install --cask blackhole-2ch
   ```
2. **Create a Multi-Output Device**:
   - Open **Audio MIDI Setup** on macOS (press `Cmd + Space` and search for `Audio MIDI Setup`).
   - Click the **`+`** icon in the bottom-left corner and select **Create Multi-Output Device**.
   - Check **your headphones/speakers** AND **BlackHole 2ch**.
   - Keep your headphones at the top of the list as the primary output device (Drift Correction enabled on BlackHole).
3. **Configure Your Call (Zoom / Google Meet / Teams / Browser)**:
   - In your calling app or macOS sound settings, set **Output / Speaker** to the new **Multi-Output Device**.
   - Set **Input / Microphone** to your real hardware microphone.
4. **Configure TellMeMore**:
   - Open TellMeMore **Settings (⚙) -> LLM -> AUDIO**:
     - **Your microphone:** `System default` (or your headset mic).
     - **Interviewer voice:** `BlackHole 2ch`.

Now, when your interviewer speaks, you hear them clearly in your headphones, and TellMeMore captures their audio in real time!

---

## API Keys

TellMeMore requires a speech-to-text API key and an LLM API key:

| Service | Purpose | Free Tier / Cost | Where to Get |
|---|---|---|---|
| **Deepgram** | Real-time dual STT (`nova-3`) | **$200 free credit** on signup | [console.deepgram.com](https://console.deepgram.com) |
| **Google Gemini** | Answer suggestion LLM | Free tier available | [aistudio.google.com](https://aistudio.google.com) |
| **Z.ai (GLM)** | High-speed LLM alternative | Free flash models available | [z.ai](https://z.ai) |
| **OpenAI / Anthropic** | Answer suggestion LLM | Pay-as-you-go | [platform.openai.com](https://platform.openai.com) / [console.anthropic.com](https://console.anthropic.com) |

All credentials are saved locally in `~/.sobes_helper.json` on your machine. No keys or conversation transcripts are ever sent to third-party tracking servers.

---

## 🌐 The TellMeMore Ecosystem

TellMeMore is part of an integrated communication intelligence suite:
- **[TellMeMore macOS](https://github.com/s3rfdev/TellMeMore)**: Invisible real-time HUD and interview prompter with voice & screen capture.
- **[TellMeMore TG](https://github.com/s3rfdev/TellMeMore_TG)**: Cross-platform Telegram client with psychological profiling, Sherlock analysis, and RAG dossier.
- **[TellMeMore Copilot (Chrome Extension)](https://github.com/s3rfdev/tellmemore-chrome)**: Manifest V3 extension for Facebook Messenger & Telegram Web with live manipulation radar and 1-click strategic reply injection.
- **[Official Landing & Documentation](https://s3rfdev.github.io/TellMeMore/)**

---

## Privacy & Security

- **Zero Telemetry**: No analytics, tracking, or remote error reporting.
- **Local Storage**: All profile configurations, API keys, and window layouts are saved strictly to `~/.sobes_helper.json`.
- **Direct Peer Connections**: Audio is streamed directly from your device to Deepgram via secure WebSockets (`wss://`), and LLM queries are sent directly to the official provider endpoints (Google, Anthropic, OpenAI, Zhipu).

---

## Contributing

Contributions, issues, and feature requests are welcome!
Feel free to check [issues page](https://github.com/s3rfdev/TellMeMore/issues) or open a PR.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
