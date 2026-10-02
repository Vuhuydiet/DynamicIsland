# Dynamic Island for macOS

A native, high-performance macOS Dynamic Island built in Swift and SwiftUI. It seamlessly wraps around the MacBook Pro / MacBook Air hardware display notch—or floats as an iPhone-style interactive capsule on non-notched external displays—transforming the screen top into an interactive hub.

---

## ✨ Features

### 🏝️ Adaptive Notch & Liquid Glass Design
- **Physical Notch Detection:** Automatically measures hardware notch dimensions and safe area insets on 14" & 16" MacBook Pros and MacBook Airs.
- **Liquid Glass Materials:** Layered translucent frosted glass (`NSVisualEffectView` HUD material) with specular top highlights, subtle gradient sheen, and continuous curve clipping.
- **Flush Edge Geometry:** In notch mode, the top corner radius is set to 0 (`UnevenRoundedRectangle`) to seal flush against the screen bezel with zero gaps.
- **Dynamic Compact Ears:** Compact mode displays live indicators on either side of the notch (now-playing animations, live ticking timer, or battery/drop counters).
- **Floating Pill Mode:** Switchable via Preferences for external monitors, studio displays, and non-notched Macs.
- **Full-Width Tab Bar:** 560pt expanded header with equally distributed tab pills across **Media**, **Drop Shelf**, **Timer**, **Clipboard**, and **Notes**.

---

### 🎨 Configurable UI/UX Versions (Closed & Opened)
- **Independent Customization:** Select preferred UI options independently for the **Closed Notch UI** and the **Opened Island UI** in Preferences (`⌘,` → **General**).
- **Layout Shell Scope Rule:** Opened Island UI options govern how the island is structurally organized (header arrangement, notch spacing, tab bar positioning, and animation transitions). Individual tab contents (`MediaView`, `DropShelfView`, `TimerView`, `ClipboardView`, `NotesView`) remain consistent, full-featured, and universal across all layout styles via `IslandTabContentView`.
- **Interactive Visual Previews:** Live preview cards in Preferences showcase each option with interactive state toggles and scaled graphical representations.

---

### 🎵 Universal Media & Video Player Hub
- **Universal NowPlaying Detection:** Uses Apple's private `MediaRemote.framework` (`MRMediaRemoteGetNowPlayingInfo`) to inspect media playback across all system apps.
- **Multi-Source Support:**
  - 🎬 **Browsers & Web Video:** YouTube, Netflix, Twitch, Vimeo across Google Chrome, Safari, Brave, Arc, and Edge.
  - 📺 **Local Players:** QuickTime Player, VLC Media Player, and IINA.
  - 🎧 **Music Apps:** Apple Music, Spotify, Podcasts, and Tidal.
- **Real-Time Playback Controls:** Fully functional Previous Track (`<<`), Play/Pause (`||` / `▶`), and Next Track (`>>`) powered by native `MRMediaRemoteSendCommand` with AppleScript and system key fallbacks.
- **Interactive Scrubber:** Drag smoothly to seek position on supported media.
- **Dynamic Accent Theming & Artwork:** Dynamic artwork previews and source-specific brand colors.
- **Equalizer Spectrum:** Bouncing multi-bar audio visualizer that syncs to playback state.

---

### 📂 File Drop Shelf (Drag-to-Notch)
- **Auto-Expand on Drag Hover:** Dragging files, images, or links to the notch automatically reveals the island and opens the Drop Shelf tab with a glowing blue border.
- **File Stashing:** Temporarily park working assets, images, and documents right at the screen top.
- **Drag-Out Support:** Drag parked files out directly into Finder, Terminal, Slack, Mail, Messages, or browsers.
- **Quick File Operations:** Right-click or click to reveal in Finder, copy file path, or remove.

---

### ⚡ Condensed System HUD
The header ear hosts a real-time system telemetry readout:
1. ⚙️ **CPU:** Instantaneous usage percentage with load-adaptive coloring.
2. 💾 **RAM:** Used memory in gigabytes (e.g. `14.2G`).
3. 💽 **Disk:** Root volume used space (e.g. `245G`).
4. 🔋 **Battery:** Real-time percentage with live charging bolt (`⚡ 98%`).

---

### ⏱️ Timers & Centered Stopwatch
- **Custom Time Input:** Intuitive H / M / S steppers with up/down arrows to set custom countdown durations.
- **Quick Presets:** Instant access to 1m, 5m, 15m, and 🍅 25m Pomodoro intervals.
- **Live Activity Ear:** Countdown ticks live in the compact notch ear (`⏳ 04:32`) even when collapsed.
- **Centered Stopwatch:** Centered millisecond stopwatch with lap recording and scrollable lap history.
- **Audio Alerts & Notifications:** Tactile sound effects and UserNotifications on completion.

---

### 📋 Clipboard History & 📝 Quick Notes
- **Clipboard History:** Automatically captures copied text and links with instant 1-click re-copying.
- **Scratchpad Editor:** Persistent notes scratchpad with automatic saving and 1-click clipboard export.

---

### ⚙️ Preferences & Shortcuts
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
open DynamicIsland.app
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
    │   │   ├── CondensedSystemHUDView.swift # Inline CPU/RAM/Disk/Battery HUD
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
