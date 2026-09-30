# Dynamic Island for MacBook (macOS)

An ultra-sleek, native macOS Dynamic Island application built in Swift and SwiftUI. It seamlessly wraps around the MacBook Pro / MacBook Air display notch—or floats gracefully as an iPhone-style capsule on external monitors—transforming the screen notch into a powerful interactive command center.

---

## ✨ Features

### 🏝️ Adaptive Notch & Island Geometry
- **Physical Notch Detection:** Automatically detects MacBook Pro (14" / 16") and MacBook Air hardware notches using macOS safe area insets and auxiliary display boundaries.
- **Dynamic Ear Badges:** In compact mode, the left and right "ears" next to the notch display live indicators (live countdown timer, animated equalizer bars, battery %, or drop shelf item counts).
- **Floating Pill Mode:** Switchable to a floating capsule mode for external monitors, iMacs, or non-notched displays.
- **Apple-grade Fluid Physics:** Smooth spring animations (`.spring(response: 0.36, dampingFraction: 0.78)`) that fluidly expand and collapse.

---

### 🎵 Universal Media & Video Player Hub
- **Universal Source Support:** Automatically listens to **every video and audio source** playing on your Mac:
  - 🎬 **Web Streaming & Browsers:** **YouTube**, **Netflix**, **Twitch**, and **Vimeo** across Google Chrome, Safari, Brave, Arc, and Edge.
  - 📺 **Local Video Players:** **QuickTime Player**, **VLC Media Player**, and **IINA**.
  - 🎧 **Music Apps:** **Apple Music**, **Spotify**, Tidal, and Podcasts.
  - 🔊 **System-wide NowPlaying:** Native bridge to macOS `MediaRemote.framework` for universal OS audio/video session tracking.
- **Dynamic Brand Colors & Badges:** Branded gradients, icons, and real video/album artwork (YouTube red `play.rectangle`, QuickTime cyan `film`, VLC orange `cone`, Spotify green waves, Apple Music pink notes).
- **Interactive Scrubber:** Drag to seek through playback position.
- **Universal Playback Controls:** Previous track, Play/Pause, Next track, and quick jump to the active source app or browser.
- **Audio Equalizer Visualizer:** 7-bar audio frequency spectrum tinted with the active media source's brand color.
- **Demo Mode:** Built-in demo player with sample tracks to preview animations anytime.

---

### 📂 Quick Drop Shelf (File Stash)
- **Drag-to-Notch:** Drag any file, image, or link directly to the notch to immediately expand the Drop Shelf.
- **Temporary Parking:** Stash files, code snippets, or assets at the top of your screen.
- **Drag-Out Support:** Drag files out of the shelf into Slack, Mail, Messages, Terminal, Finder, or browser windows.
- **Quick File Actions:** Right-click or hover to copy path, reveal in Finder, or remove items.

---

### ⚡ Permanent Condensed System HUD (Top Section)
The expanded island features a **two-part split architecture**:
- **Part 1 (Top Section):** Always-visible condensed 4-pill system telemetry strip:
  - ⚙️ **CPU:** Real-time percentage load with colored load gauge (cyan / orange / red).
  - 💾 **Memory (RAM):** Used memory in gigabytes (e.g. `14.2 GB`) with memory ring.
  - 🔋 **Battery:** Percentage with live charging status (`⚡ 98%`).
  - 💽 **Disk:** Root volume storage usage (e.g. `262 GB`) with usage ring.
- **Part 2 (Bottom Section):** Fast tab bar switching between your working modules: **Media**, **Drop Shelf**, **Timer**, **Clipboard**, and **Notes**.

---

### ⏱️ Timers & Stopwatch (Live Activity)
- **Countdown Timer:** Presets for 1m, 5m, 15m, and 25m Pomodoro sessions with circular progress ring.
- **Live Activity Notch Ear:** Live ticking countdown (`⏳ 04:32`) remains visible in the notch ear even when the island is collapsed!
- **Alert Sounds & Notifications:** Gentle audio bell and notification when the timer finishes.
- **Precision Stopwatch:** Hundredth-of-a-second stopwatch with lap time tracking.

---

### 📋 Clipboard History
- **Recent Snippets:** Automatically monitors copied text, links, and code snippets.
- **Search:** Instant search filter across clipboard items.
- **1-Click Copy:** Click any snippet to copy it back to the clipboard with visual checkmark feedback.

---

### 📝 Quick Scratchpad
- **Instant Notes:** Fast, minimalist scratchpad right at the top of your screen.
- **Auto-Saving:** Notes are automatically persisted.
- **Copy All / Clear:** 1-click export of your quick notes.

---

