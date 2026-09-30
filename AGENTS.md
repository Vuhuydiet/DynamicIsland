# AGENTS.md — Contributor & AI Agent Guide

This document captures architectural decisions, build instructions, and critical gotchas for developers and AI agents working on the **Dynamic Island** codebase.

---

## 🛠️ Build Environment & Toolchain

### 1. Developer Directory Requirement
On systems where Xcode GUI license agreements have not been accepted or differ from Command Line Tools, calling `swiftc`, `xcodebuild`, or build tools directly may prompt an interactive license block.
**Always prefix build commands with `DEVELOPER_DIR`:**
```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh
```

### 2. Required Frameworks
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

### 3. Build & Relaunch Workflow
```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh && \
pkill -f DynamicIsland || true && \
sleep 0.4 && \
open /Users/vuhuydiet/dev/dynamic-island/DynamicIsland.app
```

---

## 📐 Window & Geometry Architecture

### 1. NSPanel Specification (`WindowController.swift`)
The island window is a `DynamicIslandPanel` (subclass of `NSPanel`) with:
- `styleMask`: `[.borderless, .nonactivatingPanel]`
- `level`: `.statusBar`
- `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
- `isOpaque = false`, `backgroundColor = .clear`
- Panel size: `640 × 340` (content origin aligned to screen top: `y = screen.frame.maxY - 340`).

### 2. Open-Top Mouse Hit-Testing Gotcha
**Critical:** `NSRect.contains(mousePoint)` uses half-open intervals (`minY <= y < maxY`). When the cursor touches the screen's top physical pixel edge (`y == screen.frame.maxY`), `NSRect.contains` returns `false`!
- The global mouse movement monitor in `WindowController` **must never apply an upper-bound check on `y`**.
- Only check horizontal bounds and that the cursor remains above the panel bottom:
  ```swift
  let inX = mouse.x >= (screen.frame.midX - islandW / 2.0 - margin)
         && mouse.x <= (screen.frame.midX + islandW / 2.0 + margin)
  let inY = mouse.y >= (islandBottom - margin)
  if !(inX && inY) {
      // collapse if not pinned
  }
  ```

### 3. Notch Sealing (Flat-Top Corners)
In notch mode, the island top corners must be `0` (`topCornerRadius = 0` via `UnevenRoundedRectangle` and `CALayer.maskedCorners`):
- Leaving a rounded corner radius at the top creates crescent gaps where mouse movements slip between the bezel and the window.
- Only the bottom corners (`bottomLeadingRadius`, `bottomTrailingRadius`) receive rounding (`26pt` expanded, `14pt` compact).

---

## 🎵 Media & NowPlaying Architecture

### 1. Private `MediaRemote.framework` Dynamic Binding
macOS does not expose public headers for `MediaRemote`, but its functions are in the system dyld shared cache.
We dynamically resolve symbols via `dlopen` and `dlsym`:
- `MRMediaRemoteGetNowPlayingInfo`: Polls current track metadata and artwork.
- `MRMediaRemoteRegisterForNowPlayingNotifications`: Listens to `kMRMediaRemoteNowPlayingInfoDidChangeNotification`.
- `MRMediaRemoteSendCommand`: Sends native playback commands across the OS.

### 2. `MRMediaRemoteSendCommand` Command IDs
```swift
0 // Play
1 // Pause
2 // Toggle Play / Pause
3 // Next Track
4 // Previous Track
```

### 3. Synthetic Media Key Fallback Gotcha
`NSEvent.otherEvent(with: .systemDefined, ...).cgEvent?.post(tap: .cghidEventTap)` is **silently ignored by macOS** unless the process has Root or Accessibility permissions.
- Always call `MRMediaRemoteSendCommand` first.
- AppleScript (`tell application "Music"`, `tell application "Spotify"`) is used for specific apps.
- When posting `cgEvent`, post to both `.cghidEventTap` and `.cgSessionEventTap`.

### 4. No Demo Player
Production code must strictly reflect real media sessions. Demo player mocks, timers, and sparkle buttons must not be present in `MediaManager` or `MediaView`.

---

## 🎨 UI & Layout Rules

### 1. Liquid Glass Styling
- Background uses `NSVisualEffectView` (`hudWindow` material, `behindWindow` blending) wrapped in `LiquidGlassBackground`.
- Overlaid with dark tint (`Color.black.opacity(0.52)`), gradient sheen, and a continuous specular border (`stroke`).

### 2. Expanded Header Structure
- **Expanded Width:** Fixed at `600pt`.
- **Left Ear:** Clickable title `Dynamic Island` (opens Settings / Preferences).
- **Center Notch Spacer:** Clear cutout matching detected hardware notch width (`max(170, detector.currentNotch.notchWidth)`).
- **Right Ear:** Inline 4-stat HUD (`CondensedSystemHUDView`) followed by the Pin button (`📌`).
- **HUD Order:** **CPU → RAM → Disk (used) → Battery**.

### 3. Full-Width Tab Bar
- Tabs: `Media`, `Drop Shelf`, `Timer`, `Clipboard`, `Notes`.
- Layout: Every tab pill uses `.frame(maxWidth: .infinity)` inside an `HStack(spacing: 4)` so buttons evenly fill the 600pt bar.

### 4. Centered Timer & Stopwatch
- Both Countdown Timer and Stopwatch content are centered using `Spacer(minLength: 0)` on both leading and trailing edges.
- Mode Picker (`Timer` | `Stopwatch`) is centered at the top of the tab.
- Custom time input uses H / M / S steppers with chevrons.

### 5. Drag-to-Notch Drop Shelf
- `IslandContainerView.onDrop` accepts `[.fileURL, .item]`.
- `.onChange(of: isTargetedForDrop)` expands the island directly to the `dropShelf` tab as soon as dragged files enter the hover zone.
- Visual feedback is a pulsing 2pt blue border overlay (`Color.blue.opacity(0.8)`).

---

## 🔄 State & Singletons Map

| Singleton | Responsibility |
| :--- | :--- |
| `AppState.shared` | Expansion state (`isExpanded`), active tab (`activeTab`), pinned (`isPinned`), hover state (`isHovering`) |
| `WindowController.shared` | `NSPanel` lifecycle, screen change observers, global mouse tracking |
| `SettingsManager.shared` | Preferences storage (`UserDefaults`), notch style (`auto`/`notch`/`floating`), menu bar icon visibility |
| `MediaManager.shared` | System media observation, playback controls, spectrum visualizer data |
| `DropShelfManager.shared` | Parked files list, bookmark persistence, file operations |
| `SystemMonitor.shared` | 2-second background timer updating CPU, RAM, Disk, and Battery |
| `TimerManager.shared` | Countdown timer engine, precision stopwatch engine, lap recording |
| `ClipboardManager.shared` | System pasteboard polling and history items |
| `NotesManager.shared` | Persistent quick notes scratchpad |
| `SoundManager.shared` | Tactile audio feedback (click, expand, collapse, alert) |
| `NotchDetector.shared` | Hardware notch measurement via `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` |
