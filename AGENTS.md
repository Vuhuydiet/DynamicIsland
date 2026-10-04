# AGENTS.md — Contributor & AI Agent Guide

This document captures architectural decisions, build instructions, design principles, and critical gotchas for developers and AI agents working on the **Dynamic Island** codebase.

---

## 📑 Table of Contents
0. [🚨 Engineering Rule: Behaviours Must Be Code-Enforced](#0-engineering-rule-behaviours-must-be-code-enforced)
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
   - [5.6 Standardized Components & Plugin Architecture Subsystem](#56-standardized-components--plugin-architecture-subsystem)
6. [🔄 State & Singletons Map](#6-state--singletons-map)

---

## 0. 🚨 Engineering Rule: Behaviours Must Be Code-Enforced

> **"Prior code to guarantee app's behaviours, not by docs or comment."**

This is the highest-priority rule in this repository. It sits above every other
section, including the build instructions.

### 0.1 The Rule

Whenever the application is supposed to *do* something, or *not* do something, that
constraint **must be expressed in executable code that fails loudly when violated** —
never only in a comment, a docstring, a prompt to an AI agent, a code review
checklist, or a line in this file.

If a behaviour is only described in prose, it is not implemented. It is a wish.

### 0.2 Why

Prose-only enforcement fails in three concrete, observed ways in this codebase:

1. **It is invisible at the edit site.** A contributor adding a branch to a long
   `if/else` chain never reads the comment on line 900. The rule must live in the type
   or the function signature they are forced to call.
2. **It does not survive refactors.** Comments get moved, deleted, or contradicted by
   the next change. Types do not.
3. **It cannot cover future contributors.** An AI agent or a new plugin author will
   not have read `AGENTS.md`. They *will* have to satisfy the compiler.

### 0.3 How To Comply — Escalating Levels of Enforcement

Prefer the strongest mechanism available. Work down this list:

| Level | Mechanism | Use when |
| :--- | :--- | :--- |
| 1 | **Type-level restriction** | Make the illegal state unrepresentable. The right ear accepts only `RightEarToken`, which has no case that carries text, so text cannot be rendered there at all. |
| 2 | **Required protocol conformance** | Make omission a **compile error**. `IslandPlugin` requires `defaultSoundProfile` and `compactStatusToken()`, so a new plugin cannot silently skip sound config or skip the right-ear contract. |
| 3 | **Single choke-point function** | Route every call path through one function that validates. `RightEarPolicy.token(for:)` and `SoundManager.playPluginCue(_:pluginId:)` are the only sanctioned entry points. |
| 4 | **Automated guard** | A script or test that fails the build on violation. Use for cross-cutting invariants. |
| 5 | **Debug-time assertion + log** | `#if DEBUG` diagnostics naming the offending call site. Supporting evidence, never the primary guarantee. |
| ❌ | Comment / doc / prompt / checklist | **Never sufficient on its own.** |

### 0.4 Testability Precondition

A behaviour that is asserted only in a comment cannot be tested. When adding a guard,
prefer designs that make the invariant **unit-testable** without launching the app:

- Expose a pure policy function (e.g. `RightEarPolicy.token(for:)`) rather than burying
  the logic inside a `body`.
- Keep policy types `Equatable`/`Codable` so assertions are trivial.
- A closed enum is both the enforcement mechanism *and* the test surface.

### 0.5 When Adding a New Guard

Checklist (the enforcement, not the rule, is the deliverable):

- [ ] Illegal behaviour is **impossible** (level 1) or **won't compile** (level 2).
- [ ] There is exactly **one** entry point; nobody can bypass it with a direct call.
- [ ] The guard covers **all** current call sites, not just the obvious one.
- [ ] The invariant is **unit-testable** as a pure function.
- [ ] `#if DEBUG` diagnostics name the violating call site, so mistakes are loud in development.
- [ ] The override path, if any, is **explicit and centralised** (e.g. a settings flag),
      never a scattered per-call-site `if`.

### 0.6 Live Examples in This Repo

These are the reference implementations to imitate:

| Behaviour | Enforcement | Location |
| :--- | :--- | :--- |
| No text on the closed-notch right ear (battery % excepted) | Level 1 — right ear takes only `RightEarToken`; no case accepts a string | `Views/Compact/RightEarPolicy.swift`, `ClassicCompactRightEarView` |
| Plugins cannot inject arbitrary views into the right ear | Level 1 — `compactStatusToken()` returns a token, not an `AnyView` | `Plugins/IslandPlugin.swift` |
| Every plugin is configurable with sound | Level 2 — `defaultSoundProfile` is a required protocol member; Settings UI iterates the registry | `Plugins/PluginSoundProfile.swift`, `SoundSettingsTab` |
| Plugin sounds honour global **and** per-plugin settings | Level 3 — sole entry point `SoundManager.playPluginCue(_:pluginId:)` | `App/SoundManager.swift` |
| Plugins get lifecycle callbacks + interaction audio on tab switch | Level 3 — `activeTab.didSet` dispatches; call sites cannot forget | `Models/AppState.swift` |
| No y-overflow hit-test collapse at the screen's top pixel edge | Level 3 — hit-test omits any upper `y` bound | `App/WindowController.swift` |
| Tab content identical across all opened-island shells | Level 3 — one `IslandTabContentView`, embedded by every shell | `Views/Expanded/IslandTabContentView.swift` |

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
-framework UserNotifications \
-framework WebKit
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
- Panel size: `880 × 720` (content origin aligned to screen top: `y = screen.frame.maxY - 720`, providing generous headroom for large integrated apps up to 780×500pt with bottom shelf).

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
    - **Right-ear text contract (code-enforced, not a convention)**: the right ear renders **no text at all** except the battery percentage. This is guaranteed structurally by `RightEarToken` (§0.6) — the ear resolves a token, and no token case except `.battery` can carry a string. Every right-ear state (media visualizer, media pause glyph, timer progress ring, timer done pulse, stopwatch lap flag, stopwatch state dot, drop-shelf glyph, plugin icon, notification icon) is graphical by construction. Do **not** reintroduce labels such as `"Timer"`, `"Paused"`, `"Stopwatch"`, `"Done!"`, `"L<n>"`, or notification message bodies here; if a label is genuinely needed, put it on the **left** ear, which does permit text.
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
  - Routed via [`ExpandedIslandView.swift`](Sources/DynamicIsland/Views/Expanded/ExpandedIslandView.swift).
  - **Single-shell policy**: the app ships exactly one opened-island shell. The `Bottom Deck`, `Compact HUD`, `Floating Cards`, and `Command Center` shells were removed. `OpenedIslandStyle` is intentionally retained as a one-case `CaseIterable` enum so the persisted `openedIslandStyle` preference key and any `allCases`-driven UI keep working, and so a future shell can be added as a new case without a settings migration. `init(rawValue:)` still parses the removed shells' legacy strings and coerces them to `.defaultStyle`, so upgrading users with a stale saved preference are not left with an unparsable setting. The matching Preferences gallery (`OpenedOptionPreviewCard`) and its per-shell preview bodies were deleted.
- **Option Naming**:
  - Option names displayed to users must be clean and descriptive (e.g. `"Default"`), never prefixed with arbitrary numbers like `"Option 1"`.
- **Settings Switchability & Previews**:
  - Configured independently via `SettingsManager.shared.closedNotchStyle` and `SettingsManager.shared.openedIslandStyle`, persisted to `UserDefaults`.
  - **Closed Notch** is displayed in **General Preferences** with live interactive example cards (`ClosedOptionPreviewCard`) featuring live state toggles and scaled UI visual previews. Opened Island no longer needs a picker, since only one shell exists.

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

### 4.3 Full-Width Tab Bar & Reordering Architecture
- **Supported Tabs**: `Media`, `Timer`, `Clipboard`, `Notes`, `Messenger`, and dynamically loaded `IslandPlugin` extensions (Drop Shelf decoupled from tab bar into an instantaneous notch flyout tray).
- **Layout**: Every tab pill uses `.frame(maxWidth: .infinity)` inside an `HStack(spacing: 4)` with `.padding(.horizontal, 40)` giving a generous margin from the vertical edges.
- **Dynamic Reordering & Customization**:
  - Configurable in Preferences (**Behavior & Tabs → Island Tabs & Order**) with interactive up/down reorder arrows (`chevron.up`, `chevron.down`), position indicators (`#1, #2, ...`), and a 1-click **Reset Order** action.
  - Persisted in `SettingsManager.shared.customTabOrder: [String]` under UserDefaults key `"customTabOrder"`.
  - Derived centrally via `IslandTab.allCases` calling `SettingsManager.shared.orderedTabs(from: defaultTabs)`. Any newly registered plugins or unlisted tabs are safely appended to the end.
  - Dynamically updates the opened island's tab bar (`FullHub`) with fluid `.animation(IslandSpring.tabSlide, value: visibleTabs)` physics.
  - Distributed notifications: `com.dynamicisland.reorderTabs` (accepts comma-separated list of IDs) and `com.dynamicisland.resetTabOrder`.

### 4.4 Animation Architecture & Spring Physics (`IslandAnimations.swift`)
- **Configurable Expansion Choreography Styles & VFX Engine (`ExpansionAnimationStyle` & `IslandVFXOverlayView`)**:
  - Dynamically configured in Preferences (**Animations → Expansion Animation Styles**), persisted via `SettingsManager.shared.expansionAnimation` and scaled via `SettingsManager.shared.animationSpeedMultiplier` (0.60×–1.75×).
  - Presets:
    - `fluidApple` ("Fluid Apple"): Authentic Cupertino minimalism — symmetrical fluid ballooning with continuous bezier flares.
    - `holographicHUD` ("Holographic HUD"): Iron Man / Stark Tech — cyan laser scan line sweeps down from the camera notch accompanied by HUD corner targeting reticles (`[ ]`).
- **Dynamic Physics & Staged Geometry Resolution**:
  - `IslandContainerView` coordinates width, height, and content reveal through `settings.expansionAnimation.widthAnimation`, `heightAnimation`, and `expandAnimation`, combined with the sweeping laser beam and corner reticles in `IslandVFXOverlayView`.
  - Asymmetric content transitions (`expandedContentTransition`, `compactContentTransition`) automatically adjust entrance delays, scales, and fade timings based on the selected animation style and speed multiplier.
- **Micro-Interactions**:
  - `tabSlide`: `spring(response: 0.32, dampingFraction: 0.76)` — sliding matched-geometry pill indicators.
  - `bouncy`: `spring(response: 0.22, dampingFraction: 0.65)` — tactile button click/toggle micro-interaction.
  - `visualizer`: `spring(response: 0.18, dampingFraction: 0.65, blendDuration: 0.04)` — organic audio wave bounce.
  - `hover`: `spring(response: 0.25, dampingFraction: 0.75)` — subtle 2% breathing expansion when cursor enters compact zone.
- **Continuous Shape Interpolation**:
  - `NotchIslandShape` & `IslandContainerShape` implement `AnimatablePair` across `cornerRadius`, `flareWidth`, and `flareHeight`, ensuring bezier curves and concave fillets morph smoothly without geometry snapping.
- **Matched Geometry & Asymmetric Transitions**:
  - Active tab indicators in both main navigation and timer mode use `@Namespace` and `.matchedGeometryEffect` to glide fluidly across pills.
  - View contents use asymmetric transitions with subtle vertical glide and opacity to eliminate flicker or clipping.

### 4.5 Settings Window Architecture (`SettingsWindowView.swift`)
- Re-architected with macOS System Settings design language (780×640pt window with 215pt frosted sidebar).
- Categorized tabs:
  1. `General`: Appearance themes, Island UI layout shells (`ClosedOptionPreviewCard`, `OpenedOptionPreviewCard`), and System startup/menu bar integration.
  2. `Animations`: Dedicated expansion spring physics hub with live interactive notch playground simulator (`AnimationPlaygroundView`), style preset cards, and speed multiplier slider.
  3. `Behavior & Tabs`: Docking modes (Auto Detect, Attached to Notch, Floating Pill), expansion triggers & hover sensitivity, tab visibility manager, and drop shelf layout.
  4. `Sound Effects`: Global volume, audio theme scheme, and per-event sound toggles with live audition buttons.
  5. `Geometry & Notch`: Real-time hardware notch telemetry readouts and pixel-accurate offset calibration.
  6. `Shortcuts`: Global keyboard shortcuts with native `KeyCapView` styling and mouse gestures cheatsheet.
  7. `About`: System status, framework badges, and application quit controls.

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
- **Dedicated Split Bottom Shelf Architecture (`BottomShelfRectangleView.swift`)**:
  - The Drop Shelf is completely decoupled from the main tab bar, eliminating tab clutter when empty.
  - When files are parked or being dragged towards the notch, `BottomShelfRectangleView` unfolds as a dedicated, split secondary floating rectangle 12pt below the main island.
  - **Width Calibration**: The shelf uses `islandBodyWidth = islandWidth - (expandedFlareWidth * 2)` (`516pt` for default 560pt island) to align flush with the straight vertical walls of the main island, avoiding protrusion caused by the top screen-bezel concave flares.
  - **Drop Routing Rule (Tray Drop Only)**:
    - Dragging over the main notch/island triggers expansion (`appState.isDraggingOver = true; appState.expand()`) to reveal the shelf below, but the main island **strictly rejects drops** (`return false`) to prevent accidental file parking over tab contents.
    - Dropping is **exclusively accepted by the bottom shelf tray** (`BottomShelfRectangleView.onDrop`), which provides an illuminated cyan border, glow shadow, and dynamic label ("Release to park on shelf").
    - Inter-rectangle hover transition is smoothed via an 0.8s debounce timer (`scheduleDragExitCheck`), preventing premature shelf disappearance when the cursor crosses the 12pt gap.
  - **Hit-Testing**: `DynamicIslandHostingView.hitTest` and `WindowController` mouse tracking evaluate `appState.totalExpandedHeight` (`mainH + 12pt + shelfRectangleHeight`) so mouse clicks, drag-outs, and contextual menus on shelf cards function properly.
  - Users can retrieve files in **1 action** (simply hover the notch to reveal the shelf and drag files out directly, zero tab clicks needed).
  - Configurable card styles in Settings: **Square Cards** (default: 68×66pt card with 32×32 icon and hover `xmark` delete) or **Compact Strip** (horizontal capsules).
- Parked files are managed by `DropShelfManager.shared` with multi-tier ingestion fallback (`loadObject`, `loadItem("public.file-url")`, `NSPasteboard(name: .drag)`), persistent security-scoped bookmarks, and quick drag-out into Finder or other apps.

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

### 5.6 Standardized Components & Plugin Architecture Subsystem
- **Standardized UI Component Library (`IslandComponents.swift`)**:
  - `IslandHeaderView`: Universal header component for built-in tabs and external plugins with leading icon/title/subtitle/status badge and trailing action buttons.
  - `IslandCardView`: Standard continuous rounded corner container (`Color.white.opacity(0.06)` with specular border).
  - `IslandButton`: Tactile bouncy button with styles (`.primary`, `.secondary`, `.ghost`, `.tinted`, `.danger`) and sizes (`.small`, `.regular`, `.large`).
  - `IslandSearchField`: Universal search bar with auto-clear button and active glow stroke.
  - `IslandDivider`: Unified translucent Liquid Glass ruler.
  - `IslandEmptyStateView`: Standard empty/offline placeholder.
- **Universal Plugin Protocol (`IslandPlugin.swift` & `PluginManager.swift`)**:
  - Any app or tool can be injected into the Dynamic Island by implementing `IslandPlugin`.
  - Supports capability flags (`.variableHeight`, `.compactAccessory`, `.customSettings`, `.deepLinking`).
  - Lifecycle hooks: `onRegister()`, `onEnable()`, `onDisable()`, `onTabSelected()`, `onTabDeselected()`. These are dispatched from `AppState.activeTab.didSet` (see §0.6), so no assignment site can forget them.
  - **Required members that are compile-time obligations, not suggestions**: `defaultSoundProfile` (sound config — see below) and `compactStatusToken()` (right-ear contract — see `RightEarToken`). Omitting either fails compilation, per §0.3 level 2.
  - Dynamic sizing for integrated apps: Tabs and plugins declare `preferredIslandWidth` (defaults to `740.0pt` for integrated apps vs `560.0pt` for lightweight system utilities) and `preferredContentHeight` (defaults to `400.0pt` for apps vs `170.0pt` for tools).
  - Both width and height morph fluidly with spring physics when switching between tool tabs and integrated app tabs.
- **Per-Plugin Audio Subsystem (`PluginSoundProfile.swift`)**:
  - `IslandPluginSoundProfile` (per-plugin `isEnabled`, `volume`, `alertCue`, `interactionCue`) plus `IslandPluginSoundEvent.allCases` (`.alert`, `.interaction`) and the curated `IslandSoundCue` set.
  - **Every plugin is automatically sound-configurable**: `SoundSettingsTab` iterates `PluginManager.shared.plugins` and builds controls from `IslandPluginSoundEvent.allCases`, so registering a new plugin produces working audio settings with **zero UI code** — this is the §0.3 level-2 guarantee in action.
  - User overrides live in `SettingsManager.pluginSoundOverrides` (JSON-encoded, keyed by plugin id) and are *sparse*: absent ids fall back to the plugin's `defaultSoundProfile`, so shipping a new plugin or a new default cue needs no migration.
  - `SettingsManager.soundProfile(forPlugin:)` is the single resolution point; `updatePluginSound(_:_:)` and `resetPluginSound(_:)` are the only mutators.
  - **All** plugin audio is emitted through `SoundManager.playPluginCue(_:pluginId:)`, which is the sole choke point honouring the global `soundEffectsEnabled` master switch, the per-plugin mute, and `globalVolume × pluginVolume`. Do not call `NSSound` directly for plugin feedback.
  - Alerts route here from `PluginNotificationManager.displayNotification(_:)`; interactions route from `AppState.notifyTabLifecycleChange(from:to:)`.
- **Web App Injection Infrastructure (`IslandWebPlugin.swift`)**:
  - Reusable `WKWebView` wrapper (`IslandWebViewHost` & `IslandWebController`) with desktop Safari User-Agent, custom zoom factors (default 0.88), custom CSS/JS injection, and persistent cookie/session storage.
  - Interactive dynamic zoom controls (`zoomIn()`, `zoomOut()`, `setZoom()`, `resetZoom()`).
  - Title change observation automatically detects unread notification badges (e.g. `(3) Messenger`).
- **Standardized App Icon & Asset Pipeline (`PluginIconManager.swift`)**:
  - Centralized manager for discovering, downloading, caching, and serving authentic logos for plugins and island tabs.
  - Multi-tier discovery hierarchy:
    1. In-memory `NSCache`.
    2. Persistent user cache: `~/Library/Application Support/DynamicIsland/PluginIcons/<id>.png`.
    3. Bundled assets: `DynamicIsland.app/Contents/Resources/PluginIcons/<id>.png` (copied from `Resources/PluginIcons/` at build time).
    4. Development project directory: `Resources/PluginIcons/<id>.png`.
    5. Installed macOS Application bundle icon (`PluginManager.appIcon(bundleIdentifier:)`).
    6. Custom plugin view provider or SF Symbol fallback.
  - Dynamic logo download: `downloadAndCacheIcon(from:for:completion:)` downloads remote logos directly to disk and memory cache.
  - Standardized View Providers: `iconView(for: IslandTab, size:)` and `iconView(for: any IslandPlugin, size:)`.
- **Facebook Messenger Integration (`MessengerPlugin.swift`)**:
  - Official web messenger embedded into the opened island for frictionless chatting.
  - Generous dimensions: `740 × 400 pt` viewport providing comfortable room for conversation lists, active chat threads, and photo attachments.
  - Dynamic zoom buttons (`+` and `-`) in header and settings to customize scale.
  - Authentic App Icon: Direct high-resolution PNG asset (`Resources/PluginIcons/messenger.png`) bundled and loaded via `PluginIconManager`, with fallback to `MessengerAppIconView` squircle or vector gradient.
  - Real-time unread badge count displayed on the Messenger tab pill and in the closed notch ear (`makeCompactAccessory`).
  - Settings window controls: "Open Messenger in Notch", "Open in Browser", "Reload", Zoom controls, "Test Notification", and "Log Out / Reset Cache".
- **Plugin Notification Subsystem (`PluginNotificationManager.swift`)**:
  - Full-featured notification pipeline for external plugins and web applications.
  - **HTML5 Web Notification Bridge**: Automatically injects a polyfill into `WKWebView` at document start, routing JavaScript `new Notification(title, options)` calls through `WKScriptMessageHandler` (`islandNotification`) to native Swift.
  - **Title Flashing Observation**: Detects incoming chat alerts formatted as `(N) Sender: Message` or unread count increments.
  - **In-Notch Live Alert Pill**: When the notch is compact, an incoming notification smoothly balloons the compact notch from 56pt to 135pt ears, showing the app logo + sender on the **left** ear, and — per the right-ear contract (§0.6) — **only the sender's icon on the right ear, never the message text** — with auditory feedback via the plugin's own configured cue (`SoundManager.shared.playPluginCue(.alert, pluginId:)`).
  - **Auto-Dismiss & Tap-to-Chat**: Banners automatically contract after 4.5 seconds. Tapping the live alert pill immediately opens the island directly into that plugin's tab.
  - **Native macOS Notification Integration**: Posts requests to `UNUserNotificationCenter`. Clicking system banners routes straight to the corresponding plugin tab.
  - **Distributed Notification Observer**: Listens on `com.dynamicisland.pluginNotification` for external triggering.

---

## 6. 🔄 State & Singletons Map

| Singleton | Responsibility |
| :--- | :--- |
| `AppState.shared` | Expansion state (`isExpanded`), active tab (`activeTab`, whose `didSet` dispatches plugin lifecycle + interaction audio), pinned (`isPinned`), hover state (`isHovering`) |
| `WindowController.shared` | `NSPanel` lifecycle, screen change observers, global mouse tracking |
| `SettingsManager.shared` | Preferences storage (`UserDefaults`), UI versions, notch style, menu bar icon visibility, sparse per-plugin sound overrides (`soundProfile(forPlugin:)`) |
| `SettingsWindowController.shared` | Standalone settings window lifecycle, notification observers, window frame sizing |
| `MediaManager.shared` | System media observation, playback controls, spectrum visualizer data |
| `DropShelfManager.shared` | Parked files list, bookmark persistence, file operations |
| `SystemMonitor.shared` | 2-second background timer updating CPU, RAM, Disk, and Battery |
| `TimerManager.shared` | Countdown timer engine, precision stopwatch engine, lap recording |
| `ClipboardManager.shared` | System pasteboard polling and history items |
| `NotesManager.shared` | Persistent quick notes scratchpad |
| `PluginManager.shared` | Central registry, lifecycle coordinator, and state manager for plugins |
| `PluginIconManager.shared` | Standardized logo resolution, disk/memory caching, asset bundling, and remote icon downloader |
| `PluginNotificationManager.shared` | Plugin notifications coordinator, in-notch alert balloon, auto-dismiss, system banners |
| `MessengerPlugin.shared` | Facebook Messenger integration controller, web session host, unread badge tracker |
| `SoundManager.shared` | Tactile audio feedback (click, expand, collapse, drop, timer alert) and **all** plugin audio via the sole `playPluginCue(_:pluginId:)` choke point |
| `RightEarPolicy` | (static type, not a singleton) Closed-notch right-ear contract: `RightEarToken` token space + `token(for:)` sanitiser. See §0.3 and §0.6 |
| `NotchDetector.shared` | Hardware notch measurement via `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` |
