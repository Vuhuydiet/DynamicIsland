# 🏛️ Architecture

How the island window is built, shaped, animated, and hit-tested.

---

## 📑 Table of Contents

1. [Window & Panel](#1-window--panel)
2. [Hit-Testing & the Open-Top Rule](#2-hit-testing--the-open-top-rule)
3. [Notch Detection & Island Geometry](#3-notch-detection--island-geometry)
4. [Notch Sealing & Shape Construction](#4-notch-sealing--shape-construction)
5. [Liquid Glass Materials](#5-liquid-glass-materials)
6. [The Opened Island Shell](#6-the-opened-island-shell)
7. [Animation & Spring Physics](#7-animation--spring-physics)
8. [Docking Modes](#8-docking-modes)
9. [Focus & Key Handling](#9-focus--key-handling)
10. [State & Singletons Map](#10-state--singletons-map)
11. [Framework Dependencies](#11-framework-dependencies)
12. [Settings Window](#12-settings-window)

---

## 1. Window & Panel

The island lives in a single `DynamicIslandPanel` (`NSPanel` subclass) owned by
`WindowController`.

| Property | Value |
| :--- | :--- |
| `styleMask` | `[.borderless, .nonactivatingPanel]` |
| `level` | `.statusBar` |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` |
| `isOpaque` / `backgroundColor` | `false` / `.clear` |
| `canBecomeKey` / `canBecomeMain` | `true` / `false` |
| Panel size | from `canvasSize(for:)` — the larger of `880 × 720` or the max island plus shelf, clamped to the screen |
| Origin | `x = screen.midX - width/2`, `y = screen.maxY - height` |

The panel is **much larger than the visible island** on purpose. It is a
transparent canvas anchored to the top of the screen, giving headroom for the
largest expanded state (an island the user has dragged out to `1200 × 900 pt`)
plus the secondary drop shelf below the main island. Only the part that is actually
island geometry receives clicks — everything else is click-through.

Its size is derived from the screen rather than fixed, so the ceiling on how large
the island can become is the display itself rather than a constant that silently
caps it. Because the island is top-anchored and centred, the canvas growing changes
nothing about where the island sits.

`canBecomeKey` is required so text fields in the Notes and Clipboard tabs can
receive keyboard input. `canBecomeMain` is `false` so the island never becomes the
active application.

---

## 2. Hit-Testing & the Open-Top Rule

> [!WARNING]
> **Never use `NSRect.contains(mousePoint)` for the top edge.**
> `NSRect.contains` uses half-open intervals (`minY <= y < maxY`). When the cursor
> touches the screen's top physical pixel — `y == screen.frame.maxY` — it returns
> `false`. A hit test built on it will collapse the island at the exact moment the
> user hovers the notch.

The global mouse monitor must therefore apply **no upper bound on `y`**. Only
check horizontal bounds, and verify the cursor is still above the island's bottom
edge:

```swift
let inX = mouse.x >= (screen.frame.midX - islandW / 2.0 - margin)
       && mouse.x <= (screen.frame.midX + islandW / 2.0 + margin)
let inY = mouse.y >= (islandBottom - margin)   // no upper bound — open top
if !(inX && inY) {
    // collapse if not pinned
}
```

`DynamicIslandHostingView.hitTest(_:)` is the second half of this: it also evaluates
`appState.totalExpandedHeight` (main island + the 12pt gap + the drop shelf) so
clicks, drag-outs, and context menus on shelf cards work.

---

## 3. Notch Detection & Island Geometry

`NotchDetector` measures the hardware notch from the screen's auxiliary top areas.

| Case | `hasPhysicalNotch` | `notchWidth` | `notchHeight` |
| :--- | :--- | :--- | :--- |
| Real notch detected | `true` | measured | measured |
| Non-notched screen | `false` | `170` | `34` |
| No screen available (fallback) | `false` | `180` | `34` |

The width used everywhere in layout is floored so a degenerate measurement cannot
collapse the island: `max(170, notchDetector.currentNotch.notchWidth)`.

### Closed island width

```swift
compactEarWidthFixed = 56.0                       // constant, see below
compactEarWidth     = 56.0 + customWidthOffset / 2
compactIslandWidth  = notchWidth + 2 * compactEarWidth + 2 * compactFlareWidth  // notch mode
```

> [!IMPORTANT]
> **The closed island is a fixed-size window.** Its width is a property of the
> hardware notch plus a constant ear width — never of the current activity. Sizing
> the ears per-state was tried and reverted: an incoming notification ballooned the
> notch to 135pt ears, which read as the notch *glitching* rather than as a
> notification arriving. Content adapts to the fixed width instead — the left ear
> scales and truncates its text, the right ear is graphical only, and live
> indicators use glyphs rather than more room.

### Expanded geometry

| | System tools | Integrated apps |
| :--- | :--- | :--- |
| Island width | `560 pt` (`AppState.expandedWidth`) | the user's stored size, else `preferredIslandWidth`, default `740 pt` |
| Content height | `170 pt` | the user's stored size, else `preferredContentHeight`, default `400 pt` |

```swift
expandedHeight = notchTopInset + 38 + contentHeight + 16
totalExpandedHeight = shelfRectangleHeight > 0
    ? expandedHeight + 12 + shelfRectangleHeight
    : expandedHeight
```

The drop shelf is always measured as a **split secondary rectangle** 12pt below the
main island, never as part of it.

### The user can resize the opened island

On a **plugin tab** the island is resizable: a grip in the bottom-right corner drags
both axes, and the chosen size is remembered per plugin. Tool tabs keep their fixed
geometry — their content is a fixed-format readout rather than a document.

`AppState.resolvedSize(for:)` is the **single place a plugin's declared size is
read**, and the single resolution point for the whole island.
`expandedWidth` and `currentContentHeight` both consult it, so all six readers of the
geometry — the drawn frame, the tab bar, `DynamicIslandHostingView.hitTest`, and
`WindowController.checkMousePosition` — follow the user's size with no change at any
of them. A stored size that is not usable (`NaN`, infinite, or non-positive) is
discarded in favour of the plugin's declaration, so a corrupt preference degrades to
a working island rather than an invisible one.

Two constraints on the mechanism, both structural rather than tuned:

- **The panel is not the surface.** The island is a SwiftUI frame inside a
  transparent, click-through `NSPanel` that is deliberately *larger* than the island.
  Resizing the panel would resize the canvas, and because the island is top-anchored
  a taller frame pushes the visible top edge off-screen. The canvas is instead sized
  from the screen by `WindowController.canvasSize(for:)` and clamped to it, so the
  ceiling on island size is the display rather than a constant.
- **The grip, not `NSPanel.setFrame`.** A borderless window gets no resize cursor and
  no resize corner from macOS, so `IslandResizeGrip` draws its own affordance and
  AppKit's public diagonal cursor does not exist — the grip builds one from a
  template image via `NSCursor(image:hotSpot:)`.
- **The grip strokes the island's own shape path, in an `.overlay` applied after the
  `clipShape`.** `FullHubExpandedView.body` is a `VStack`, so a grip added as a child
  there is laid out *below* the content and then cut away — it is never drawn. The grip
  is therefore attached in `IslandContainerView` with `.overlay(alignment: .bottomTrailing)`
  **after** `.clipShape`.
  It strokes `containerShape.path(in:)` — the island's own outline — rather than
  building a corner from a radius. A hand-rolled arc cannot follow the edge, because
  the real bottom-right corner is neither a circle nor at the frame's corner: in notch
  mode `NotchIslandShape` curves it with radius `rBottom` centred at
  `(width - flareWidth - rBottom, height - rBottom)`, and in floating mode the shape is
  a `RoundedRectangle(.continuous)` squircle. Stroking the actual path fits by
  construction in both modes and leaves the radius with a single owner instead of a
  second copy that can drift.
  The visible run of edge comes from a diagonal gradient mask, so the brightest point
  is the corner itself and there is no separately-positioned tip to keep in sync. The
  mask covers only the corner's curve (its reach is sized to the 32pt bottom radius),
  so the straight edges above it stay plain glass.
  The failure here is silent and easy to misread: the web view is a `WKWebView` in an
  `NSViewRepresentable`, which composites above SwiftUI, so "the page is covering it"
  is always available as an explanation whether or not it is true.
  A bright 40×40 marker placed alongside the grip was *equally* invisible, which is
  what ruled the web view out and pointed at the layout instead.
- **A glow that traces a path must not own input.** Stroking the island's full
  outline is what makes the glow follow the real edge, but a stroked `Path` is
  hit-tested by its *fill* — the entire island — and `.mask` limits only what is
  drawn, never what is hit. With input attached, the invisible glow swallowed every
  click in the island and the unpin button stopped responding; nothing in the view
  looked wrong, and the pin button was still plainly drawn.
  The glow therefore carries `.allowsHitTesting(false)`, and the only thing accepting
  input is a separate 64pt corner square — well clear of the header, so it cannot
  shadow the pin button.
  More generally: any overlay that is invisible for most of its area is a trap, since
  the eye reports the visible part while the hit region covers the rest.
- **The grip's corner comes from `IslandGripRegion`, never from a hand-written rect.**
  SwiftUI's `y` grows *downward*, so a region written as `y: 0` is the island's **top**
  edge, not its origin-relative bottom corner. That single sign error put the grip's
  invisible hit region over the header, on the unpin button, while the visible glow sat
  correctly at the bottom corner — so unpin and the drag both failed while the glow
  rendered perfectly and every screenshot looked right.
  The named type makes the inversion unrepresentable, and `IslandGripRegionTests` pins
  each edge to the matching edge of the island; reintroducing the bug fails four of
  them, including the one that specifically asserts the grip is not the top corner.
- **The grip draws nothing; the cursor is the affordance.**
  A brightening rim on the bottom-right corner read as an active state rather than a
  handle, and it drew the eye to a part of the island that does nothing until dragged.
  The diagonal cursor carries it instead, which is how AppKit signals a resizable
  window. The visible part is gone, so the hit region is the *only* affordance and has
  to be large enough to find blind.
- **A live resize drag must not animate the width or height, and must not write to
  `UserDefaults` per frame.**
  Both were measured causes of the island trailing the pointer. The springs are for
  sizes the user did not choose frame by frame; during a drag the edge is expected to
  be glued to the cursor, and a spring makes the two visibly separate.
  And because `setIslandSizeOverride` runs on every pointer frame, a synchronous
  `JSONEncoder` + `defaults.set` on the main thread put that cost in front of layout
  and drawing. The live value publishes immediately; only the *write* is debounced, and
  `endResize` flushes it so the size the user chose is durable.
- **The glow rests at low intensity; it is not hover-only.** A faint glyph on
  translucent glass at 0.28 read as absent, and a glow visible only on hover would be
  the same failure with more steps — the affordance must be discoverable before the
  pointer arrives. It brightens and extends along the edge on hover, and saturates
  while dragging, with the diagonal `NSCursor` as the confirmation once the pointer is
  actually there.
- **A native view in the content still covers a SwiftUI overlay.** `NSViewRepresentable`
  composites **above** SwiftUI in the same layer, so neither ZStack order nor
  `.overlay` can lift a SwiftUI view over one. The grip avoids the fight by sitting
  in the island's bottom-right corner, outside the content's frame.

**A resize drag starts on the island's bottom edge**, which is exactly where the
mouse-leave check collapses it, so `AppState.isResizing` suspends that rule for the
duration of the drag. The alternative — widening the leave margin — buys correctness
by *disagreeing less often* about where the island is and leaves the overlap in place
for the next reader of that margin. The flag is also cleared in `collapse()`, so a
collapse triggered from outside the drag (Esc, a notification, a fullscreen
transition) cannot leave it pinned and wedge the island open.

Drag geometry is derived from the size the drag *started* at, never accumulated, so
the result cannot depend on the frame rate — see `IslandSize.resized(start:translation:)`

---

## 4. Notch Sealing & Shape Construction

`NotchIslandShape` is a custom `Shape` that flares outward into the top screen
bezel so the island appears to merge with the bezel rather than float over it.

| Constant | Compact | Expanded |
| :--- | :--- | :--- |
| `flareWidth` | `12 pt` | `22 pt` |
| `flareHeight` | `10 pt` | `18 pt` |
| `defaultBottomRadius` | `14 pt` | (uses the same default) |

The construction, in both states:

- **Top corners** — concave fillets flaring horizontally into the bezel.
- **Left/right edges** — true straight vertical lines (`flareHeight ... h - rBottom`).
- **Bottom corners** — convex continuous curves.
- **Bottom edge** — flat, enclosing the physical camera notch.

### Continuous interpolation

`NotchIslandShape` and `IslandContainerShape` implement `AnimatablePair` across
`cornerRadius`, `flareWidth`, and `flareHeight`:

```swift
public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
    AnimatablePair(flareWidth, AnimatablePair(flareHeight, rBottom))
}
```

This is what lets the bezier curves and concave fillets **morph** between the
compact and expanded geometries instead of snapping. The radius is clamped to
`h - flareHeight - 2` so the curves cannot self-intersect at small sizes.

---

## 5. Liquid Glass Materials

`LiquidGlassBackground` (`NSViewRepresentable`) wraps an `NSVisualEffectView`:

```swift
v.material     = .hudWindow
v.blendingMode = .behindWindow
v.state        = .active
v.isEmphasized = true
```

The visual stack is: `NSVisualEffectView` → dark tint (`Color.black.opacity(0.52)`)
→ gradient sheen → continuous specular border stroke. The whole stack is clipped to
the island shape so the glass never bleeds past the silhouette.

---

## 6. The Opened Island Shell

There is exactly **one** opened-island shell: `FullHubExpandedView`, routed through
`ExpandedIslandView`.

`OpenedIslandStyle` is intentionally retained as a **one-case `CaseIterable` enum**
rather than deleted, because:

- the persisted `openedIslandStyle` preference key and its accessor stay valid;
- `allCases`-driven UI keeps working;
- a future shell can be added as a new case with **no settings migration**.

The **"Opened Island UI"** section of General Preferences renders
`OpenedOptionPreviewCard` for every `allCases` entry, so a shell added later appears
in Settings with no change to that view. Per-shell display strings live on the style
itself as `badgeText` and `styleDescription`, and the card switches on the style —
adding a case without artwork therefore fails to compile.

`init(rawValue:)` still parses the removed shells' legacy strings (`"Bottom Deck"`,
`"Compact HUD"`, `"Floating Cards"`, `"Command Center"`) and coerces them to
`.defaultStyle`, so an upgrading user with a stale saved preference does not end up
with an unparsable setting.

### Universal Tab Content Rule

Shells own **layout only** — header organisation, tab navigation, transitions. Tab
content always renders through the single `IslandTabContentView`, which switches on
`AppState.activeTab` to the appropriate tool view.

Never duplicate a tool view per shell, and never customise tool content per layout
style. If a shell needs different content, that is a new tab, not a forked view.

### Header structure

| Region | Content |
| :--- | :--- |
| Left ear | Clickable `Dynamic Island` title → opens Preferences |
| Centre | Notch spacer cutout, `max(170, notchWidth)` |
| Right ear | `CondensedSystemHUDView` (CPU → RAM → Disk used), then the 📌 pin button |

---

## 7. Animation & Spring Physics

`IslandAnimations.swift` owns every spring in the app.

### Expansion choreography

`ExpansionAnimationStyle` is user-configurable (**Preferences → Animations**) and
persisted via `SettingsManager.shared.expansionAnimation`, scaled by
`animationSpeedMultiplier` (`0.60×`–`1.75×`).

| Preset | Character |
| :--- | :--- |
| `fluidApple` — "Fluid Apple" | Cupertino minimalism; symmetrical fluid ballooning with continuous bezier flares |
| `holographicHUD` — "Holographic HUD" | Stark-tech HUD; a cyan scan line sweeps down from the notch with corner targeting reticles |

`IslandContainerView` coordinates width, height, and content reveal through
`widthAnimation` / `heightAnimation` / `expandAnimation`, combined with the
`IslandVFXOverlayView` beam and reticles. Content transitions
(`expandedContentTransition`, `compactContentTransition`) derive their entrance
delays, scales, and fades from the selected style and the speed multiplier.

### Micro-interactions

| Spring | Value | Used for |
| :--- | :--- | :--- |
| `tabSlide` | `spring(response: 0.32, dampingFraction: 0.76)` | Sliding matched-geometry tab indicator |
| `bouncy` | `spring(response: 0.22, dampingFraction: 0.65)` | Button click/toggle feedback |
| `visualizer` | `spring(response: 0.18, dampingFraction: 0.65, blendDuration: 0.04)` | Audio wave bounce |
| `hover` | `spring(response: 0.25, dampingFraction: 0.75)` | Breathing expansion on compact-zone entry |

### Matched geometry

Active tab indicators use `@Namespace` + `.matchedGeometryEffect` to glide across
pills. View contents use asymmetric transitions with a subtle vertical glide and
opacity, to eliminate flicker and clipping on tab switch.

---

## 8. Docking Modes

`SettingsManager.notchStyle` controls how the island presents itself:

| Mode | Behaviour |
| :--- | :--- |
| `.auto` | Notch mode when a physical notch is detected, otherwise floating pill |
| `.notch` | Always attach to the notch |
| `.floating` | Always a floating capsule — for external and studio displays |

### One resolution point

Whether the island is in notch mode is decided in exactly one place:
`DockingMode.isNotchMode(style:hasPhysicalNotch:)`, a pure function reached in
production only through `NotchDetector.shared.isNotchMode`.

That matters because the same boolean sizes the drawn silhouette *and* the clickable
region, and the click region is the hand-written open-top rectangle from §2. It was
previously an inline `switch` at seven call sites — two sizing the hit test, two
drawing the matching shape — so a copy that drifted would make the island look
clickable where it was dead, with no build error. A new call site now cannot bypass
the rule, and `DockingModeTests` pins the policy.

Expansion is driven by `AppState`: hover, click, pin, or a distributed notification.
`expandTrigger` (`.hover` / `.clickOnly`) and `hoverDelay` shape the feel, and a
short collapse cooldown prevents flicker when the cursor crosses the island boundary.

---

## 9. Focus & Key Handling

The island is a `.nonactivatingPanel` ordered with `orderFrontRegardless()` — neither
of which grants key status. Without intervention, the user's next keystroke after
the island closes is lost, and `⌘C` / `⌘V` never reach the text fields inside it.

`IslandFocusController` is the single choke point for this:

| Call | Effect |
| :--- | :--- |
| `islandDidReceiveClick()` | `makeKey()` on the panel — called from `DynamicIslandHostingView.mouseDown` and `acceptsFirstMouse` |
| `resignFocusIfIdle()` | Hands the keyboard back to the app the user was working in — called on collapse |
| `installMainMenu()` | Installs the app + Edit menus, which is what makes `⌘C`/`⌘V`/`⌘Z` work at all |

`DynamicIslandHostingView.acceptsFirstMouse(for:)` returns `true` so the very first
click routes through that choke point rather than being swallowed as
activation-only.

Each keyboard combination has exactly **one** owner: plain `⌘,` belongs to the
Preferences menu item, and the local key monitor only claims the `⌥ + ⌘ + ,`
variant. `installMainMenu()` additionally asserts at `#if DEBUG` that no two edit
actions claim the same key equivalent, because AppKit would silently make one
unreachable.

---

## 10. State & Singletons Map

| Singleton | Responsibility |
| :--- | :--- |
| `AppState.shared` | Expansion, active tab (whose `didSet` dispatches plugin lifecycle + interaction audio), pinned, hover, drag-over |
| `WindowController.shared` | `NSPanel` lifecycle, screen-change observers, global mouse tracking |
| `SettingsManager.shared` | `UserDefaults` preferences, UI styles, menu-bar visibility, sparse per-plugin sound overrides |
| `SettingsWindowController.shared` | Standalone preferences window lifecycle |
| `MediaManager.shared` | System media observation, playback controls, spectrum data |
| `DropShelfManager.shared` | Parked files, security-scoped bookmarks, file operations |
| `SystemMonitor.shared` | 2-second timer updating CPU, RAM, disk, battery |
| `TimerManager.shared` | Countdown timer, precision stopwatch, lap recording |
| `ClipboardManager.shared` | Pasteboard polling and history |
| `NotesManager.shared` | Persistent scratchpad |
| `PluginManager.shared` | Plugin registry, lifecycle coordination |
| `PluginIconManager.shared` | Logo resolution, disk/memory caching, remote download |
| `PluginNotificationManager.shared` | Plugin notifications, in-notch alert, auto-dismiss, system banners |
| `WebAppRegistry.shared` | Reconciles stored descriptors to live `WebAppPlugin`s |
| `SoundManager.shared` | Tactile feedback and **all** plugin audio via `playPluginCue(_:pluginId:)` |
| `NotchDetector.shared` | Hardware notch measurement |
| `IslandFocusController.shared` | Main menu installation and the island focus choke point |
| `RightEarPolicy` | *(static type, not a singleton)* right-ear token contract + sanitiser |
| `TabDragCoordinator` | *(per-view `@StateObject`, not a singleton)* tab drag state machine |
| `DistributedObservationTokens` | *(static helper)* registers/unregisters block-based notification observers |

### Observer lifetime

The block-based `addObserver(forName:object:queue:using:)` API returns an opaque
token that must be handed back to `removeObserver`. `DistributedObservationTokens`
is the single registrar: it registers a name → handler map and returns the tokens as
a value, which each owner holds and releases in its `deinit`.

The alternative — the selector-based `addObserver(_:selector:name:object:)` with a
target — unregisters automatically when the target deallocates and needs no token.
Both forms are in use in this codebase, which is exactly why the distinction is
worth knowing before adding an observer.

---

## 11. Framework Dependencies

The project has **no third-party dependencies**. Everything is a system framework,
linked explicitly in `scripts/build_app.sh`:

| Framework | Used for |
| :--- | :--- |
| `AppKit` | `NSPanel`, `NSWindow`, `NSVisualEffectView`, menu bar extra |
| `SwiftUI` | All views |
| `Combine` | `ObservableObject` pipelines |
| `IOKit` | Battery telemetry, power source state |
| `CoreAudio` | Default output device + `kAudioDevicePropertyDeviceIsRunningSomewhere` playback detection |
| `AudioToolbox` | `NSSound` playback |
| `UserNotifications` | System notification banners |
| `ServiceManagement` | `SMAppService` launch-at-login |
| `WebKit` | `WKWebView` host for web plugins |

Additionally, `MediaRemote.framework` is used **privately** via runtime symbol
resolution — see [`MEDIA.md`](MEDIA.md).

---

## 12. Settings Window

`SettingsWindowView` follows the macOS System Settings design language: a `780 ×
640 pt` window with a frosted sidebar.

| Pane | Contents |
| :--- | :--- |
| **General** | Appearance themes, closed-notch style with interactive preview cards, menu-bar icon, launch at login |
| **Animations** | Expansion style presets, speed multiplier, and a live `AnimationPlaygroundView` simulator |
| **Behavior & Tabs** | Docking mode, expansion trigger, hover sensitivity, tab visibility, tab order with up/down arrows + reset, drop-shelf card style |
| **Plugins** | Per-plugin enable, zoom, reload, test notification, cache reset |
| **Sound Effects** | Global volume, theme scheme, per-event toggles, and per-plugin sound built by iterating the plugin registry |
| **Geometry & Notch** | Live notch telemetry readouts and pixel-accurate offset calibration |
| **Shortcuts** | Global keyboard shortcuts with `KeyCapView` styling, mouse gesture cheatsheet |
| **About** | System status, framework badges, quit |

Option names shown to users are clean and descriptive (`"Default"`), never
numbered (`"Option 1"`).

### File layout

One file per pane under `Views/Expanded/Settings/`, so that editing the sound pane
does not require loading the geometry pane. `SettingsWindowShell.swift` holds the
window itself, the `SettingsTab` registry, and the primitives every pane shares
(`SettingsCard`, `SettingsRow`, `KeyCapView`).

| File | Owns |
| :--- | :--- |
| `SettingsWindowShell.swift` | Window, sidebar, `SettingsTab`, shared row/card primitives |
| `GeneralSettingsTab.swift` | General pane, plus `ThemeCard` and `ClosedOptionPreviewCard` (rendered only there) |
| `AnimationsSettingsTab.swift` | Animations pane, `AnimationCard`, `AnimationPlaygroundView` |
| `BehaviorSettingsTab.swift` | Behavior & Tabs pane |
| `SoundSettingsTab.swift` | Sound pane, `PluginSoundSettingsRow`, `SoundEventRow` |
| `GeometrySettingsTab.swift` | Geometry & Notch pane |
| `ShortcutsSettingsTab.swift` | Shortcuts pane, `ShortcutRow` |
| `AboutSettingsTab.swift` | About pane |
| `PluginsSettingsTab.swift` | Plugins pane |
