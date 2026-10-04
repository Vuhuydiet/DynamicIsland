# Dynamic Island for macOS

A native, high-performance macOS Dynamic Island built in Swift and SwiftUI. It seamlessly wraps around the MacBook Pro / MacBook Air hardware display notch—or floats as an iPhone-style interactive capsule on non-notched external displays—transforming the screen top into an interactive hub.

---

## 📑 Table of Contents
1. [✨ Features & Subsystems](#-features--subsystems)
   - [Adaptive Notch & Liquid Glass Design](#-adaptive-notch--liquid-glass-design)
   - [Configurable UI/UX Versions](#-configurable-uiux-versions)
   - [Universal Media & Video Player Hub](#-universal-media--video-player-hub)
   - [File Drop Shelf (Drag-to-Notch)](#-file-drop-shelf-drag-to-notch)
   - [Timers & Centered Stopwatch](#️-timers--centered-stopwatch)
   - [Clipboard History & Quick Notes](#-clipboard-history--quick-notes)
   - [Condensed System HUD](#-condensed-system-hud)
   - [App Plugins & Chat Injection (Facebook Messenger)](#-app-plugins--chat-injection-facebook-messenger)
   - [Preferences & Customization](#️-preferences--customization)
2. [⌨️ Shortcuts & Gestures](#️-shortcuts--gestures)
3. [🛠️ Building & Running](#️-building--running)
4. [📂 Project Structure](#-project-structure)
5. [📄 License](#-license)

---

## ✨ Features & Subsystems

### 🏝️ Adaptive Notch & Liquid Glass Design
- **Physical Notch Detection:** Automatically measures hardware notch dimensions and safe area insets on 14" & 16" MacBook Pros and MacBook Airs.
- **Liquid Glass Materials:** Layered translucent frosted glass (`NSVisualEffectView` HUD material) with specular top highlights, subtle gradient sheen, and continuous curve clipping.
- **Flush Edge Geometry:** In notch mode, top corner radii flaring into the screen bezel are mathematically continuous with zero gaps (`NotchIslandShape`).
- **Dynamic Compact Ears:** Compact mode displays live indicators on either side of the notch (now-playing animations, live ticking timer, or battery/drop counters).
- **Floating Pill Mode:** Switchable via Preferences for external monitors, studio displays, and non-notched Macs.
- **Full-Width Tab Bar:** 560pt expanded header with equally distributed tab pills across **Media**, **Drop Shelf**, **Timer**, **Clipboard**, and **Notes**.

---

### 🎨 Configurable UI/UX Versions
- **Closed Notch Customization:** Choose the compact notch appearance in Preferences (`⌘,` → **General**).
- **Single Opened Island Shell:** The expanded island uses one layout — the full multi-tab workspace with a top header HUD, full-width sliding pill bar, and centered tool content.
- **Universal Tab Content:** Individual tool views (`MediaView`, `DropShelfView`, `TimerView`, `ClipboardView`, `NotesView`) are shared through `IslandTabContentView`, so tool behaviour stays identical regardless of the active tab.
- **Interactive Visual Previews:** Live preview cards in Preferences showcase the closed notch options with interactive state toggles and scaled graphical representations.

---

### 🎵 Universal Media & Video Player Hub
- **Universal NowPlaying Detection:** Dynamically links Apple's private `MediaRemote.framework` (`MRMediaRemoteGetNowPlayingInfo`) to inspect media playback across all system apps.
- **Multi-Source Support:**
  - 🎬 **Browsers & Web Video:** YouTube, Netflix, Twitch, Vimeo across Google Chrome, Safari, Brave, Arc, and Edge.
  - 📺 **Local Players:** QuickTime Player, VLC Media Player, and IINA.
  - 🎧 **Music Apps:** Apple Music, Spotify, Podcasts, and Tidal.
- **Real-Time Playback Controls:** Fully functional Previous Track (`<<`), Play/Pause (`||` / `▶`), and Next Track (`>>`) powered by native `MRMediaRemoteSendCommand` with AppleScript and system key fallbacks.
- **Interactive Scrubber:** Drag smoothly to seek position on supported media.
- **Equalizer Spectrum:** Bouncing multi-bar audio visualizer that syncs to active audio output via CoreAudio.

---

### 📂 File Drop Shelf (Drag-to-Notch)
- **Auto-Expand on Drag Hover:** Dragging files, images, or links to the notch automatically reveals the island and opens the Drop Shelf tab with a glowing blue border.
- **File Stashing:** Temporarily park working assets, images, and documents right at the screen top.
- **Drag-Out Support:** Drag parked files out directly into Finder, Terminal, Slack, Mail, Messages, or browsers.
- **Quick File Operations:** Right-click or click to reveal in Finder, copy file path, or remove.

---

### ⏱️ Timers & Centered Stopwatch
- **Custom Time Input:** Intuitive H / M / S steppers with up/down chevrons to set custom countdown durations.
- **Quick Presets:** Instant access to 1m, 5m, 15m, and 🍅 25m Pomodoro intervals.
- **Live Activity Ear:** Countdown ticks live in the compact notch ear (`⏳ 04:32`) even when collapsed.
- **Centered Stopwatch:** Centered millisecond stopwatch with split lap calculation (`Lap`, `Split`, `Total`), fastest lap green bolt (`⚡`) highlight, and slowest lap red tortoise (`🐢`) highlight.
- **Audio Alerts & Notifications:** Tactile sound effects and UserNotifications on completion.

---

### 📋 Clipboard History & 📝 Quick Notes
- **Clipboard History:** Automatically captures copied text and links with instant 1-click re-copying.
- **Scratchpad Editor:** Persistent notes scratchpad with automatic saving and 1-click clipboard export.

---

### ⚡ Condensed System HUD
The header ear hosts a real-time system telemetry readout updated every 2 seconds:
1. ⚙️ **CPU:** Instantaneous usage percentage with load-adaptive coloring.
2. 💾 **RAM:** Used memory in gigabytes (e.g. `14.2G`).
3. 💽 **Disk:** Root volume used space (e.g. `245G`).

---

### 🧩 App Plugins & Chat Injection (Facebook Messenger)
- **Universal Plugin Protocol (`IslandPlugin`):** Inject any native tool or web application into Dynamic Island with standard components and dynamic viewport sizing.
- **Official Facebook Messenger Integration:** Seamlessly chat from the notch in a comfortable **740 × 400 pt** view with persistent login, desktop Safari User-Agent, and zoom controls.
- **In-Notch Live Notification Banners:** HTML5 Web Notifications and title changes are intercepted and displayed as live balloon pills in the compact notch with tap-to-chat navigation.
- **Authentic App Icon Pipeline:** Bundled 512×512 PNG logos loaded via `PluginIconManager` with automatic fallback to macOS app bundles.
- 📖 **Full Developer Documentation:** Check out [`docs/PLUGINS.md`](docs/PLUGINS.md) for architecture, component library, and the 5-minute guide to adding apps like WhatsApp, Slack, or ChatGPT.

---

### ⚙️ Preferences & Customization
- **Open Preferences:** Click the **Dynamic Island** title in the header ear, press `⌘,`, or select Preferences from the menu bar.
- **Pin Island Open:** Pin button (`📌`) keeps the island expanded regardless of mouse movement.
- **Real-Time Menu Bar Icon:** Toggle the menu bar icon on or off live in Preferences.
- **Launch at Login:** Starts automatically on macOS boot using modern `SMAppService`.

---

## ⌨️ Shortcuts & Gestures

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Expand Island** | Hover cursor over notch or click compact pill |
| **Collapse Island** | Move cursor outside island bounds or press `Esc` |
| **Toggle Expand / Collapse** | `⌥ + ⌘ + I` (Option + Command + I) |
| **Open Preferences** | Click **Dynamic Island** title or press `⌘,` |
| **Pin / Unpin Island** | Click the pin icon in the header |
| **Drop Files** | Drag any file into the notch to open Drop Shelf |

---

## 🛠️ Building & Running

### Requirements
- macOS 13.0 or later (Apple Silicon M-series or Intel)
- Command Line Tools installed (`xcode-select --install`)

### Build
Run the automated build script:
```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh
```

### Launch
```bash
open /Applications/DynamicIsland.app
```

---

## 📂 Project Structure

```
dynamic-island/
├── DynamicIsland.app/              # Compiled macOS Application Bundle
├── Package.swift                   # Swift Package definition
├── scripts/
│   ├── build_app.sh               # Compilation and bundle packager
│   ├── generate_icon.swift        # Icon generator
│   └── AppIcon.icns               # 1024x1024 application icon
└── Sources/DynamicIsland/
    ├── App/
    │   ├── DynamicIslandApp.swift  # NSApplicationDelegate & Menu Bar Extra
    │   ├── WindowController.swift  # NSPanel lifecycle & open-top mouse tracking
    │   ├── SettingsWindowController.swift # Standalone preferences window
    │   └── SoundManager.swift      # Tactile audio feedback
    ├── Models/
    │   ├── AppState.swift          # Core expansion, active tab, hover & pin state
    │   ├── MediaManager.swift      # MediaRemote bridge, AppleScript adapters & controls
    │   ├── DropShelfManager.swift  # Drag & drop file parking model
    │   ├── SystemMonitor.swift     # CPU, RAM, Disk, and Battery monitor
    │   ├── TimerManager.swift      # Countdown timer & stopwatch engine
    │   ├── ClipboardManager.swift  # Pasteboard observer & history
    │   ├── NotesManager.swift      # Persistent scratchpad
    │   └── SettingsManager.swift   # UserDefaults configuration
    ├── Utilities/
    │   ├── NotchDetector.swift     # Screen safe-area & hardware notch detector
    │   └── Typography.swift        # Typography & SF Symbols definitions
    ├── Views/
    │   ├── IslandContainerView.swift # Liquid glass container, clip shapes & gestures
    │   ├── Compact/
    │   │   ├── CompactIslandView.swift # Compact ear router & interaction handler
    │   │   ├── ClassicCompactView.swift # Classic balanced notch ears (Default)
    │   │   └── EqualizerVisualizerView.swift # Animated waveform bars
    │   ├── Expanded/
    │   │   ├── ExpandedIslandView.swift # Layout shell router
    │   │   ├── FullHubExpandedView.swift # Full-featured multi-tab hub (Default)
    │   │   ├── IslandTabContentView.swift # Shared universal tab content host
    │   │   ├── CondensedSystemHUDView.swift # Inline CPU/RAM/Disk HUD
    │   │   ├── MediaView.swift          # Track info, scrubber & media controls
    │   │   ├── DropShelfView.swift      # Parked file grid & actions
    │   │   ├── TimerView.swift          # Custom time steppers & stopwatch
    │   │   ├── ClipboardView.swift      # Clipboard history list
    │   │   ├── NotesView.swift          # Scratchpad editor
    │   │   └── SettingsWindowView.swift # Preferences views & interactive previews
    │   └── Components/
    │       ├── NotchIslandShape.swift   # Tangent continuous flaring corner bezier
    │       ├── IslandAnimations.swift   # Apple-calibrated spring physics curves
    │       ├── CustomSliders.swift      # Sliders and controls
    │       └── PillBadge.swift          # Compact status badges
    └── main.swift                  # Application entry point
```

---

## 📄 License
MIT License. Free and open for personal and commercial use.
