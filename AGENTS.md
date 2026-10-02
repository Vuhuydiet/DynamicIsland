# AGENTS.md — Contributor & AI Agent Guide

This document captures architectural decisions, build instructions, design principles, and critical gotchas for developers and AI agents working on the **Dynamic Island** codebase.

---

## 📑 Table of Contents
1. [🛠️ Build Environment & Toolchain](#1-build-environment--toolchain)
2. [📐 Window & Geometry Architecture](#2-window--geometry-architecture)
3. [🏛️ UI/UX Versioning Architecture & Scope Rules](#3-uiux-versioning-architecture--scope-rules)
4. [🎨 Design System, Styling & Animation](#4-design-system-styling--animation)
5. [🧩 Subsystem Architectures & Critical Gotchas](#5-subsystem-architectures--critical-gotchas)
   - [5.1 Media & NowPlaying Subsystem](#51-media--nowplaying-subsystem)
   - [5.2 Drag-to-Notch Drop Shelf Subsystem](#52-drag-to-notch-drop-shelf-subsystem)
   - [5.3 Timers & Stopwatch Subsystem](#53-timers--stopwatch-subsystem)
   - [5.4 Clipboard & Quick Notes Subsystem](#54-clipboard--quick-notes-subsystem)
   - [5.5 System HUD Telemetry Subsystem](#55-system-hud-telemetry-subsystem)
6. [🔄 State & Singletons Map](#6-state--singletons-map)

---

## 1. 🛠️ Build Environment & Toolchain

### 1.1 Developer Directory Requirement
On systems where Xcode GUI license agreements have not been accepted or differ from Command Line Tools, calling `swiftc`, `xcodebuild`, or build tools directly may prompt an interactive license block.
**Always prefix build commands with `DEVELOPER_DIR`:**
```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh
```

### 1.2 Required Frameworks
When compiling sources directly via `swiftc`, include the following framework flags:
```bash
-framework ServiceManagement \
-framework AppKit \
-framework SwiftUI \
-framework Combine \
-framework IOKit \
-framework AudioToolbox \
-framework UserNotifications
```

### 1.3 Build & Relaunch Workflow
```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh && \
pkill -f DynamicIsland || true && \
sleep 0.4 && \
open /Applications/DynamicIsland.app
```

### 1.4 Automatic Installation to `/Applications/`
Every compilation via `./scripts/build_app.sh` automatically installs the fresh app bundle directly to `/Applications/DynamicIsland.app`:
```bash
rm -rf "/Applications/DynamicIsland.app"
cp -R "build/DynamicIsland.app" "/Applications/DynamicIsland.app"
```
Always run, test, and launch the application from `/Applications/DynamicIsland.app`.

---

## 2. 📐 Window & Geometry Architecture

### 2.1 NSPanel Specification (`WindowController.swift`)
The island window is a `DynamicIslandPanel` (subclass of `NSPanel`) configured with:
- `styleMask`: `[.borderless, .nonactivatingPanel]`
- `level`: `.statusBar`
- `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
- `isOpaque = false`, `backgroundColor = .clear`
- Panel size: `640 × 340` (content origin aligned to screen top: `y = screen.frame.maxY - 340`).

### 2.2 Open-Top Mouse Hit-Testing Gotcha
> [!WARNING]
> **Critical:** `NSRect.contains(mousePoint)` uses half-open intervals (`minY <= y < maxY`). When the cursor touches the screen's top physical pixel edge (`y == screen.frame.maxY`), `NSRect.contains` returns `false`!
- The global mouse movement monitor in `WindowController` **must never apply an upper-bound check on `y`**.
- Only check horizontal bounds and verify that the cursor remains above the panel bottom:
  ```swift
  let inX = mouse.x >= (screen.frame.midX - islandW / 2.0 - margin)
         && mouse.x <= (screen.frame.midX + islandW / 2.0 + margin)
  let inY = mouse.y >= (islandBottom - margin)
  if !(inX && inY) {
      // collapse if not pinned
  }
  ```

### 2.3 Notch Sealing & Island Shape Architecture (`NotchIslandShape.swift`)
- **Compact / Closed State**:
  - Tangent continuous corner geometry:
    - Top corners: concave fillets flaring horizontally into the top screen bezel (`compactFlareWidth = 12pt, compactFlareHeight = 10pt`).
    - Left and right edges: true straight vertical lines (`y = flareHeight ... h - rBottom`).
    - Bottom corners: convex continuous curves (`rBottom = 12pt`).
    - Bottom edge: flat horizontal line enclosing the physical camera notch (`notchWidth = 185pt`).
    - Minimal footprint: In idle, ear width is `44pt` (`compactIslandWidth = 297pt` total) to tightly hug the physical hardware notch while showing a subtle Apple logo on the left and battery percentage on the right. Expands to compact ears when active (`media: 75pt`, `timer: 65pt`, `shelf: 50pt`).
- **Expanded State**:
  - The expanded island panel uses `NotchIslandShape` matching the closed state:
    - Top corners: concave fillets flaring horizontally into the top screen bezel (`flareWidth = 22pt, flareHeight = 18pt`).
    - Left and right edges: true straight vertical lines (`y = flareHeight ... h - rBottom`).
    - Bottom corners: convex continuous curves (`cornerRadius = 32pt`).
    - Bottom edge: flat horizontal line.
    - Outer container clips `NSVisualEffectView`, dark tint, sheen, and specular rim stroke to this unified shape.

---

## 3. 🏛️ UI/UX Versioning Architecture & Scope Rules

The application provides independent customization of the **Closed Notch UI** and the **Opened Island UI** via Preferences (**General → Island UI Versions**).

### 3.1 Opened Island UI Scope Rule
> [!IMPORTANT]
> **Opened Island UI Options Scope**:
> Opened Island UI options define **structural container layout, header/notch organization, tab navigation architecture, and transitions ONLY**:
> 1. **Header organization**: Arrangement and sizing of the hardware notch spacer cutout, title/branding placement, system HUD telemetry styling and order, and pin button position.
> 2. **Tab bar & navigation architecture**: Placement and visual styling of tabs (e.g., top sliding pill bar, bottom dock, segmented controls, floating chips, or side rails) and active indicator glide physics.
> 3. **Shell framing & transitions**: Overall island width, corner radii, dividers, background blur, and expand/collapse spring curves.
>
> **Universal Tab Content Rule (Never Duplicate or Modify Tab Contents Per Style)**:
> Individual tool views (`MediaView`, `DropShelfView`, `TimerView`, `ClipboardView`, `NotesView`) are universal system tools and remain identical across all layout options. Every opened island style MUST embed [`IslandTabContentView.swift`](Sources/DynamicIsland/Views/Expanded/IslandTabContentView.swift) into its designated content viewport. Never duplicate tab content logic or customize tool views per layout shell.

### 3.2 Closed Notch UI Scope Rule
Closed Notch UI options dictate how the compact notch ears display information when idle or during live activities (e.g., standard Apple-style balanced ears, ultra-minimal, or ticker/badge styles). They route through [`CompactIslandView.swift`](Sources/DynamicIsland/Views/Compact/CompactIslandView.swift).

### 3.3 Styles, Enums & Settings Mapping
- **Closed Notch Styles (`ClosedNotchStyle`)**:
  - `defaultStyle` ("Default"): The original Apple-style balanced ears with battery percentage, Apple logo, and dynamic live activities ([`ClassicCompactView.swift`](Sources/DynamicIsland/Views/Compact/ClassicCompactView.swift)).
  - Routed dynamically via [`CompactIslandView.swift`](Sources/DynamicIsland/Views/Compact/CompactIslandView.swift).
- **Opened Island Styles (`OpenedIslandStyle`)**:
  - `defaultStyle` ("Default"): The complete multi-tab workspace with top header HUD, full-width sliding pill bar, and centered tool content ([`FullHubExpandedView.swift`](Sources/DynamicIsland/Views/Expanded/FullHubExpandedView.swift)).
  - Routed dynamically via [`ExpandedIslandView.swift`](Sources/DynamicIsland/Views/Expanded/ExpandedIslandView.swift).
- **Option Naming**:
  - Option names displayed to users must be clean and descriptive (e.g. `"Default"`), never prefixed with arbitrary numbers like `"Option 1"`.
- **Settings Switchability & Previews**:
  - Configured independently via `SettingsManager.shared.closedNotchStyle` and `SettingsManager.shared.openedIslandStyle`, persisted to `UserDefaults`.
  - Displayed in **General Preferences** with live interactive example cards (`ClosedOptionPreviewCard`, `OpenedOptionPreviewCard`) featuring live state toggles and scaled UI visual previews.

---

## 4. 🎨 Design System, Styling & Animation

### 4.1 Liquid Glass Styling
- Background uses `NSVisualEffectView` (`hudWindow` material, `behindWindow` blending) wrapped in `LiquidGlassBackground`.
- Overlaid with dark tint (`Color.black.opacity(0.52)`), gradient sheen, and a continuous specular border (`stroke`).

### 4.2 Expanded Header Structure
- **Expanded Width:** `560pt` (`AppState.expandedWidth`).
- **Left Ear:** Clickable title `Dynamic Island` (opens Settings / Preferences).
- **Center Notch Spacer:** Clear cutout matching detected hardware notch width (`max(170, detector.currentNotch.notchWidth)`).
- **Right Ear:** Inline 3-stat HUD (`CondensedSystemHUDView`) followed by the Pin button (`📌`).
- **HUD Order:** **CPU → RAM → Disk (used)** (Battery removed for compact elegance).

### 4.3 Full-Width Tab Bar
- Tabs: `Media`, `Drop Shelf`, `Timer`, `Clipboard`, `Notes`.
- Layout: Every tab pill uses `.frame(maxWidth: .infinity)` inside an `HStack(spacing: 4)` with `.padding(.horizontal, 40)` giving a generous 20pt margin from the vertical edges of the 560pt island.

### 4.4 Animation Architecture & Spring Physics (`IslandAnimations.swift`)
- **Physics Calibration (`IslandSpring`)**:
  - `expand`: `spring(response: 0.38, dampingFraction: 0.75)` — authentic Apple elastic ballooning expansion.
  - `collapse`: `spring(response: 0.30, dampingFraction: 0.84)` — snappy, clean snap-back to notch.
  - `tabSlide`: `spring(response: 0.32, dampingFraction: 0.76)` — sliding matched-geometry pill indicators.
  - `bouncy`: `spring(response: 0.22, dampingFraction: 0.65)` — tactile button click/toggle micro-interaction.
  - `visualizer`: `spring(response: 0.18, dampingFraction: 0.65, blendDuration: 0.04)` — organic audio wave bounce.
  - `hover`: `spring(response: 0.25, dampingFraction: 0.75)` — subtle 2% breathing expansion when cursor enters compact zone.
- **Continuous Shape Interpolation**:
  - `NotchIslandShape` & `IslandContainerShape` implement `AnimatablePair` across `cornerRadius`, `flareWidth`, and `flareHeight`, ensuring bezier curves and concave fillets morph smoothly without geometry snapping.
- **Matched Geometry & Asymmetric Transitions**:
  - Active tab indicators in both main navigation and timer mode use `@Namespace` and `.matchedGeometryEffect` to glide fluidly across pills.
  - View contents use asymmetric transitions with subtle vertical glide and opacity to eliminate flicker or clipping.

---

## 5. 🧩 Subsystem Architectures & Critical Gotchas

### 5.1 Media & NowPlaying Subsystem
- **Private `MediaRemote.framework` Dynamic Binding**:
  - macOS does not expose public headers for `MediaRemote`, but its symbols exist in the dyld shared cache.
  - Symbols dynamically resolved via `dlopen` and `dlsym`:
    - `MRMediaRemoteGetNowPlayingInfo`: Polls current track metadata and artwork.
    - `MRMediaRemoteRegisterForNowPlayingNotifications`: Listens to `kMRMediaRemoteNowPlayingInfoDidChangeNotification`.
    - `MRMediaRemoteSendCommand`: Sends native playback commands across the OS.
  - `AudioOutputMonitor` (CoreAudio): Uses `kAudioDevicePropertyDeviceIsRunningSomewhere` and `AudioObjectAddPropertyListenerBlock` to monitor active sound output instantaneously with 0 permissions.
- **`MRMediaRemoteSendCommand` Command IDs**:
  ```swift
  0 // Play (kMRPlay)
  1 // Pause (kMRPause)
  2 // Toggle Play / Pause (kMRTogglePlayPause)
  3 // Stop (kMRStop)
  4 // Next Track (kMRNextTrack)
  5 // Previous Track (kMRPreviousTrack)
  ```
  > [!IMPORTANT]
  > **Explicit Play/Pause vs Toggle Gotcha**: Browsers (Google Chrome, Brave, Arc, Edge) often ignore command `2` (`kMRTogglePlayPause`) when paused. To reliably control web playback, always send explicit command `0` (`kMRPlay`) when paused and command `1` (`kMRPause`) when playing.
  > **Direct Boolean State**: Use `MRMediaRemoteGetNowPlayingApplicationIsPlaying` directly rather than relying solely on `MRMediaRemoteGetNowPlayingApplicationPlaybackState` (which can return `<Paused>` for the default player path even when an audio session is actively streaming).
- **Synthetic Media Key Fallback Gotcha**:
  - `NSEvent.otherEvent(with: .systemDefined, ...).cgEvent?.post(tap: .cghidEventTap)` is **silently ignored by macOS** unless the process has Root or Accessibility permissions.
  - Always call `MRMediaRemoteSendCommand` first. AppleScript (`tell application "Music"`, `tell application "Spotify"`) is used for specific apps. When posting `cgEvent`, post to both `.cghidEventTap` and `.cgSessionEventTap`.
- **No Demo Player Rule**:
  - Production code must strictly reflect real media sessions. Demo player mocks, timers, and sparkle buttons must not be present in `MediaManager` or `MediaView`.

### 5.2 Drag-to-Notch Drop Shelf Subsystem
- `IslandContainerView.onDrop` accepts `[.fileURL, .item]`.
- `.onChange(of: isTargetedForDrop)` expands the island directly to the `dropShelf` tab as soon as dragged files enter the hover zone.
- Visual feedback is a pulsing 2pt blue border overlay (`Color.blue.opacity(0.8)`).
- Parked files are managed by `DropShelfManager.shared` with persistent security-scoped bookmarks and quick drag-out into Finder or other apps.

### 5.3 Timers & Stopwatch Subsystem
- Centered layout using `Spacer(minLength: 0)` on leading and trailing edges.
- Mode picker (`Timer` | `Stopwatch`) at the top of the tab with sliding matched indicator.
- Custom countdown input with H / M / S steppers.
- Millisecond precision stopwatch with split lap calculation (`Lap`, `Split`, `Total`), fastest lap green bolt (`⚡`) highlight, and slowest lap red tortoise (`🐢`) highlight.

### 5.4 Clipboard & Quick Notes Subsystem
- `ClipboardManager.shared` periodically polls system pasteboard change counts, deduplicates text and URLs, and persists recent items.
- `NotesManager.shared` provides persistent scratchpad storage with automatic debounce saving to disk and 1-click clipboard copying.

### 5.5 System HUD Telemetry Subsystem
- `SystemMonitor.shared` operates on a 2-second background timer.
- Telemetry telemetry values:
  - **CPU**: Host statistics calculated from CPU tick deltas (user, system, idle, nice).
  - **RAM**: Memory usage via `host_statistics64` (active + wired pages).
  - **Disk**: File system attributes query on root directory (`/`).
  - **Battery**: Real-time IOKit power source interrogation for percentage and charging state.

---

## 6. 🔄 State & Singletons Map

| Singleton | Responsibility |
| :--- | :--- |
| `AppState.shared` | Expansion state (`isExpanded`), active tab (`activeTab`), pinned (`isPinned`), hover state (`isHovering`) |
| `WindowController.shared` | `NSPanel` lifecycle, screen change observers, global mouse tracking |
| `SettingsManager.shared` | Preferences storage (`UserDefaults`), UI versions, notch style, menu bar icon visibility |
| `SettingsWindowController.shared` | Standalone settings window lifecycle, notification observers, window frame sizing |
| `MediaManager.shared` | System media observation, playback controls, spectrum visualizer data |
| `DropShelfManager.shared` | Parked files list, bookmark persistence, file operations |
| `SystemMonitor.shared` | 2-second background timer updating CPU, RAM, Disk, and Battery |
| `TimerManager.shared` | Countdown timer engine, precision stopwatch engine, lap recording |
| `ClipboardManager.shared` | System pasteboard polling and history items |
| `NotesManager.shared` | Persistent quick notes scratchpad |
| `SoundManager.shared` | Tactile audio feedback (click, expand, collapse, alert) |
| `NotchDetector.shared` | Hardware notch measurement via `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` |