### ⚙️ Preferences & Customization
- **Launch at Login (Start with macOS):** Option to automatically start Dynamic Island whenever your Mac turns on or you log in (managed via Apple's modern `SMAppService` and macOS Login Items).
- **Island Mode:** Auto Detect, Notch Attached, or Floating Pill.
- **Expansion Trigger:** Hover & Click or Click Only (with customizable hover delay).
- **Dedicated Settings Window:** Standalone native window with categorized tabs (General, Sound Effects, Geometry & Notch, Shortcuts, About) with fine-tuning offsets and hardware detection.
- **Rich Sound Settings:** Volume slider (0-100%), sound schemes (*macOS Classic*, *Modern Clicks*, *Subtle/Soft*), per-event audio toggles (expand, collapse, tab switch, drop, timer alert), and test audition buttons.
- **Menu Bar Extra:** Sleek menu bar item for toggling the island, switching tabs, toggling Launch at Login, and opening Preferences.

---

## ⌨️ Shortcuts & Gestures

| Action | Gesture / Shortcut |
| :--- | :--- |
| **Expand Island** | Hover mouse over the notch or click the pill |
| **Global Toggle** | `⌥ + ⌘ + I` (Option + Command + I) |
| **Open Settings Window** | Click the ⚙️ gear icon in the island header or `⌘,` |
| **Collapse Island** | Move mouse away, press `Esc`, or click the `^` button |
| **Pin Island Open** | Click the 📌 pin button in the top-right corner |
| **Drop Files** | Drag any file over the notch to open the Drop Shelf |
| **Menu Bar Access** | Click the capsule icon in the macOS menu bar |

---

## 🛠️ Building & Running

### Prerequisites
- macOS 13.0 or later (Tested on macOS Sequoia 15 / 26)
- Apple Silicon (M1, M2, M3, M4) or Intel Mac
- Command Line Tools (`xcode-select --install`)

### Build
Run the automated build script:
```bash
./scripts/build_app.sh
```
This compiles all Swift sources with optimizations and creates `DynamicIsland.app`.

### Launch
```bash
open DynamicIsland.app
```

### Install to Applications (Optional)
```bash
cp -R DynamicIsland.app /Applications/
```

---

## 📂 Project Structure

```
dynamic-island/
├── DynamicIsland.app/              # Compiled macOS Application Bundle
├── Package.swift                   # Swift Package manifest
├── scripts/
│   ├── build_app.sh               # Build and app packaging script
│   ├── generate_icon.swift        # AppIcon generator
│   └── AppIcon.icns               # 1024x1024 macOS App Icon
└── Sources/DynamicIsland/
    ├── App/
    │   ├── DynamicIslandApp.swift  # NSApplicationDelegate & Menu Bar Extra
    │   ├── WindowController.swift  # Non-activating floating NSPanel controller
    │   └── SoundManager.swift      # Tactile audio feedback
    ├── Models/
    │   ├── AppState.swift          # Core state, tabs, hover & pin logic
    │   ├── MediaManager.swift      # Apple Music & Spotify observer & visualizer
    │   ├── DropShelfManager.swift  # Drag & drop file stash model
    │   ├── SystemMonitor.swift     # Live CPU, RAM, Battery & quick actions
    │   ├── TimerManager.swift      # Countdown timer & stopwatch engine
    │   ├── ClipboardManager.swift  # Clipboard history observer
    │   ├── NotesManager.swift      # Auto-saving scratchpad
    │   └── SettingsManager.swift   # UserDefaults preferences
    ├── Utilities/
    │   └── NotchDetector.swift     # Hardware notch geometry & screen detection
    ├── Views/
    │   ├── IslandContainerView.swift    # Morphing capsule & spring animations
    │   ├── Compact/
    │   │   ├── CompactIslandView.swift  # Compact notch ears view
    │   │   └── EqualizerVisualizerView.swift # Bouncing waveform spectrum
    │   ├── Expanded/
    │   │   ├── ExpandedIslandView.swift # Tab bar & card container
    │   │   ├── MediaView.swift          # Music player UI & seek bar
    │   │   ├── DropShelfView.swift      # Drop shelf & file preview cards
    │   │   ├── SystemHUDView.swift      # Resource gauges & quick toggles
    │   │   ├── TimerView.swift          # Circular dial timer & stopwatch
    │   │   ├── ClipboardView.swift      # History list & search
    │   │   ├── NotesView.swift          # Scratchpad editor
    │   │   └── SettingsView.swift       # Preferences controls
    │   └── Components/
    │       ├── CustomSliders.swift      # Native volume slider
    │       └── PillBadge.swift          # Mini capsule badges
    └── main.swift                  # Application entry point
```

---

## 📄 License
MIT License. Free and open for personal and commercial customization.
