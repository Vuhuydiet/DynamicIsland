# 🧩 Plugin & App Injection Guide

How to build a plugin and inject an application — native or web — into the Dynamic
Island.

---

## 📑 Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [The `IslandPlugin` Protocol](#2-the-islandplugin-protocol)
3. [Required Members You Cannot Skip](#3-required-members-you-cannot-skip)
4. [Web App Injection](#4-web-app-injection)
5. [The UI Component Library](#5-the-ui-component-library)
6. [The Icon Pipeline](#6-the-icon-pipeline)
7. [Per-Plugin Sound](#7-per-plugin-sound)
8. [Notifications](#8-notifications)
9. [Dynamic Sizing](#9-dynamic-sizing)
10. [Tutorial: Adding a Web App](#10-tutorial-adding-a-web-app)
11. [Testing a Plugin](#11-testing-a-plugin)

---

## 1. Architecture Overview

```mermaid
flowchart TD
    subgraph Core["🏝️ Core"]
        WindowCtrl["WindowController<br/>NSPanel"]
        AppState["AppState<br/>width & height"]
        TabHost["IslandTabContentView"]
    end

    subgraph Mgrs["⚙️ Coordinators"]
        PluginMgr["PluginManager"]
        IconMgr["PluginIconManager"]
        NotifMgr["PluginNotificationManager"]
        SoundMgr["SoundManager"]
    end

    subgraph Plugins["🧩 Registered Plugins"]
        WebApp["WebAppPlugin<br/>any web app, from a descriptor"]
        Custom["Your plugin"]
    end

    WebApp -->|"implements"| PluginMgr
    Custom -->|"implements"| PluginMgr
    PluginMgr -->|"registers tabs"| AppState
    AppState -->|"renders active"| TabHost
    Custom -->|"makeContentView"| TabHost

    Plugins -->|"alerts"| NotifMgr
    NotifMgr -->|"balloons compact pill"| Core
    NotifMgr -->|"system banner"| macOS["UNUserNotificationCenter"]

    Plugins -->|"logos"| IconMgr
    Plugins -->|"cues"| SoundMgr
```

### Key principles

- **Standardized components.** Every plugin shares the same Liquid Glass aesthetic,
  typography, and button feedback.
- **Dynamic sizing.** Plugins declare their viewport; the island resizes to fit.
- **Automatic sound settings.** Registering a plugin produces working audio settings
  with zero UI code.
- **Zero tab duplication.** All shells render tab content through one shared view.

---

## 2. The `IslandPlugin` Protocol

Declared in `Sources/DynamicIsland/Plugins/IslandPlugin.swift`.

```swift
public protocol IslandPlugin: AnyObject, Identifiable {
    var id: String { get }                       // reverse-DNS, e.g. "com.dynamicisland.plugin.whatsapp"
    var name: String { get }                     // tab pill label
    var icon: String { get }                     // SF Symbol fallback

    var subtitle: String { get }                 // default ""
    var author: String { get }                   // default "Dynamic Island Community"
    var version: String { get }                  // default "1.0.0"
    var capabilities: IslandPluginCapabilities { get }   // default []
    var isEnabled: Bool { get set }              // user toggle

    var preferredContentHeight: CGFloat { get } // default 400
    var preferredIslandWidth: CGFloat? { get }   // default 740
    var tabBadge: String? { get }                // default nil

    var defaultSoundProfile: IslandPluginSoundProfile { get }  // default .standard

    func onRegister()
    func onEnable()
    func onDisable()
    func onTabSelected()
    func onTabDeselected()

    @ViewBuilder func makeContentView() -> AnyView

    func compactItems() -> [CompactEarItem]        // default [] — LEFT ear, may carry text
    func compactStatusToken() -> RightEarToken?  // default nil — RIGHT ear, graphical only
    func makeSettingsView() -> AnyView?          // default nil
    func makeIconView(size: CGFloat) -> AnyView? // default nil
}
```

### Capabilities

| Flag | Meaning |
| :--- | :--- |
| `.variableHeight` | Supports a custom expanded height |
| `.compactAccessory` | Supplies a closed-notch accessory |
| `.customSettings` | Provides a card in **Preferences → Plugins** |
| `.deepLinking` | Accepts `dynamicisland://plugin/<id>` |

### Lifecycle

`onRegister` / `onEnable` / `onDisable` are called by the registry. `onTabSelected`
and `onTabDeselected` are dispatched centrally from `AppState.activeTab.didSet`, so
**no assignment site can forget them** — including deep links, the timer path, and
notification taps.

---

## 3. Required Members You Cannot Skip

Two members are compile-time obligations rather than suggestions:

**`defaultSoundProfile`** — declaring it on the protocol means a plugin cannot be
registered without stating which cues it uses. The Settings UI generates controls
from the plugin registry, so registering a plugin with working audio settings
requires **no UI code at all**.

**`compactStatusToken()`** — returns a `RightEarToken`, never a view. Because the
right ear accepts only a closed token enum where no case except `.battery` can carry
a string, a plugin **structurally cannot** put text there. If your plugin needs
readable text in the notch, return a `CompactEarItem` from `compactItems()` instead.

**`compactItems()`** — returns *data*, not a view. The left ear measures and scrolls
its contents, so a pre-built `AnyView` cannot be placed by a marquee. Each item
declares whether it is `.resident` (holds a fixed slot, never scrolled away) or
`.transient` (enters at the left, travels right, retires once clear). Geometry lives
in `CompactEarMarquee`, a pure function of elapsed time — the same code the tests
exercise.

> [!TIP]
> These are level-2 enforcement in practice: omitting either one fails
> compilation. See [`../AGENTS.md`](../AGENTS.md) §1.

---

## 4. Web App Injection

`IslandWebPlugin.swift` provides a reusable `WKWebView` host.

> [!TIP]
> To add a site for **yourself**, you do not need this file — see
> [§10 Tutorial](#10-tutorial-adding-a-web-app). The controller below is the
> substrate `WebAppPlugin` is built on.

### `IslandWebConfiguration`

```swift
public struct IslandWebConfiguration {
    public var initialURL: URL
    public var customUserAgent: String   // desktop Safari UA by default
    public var zoomFactor: Double        // default 0.88
    public var customCSS: String?
    public var customJS: String?
    public var allowsBackForwardNavigationGestures: Bool  // default true
}
```

### `IslandWebController`

`NSObject`, `ObservableObject`, `WKNavigationDelegate`, `WKUIDelegate`, and
`WKScriptMessageHandler`.

| Member | Purpose |
| :--- | :--- |
| `webView` | The managed `WKWebView` |
| `title`, `isLoading`, `currentURL`, `estimatedProgress` | Observed page state |
| `canGoBack` / `canGoForward` | Navigation availability |
| `onNotificationReceived` | `(title, body, icon) -> Void` — HTML5 notifications |
| `zoomIn()` / `zoomOut()` / `setZoom(_:)` / `resetZoom()` | Interactive zoom (persisted per host) |

> [!NOTE]
> `pageTitleUnreadCount` and `onTitleNotificationTriggered` were **removed**. They
> parsed an unread count out of the page title (`(3) Alice: hi`) and raised a native
> macOS banner from it. The title is page-controlled content, so for a web app the
> user typed by URL that was a fabricated unread count and a page able to raise
> system notifications it had no business raising. Alerts now fire only on a real
> `new Notification()` from the page.

### What it handles for you

- **Persistent storage** via `WKWebsiteDataStore.default()` — cookies and
  `localStorage` survive relaunch, so sessions stay logged in.
- **Desktop user agent** so web apps serve their desktop layout instead of
  redirecting to mobile.
- **External link routing** — `target="_blank"` and pop-ups open in the user's
  default browser rather than inside the notch.
- **Zoom controls** for chat interfaces that are cramped in a narrow viewport.

### Rendering it

```swift
IslandCardView(cornerRadius: 10) {
    IslandWebViewHost(controller: webController)
}
.frame(maxHeight: .infinity)
```

---

## 5. The UI Component Library

`Views/Components/IslandComponents.swift` — shared by built-in tabs and plugins so
everything looks and feels identical.

### `IslandHeaderView`

Leading icon/logo, title, subtitle, optional status badge, and trailing actions.

```swift
IslandHeaderView(
    iconView: PluginIconManager.shared.iconView(for: self, size: 18),
    title: "WhatsApp",
    subtitle: "Connected",
    statusBadge: "3 new",
    statusColor: .blue
) {
    HStack(spacing: 5) {
        IslandButton(nil, icon: "arrow.clockwise", variant: .ghost, size: .small) {
            webController.reload()
        }
    }
}
```

### `IslandCardView`

The standard container: `Color.white.opacity(0.06)` with a continuous corner radius
and a specular border.

```swift
IslandCardView(cornerRadius: 10) { /* content */ }
```

### `IslandButton`

```swift
IslandButton("Log Out", icon: "trash", variant: .danger, size: .small) {
    webController.clearCache()
}
```

- **Variants:** `.primary`, `.secondary`, `.ghost`, `.tinted(Color)`, `.danger`
- **Sizes:** `.small`, `.regular`, `.large`

### `IslandSearchField` & `IslandEmptyStateView`

```swift
IslandSearchField(text: $query, placeholder: "Search conversations...")

IslandEmptyStateView(
    icon: "wifi.slash",
    title: "No Connection",
    subtitle: "Reconnecting to server..."
)
```

Also available: `IslandDivider`.

---

## 6. The Icon Pipeline

`PluginIconManager` resolves authentic app logos through a multi-tier hierarchy, so
plugins usually need no icon work at all.

| # | Tier | Location |
| :--- | :--- | :--- |
| 1 | In-memory cache | `NSCache<NSString, NSImage>` |
| 2 | Persistent user cache | `~/Library/Application Support/DynamicIsland/PluginIcons/<key>.png` |
| 3 | App bundle resources | `DynamicIsland.app/Contents/Resources/PluginIcons/<key>.png` |
| 4 | Development directory | `Resources/PluginIcons/<key>.png` |
| 5 | Installed macOS app | `NSWorkspace` lookup by bundle id |
| 6 | Fallback | `makeIconView(size:)`, else the SF Symbol |

Each tier is tried against several **candidate keys** derived from the plugin id:
the full id, its lowercase form, the last dot-separated component, and that
component lowercased. So `com.dynamicisland.plugin.messenger` will also match
`messenger.png` — which is why the bundled file is named `messenger.png` rather than
the full reverse-DNS id.

### Bundling an icon

1. Place a 512×512 PNG at `Resources/PluginIcons/<name>.png`.
2. `./scripts/build_app.sh` copies everything in that directory into
   `Contents/Resources/PluginIcons/`.

### Downloading one at runtime

```swift
PluginIconManager.shared.downloadAndCacheIcon(from: logoURL, for: plugin.id) { image in
    // cached to disk and memory
}
```

### Using it

```swift
PluginIconManager.shared.iconView(for: self, size: 18)   // for a plugin
PluginIconManager.shared.iconView(for: .plugin(id: "com.example.app"), size: 18)  // for a tab
```

---

## 7. Per-Plugin Sound

Every plugin is sound-configurable with no extra UI code, because the Settings pane
iterates the registry and builds controls from `IslandPluginSoundEvent.allCases`.

### Declaring defaults

```swift
public var defaultSoundProfile: IslandPluginSoundProfile {
    IslandPluginSoundProfile(
        isEnabled: true,
        volume: 0.9,
        alertCue: .ping,
        interactionCue: .pop
    )
}
```

### Playing a cue

```swift
SoundManager.shared.playPluginCue(.alert, pluginId: plugin.id)
SoundManager.shared.playPluginCue(.interaction, pluginId: plugin.id)
```

> [!IMPORTANT]
> **Always go through `playPluginCue(_:pluginId:)`.** It is the sole entry point that
> honours the global master switch, the per-plugin mute, and
> `globalVolume × pluginVolume`. Never call `NSSound` directly for plugin feedback —
> that bypasses every user preference.

The `pluginId` is required rather than inferred so notification audio is always
attributed to the plugin that raised it.

### Resolution and overrides

`soundProfile(forPlugin:)` is the single resolution point: an override for the id
wins, otherwise the plugin's `defaultSoundProfile` is used. Overrides are stored
**sparsely**, so shipping a new plugin — or a new default cue — needs no migration.

- `updatePluginSound(_:_:)` and `resetPluginSound(_:)` are the only mutators.
- `IslandSoundCue` is the curated cue set (`pop`, `tink`, `ping`, `glass`, `hero`,
  …), each with a display name and an SF Symbol for the picker.

Alerts route here from `PluginNotificationManager`; interactions route from
`AppState.activeTab.didSet`, so a plugin's cue plays on tab selection even if the
user disabled the generic tab-switch sound.

---

## 8. Notifications

`PluginNotificationManager` is the shared pipeline for both web and native plugins.

### Dispatching

```swift
PluginNotificationManager.shared.post(
    pluginId: "com.dynamicisland.plugin.whatsapp",
    title: "Sarah",
    body: "Are you free for lunch today?",
    subtitle: "WhatsApp",
    soundEnabled: true
)
```

### What happens

1. The plugin's configured **alert cue** plays via `playPluginCue(.alert, pluginId:)`.
2. The in-notch live alert appears (below).
3. A native macOS notification is posted via `UNUserNotificationCenter`. Clicking
   that banner routes straight to the plugin's tab.

### The in-notch alert pill

While the island is closed, an alert shows the app icon and sender on the **left**
ear and the sender's **icon only** on the **right** ear — never the message body,
per the right-ear contract. It auto-dismisses after **4.5 seconds**, and tapping it
opens the island directly into that plugin's tab.

> [!NOTE]
> The closed notch is a fixed-size window, so the alert does not balloon it. See
> [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.

### The HTML5 web notification bridge

`IslandWebController` injects a polyfill at `.atDocumentStart` that hooks
`window.Notification` and `Notification.requestPermission()`. A page calling
`new Notification(title, options)` is serialized across
`WKScriptMessageHandler` (`islandNotification`) into native Swift and dispatched
through the same pipeline.

### Title-flashing detection

**Not available, and deliberately so.** Chat apps often update the document title
instead of firing a notification — e.g. `(3) Alice: Hey there!` — so a title observer
(`webView.title`) plus an unread-count parse was how the seeded Messenger app used to
raise alerts. It was removed.

The title is page-controlled content, so a web app added by URL could choose the text of
a banner that appeared to come from the island, and fabricate an unread count it had no
basis for. Surface presence through `compactStatusToken()` instead; it accepts only
`RightEarToken` values and therefore cannot carry text.

**The cost is real:** Messenger does not call `new Notification()` for chats, so the
seeded app is silent under the bridge alone. A banner now means the site explicitly
asked for one. An alert also never quotes the page — `WebAppPlugin.displayNotice(from:appName:)`
replaces the page's `title` and `body` with the user's own app name and a fixed string,
because a banner borrowing the island's identity must not carry the page's words.

### External triggering

`PluginNotificationManager` listens on the distributed notification
`com.dynamicisland.pluginNotification`, so other tools and scripts can raise
notifications too:

```bash
xcrun swift -e '
import Foundation
let info: [String: Any] = [
    "title": "Sarah Jenkins",
    "body": "Hey! Testing the Dynamic Island notification banner!",
    "pluginId": "com.dynamicisland.plugin.messenger"
]
DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("com.dynamicisland.pluginNotification"),
    object: nil, userInfo: info, deliverImmediately: true
)
'
```

---

## 9. Dynamic Sizing

Your plugin's viewport is declared, not hard-coded:

```swift
public var preferredContentHeight: CGFloat { 400.0 }   // integrated apps
public var preferredIslandWidth: CGFloat? { 740.0 }     // integrated apps
```

Both axes morph with spring physics when switching between tool and app tabs. The
panel is sized to accommodate the largest of these — see
[`ARCHITECTURE.md`](ARCHITECTURE.md) §3 for the full geometry.

### The user can override it

On a plugin tab the island is **resizable**: dragging the bottom-right corner changes
width and height, and the size is remembered per plugin.
Nothing is drawn at that corner — the diagonal cursor that appears there on hover is
the whole affordance, the same way AppKit signals a resizable window.
During the drag the island tracks the pointer exactly, with no spring; the spring
returns as soon as the drag ends.
The whole island surface resizes and your content view follows the new frame, so a
web app gets the larger viewport rather than being letterboxed inside a fixed one.

A plugin that declares no size, or that the user never resizes, is unaffected — the
stored size is **sparse**, so a new plugin needs no migration.
`PluginsSettingsTab` shows the current size for each installed app and offers a
reset, so a user who has dragged the island into an unusable size can recover
without editing preferences.

This is a property of the *presentation*, not of your plugin: you declare a
starting point, the user owns the final size.
A plugin does not need to do anything to support it.

> [!NOTE]
> The island's resize affordance is a glow traced along the bottom-right corner's
> curve, not a button.
> It is drawn *outside* the island's own shape, so a plugin does not need to leave
> room for it — but a plugin that hosts a **native** view should know that such a view
> draws above the island's SwiftUI overlays: `NSViewRepresentable` composites above
> SwiftUI, and neither ZStack order nor `.overlay` can change that.
> The glow sits on the island's edge, outside the content's frame, so nothing has to
> be drawn over anything.
> It accepts input only within a 64pt square on that corner, so it never shadows the
> island's own controls.

---

## 10. Tutorial: Adding a Web App

**You do not need to write a plugin to add a web app.** Web apps are data: a
`WebAppDescriptor` (id, name, url) persisted in `UserDefaults` and turned into a
`WebAppPlugin` by `WebAppRegistry`. `Preferences → Plugins → Add Web App` does this
for you, and everything below — tab, web session, zoom persistence, ear accessory,
sound settings, add/remove — already works for the result.

Adding a site takes about ten seconds:

1. Open **Preferences → Plugins**.
2. Paste the address into **Web address**. A missing `https://` is added for you.
3. Press **Add**.

The URL is validated by `WebAppDescriptor.parse(_:)`, which returns one of
`empty` / `notHTTP` / `noHost` so a bad address is rejected with a specific reason
instead of producing a tab that loads nothing.

### Step 1 — Understand what you got

Each descriptor produces one `WebAppPlugin`:

| Concern | Owner |
| :--- | :--- |
| Identity | `WebAppDescriptor.identifier(for:)` — derived from the **host alone**, so editing a path never orphans the tab, icon, or saved sound |
| Label | Your `name`, or `displayName(for:)` which strips `www.`/`web.` and the public suffix (`web.whatsapp.com` → "Whatsapp") |
| Preset | `DefaultWebAppConfig.loadFromBundle()` — adding one is a no-op if already installed, so the button is idempotent |
| Persistence | `WebAppStore`, seeded once behind a flag so deleting a seeded app does not resurrect it |
| Icon | `FaviconFetcher`, which derives the site's favicon URL from `url` and caches it on first registration |

### Step 2 — Ship an icon (optional)

**Usually unnecessary.** A web app's tab icon is fetched from the site itself —
`/favicon.ico`, then `/apple-touch-icon.png` — and cached to disk on first
registration, so a shipped PNG is only worth adding for an app whose real favicon is
wrong or missing. If you do ship one, place `<lastHostComponent>.png` at
`Resources/PluginIcons/`: the candidate key is the last component of the id, so
`com.dynamicisland.webapp.web.slack.com` matches `slack.png`. A bundled icon also
*suppresses* the fetch, so shipping one pins the icon rather than decorating it.

With no icon available from either source, the tab shows a neutral globe glyph rather
than an invented brand mark.

### Step 3 — Seed a new built-in app

Append an entry to `Resources/DefaultWebApps.json`:

```json
{
  "id": "com.dynamicisland.webapp.web.slack.com",
  "name": "Slack",
  "url": "https://app.slack.com/client",
  "isEnabled": true
}
```

The file uses the same shape as the persisted descriptor, so the decoder that reads it
is the decoder that reads `UserDefaults`. Two things it is not:

- **It is read on first launch only.** A launch that finds the seed flag already set
  does not re-read it, because that flag is what makes deletion stick. Shipping a new
  default later therefore reaches *new installs only*; an existing user never
  receives it automatically, and can add it from `Preferences → Plugins → Presets`.
- **Unknown keys are rejected, not ignored.** A misspelled field drops that one entry
  instead of half-applying it, so a typo fails a test rather than silently shipping an
  app with a missing field.

The id is written down twice — here, and as `WebAppLegacyID.messenger` for the
original plugin — and a test asserts the two agree, because a new install seeded
under an unexpected id would miss its bundled icon and any restored sound override.

That is the whole integration. **If you need behaviour that cannot be derived from
the descriptor — a custom header, a site-specific side panel — it does not belong in
a `WebAppPlugin` subclass.** Write a real `IslandPlugin` instead and register it;
per-app web views are one use of the protocol, not its only one.

### Step 4 — Build and launch

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_app.sh && \
pkill -f DynamicIsland; sleep 0.4; open /Applications/DynamicIsland.app
```

---

## 11. Testing a Plugin

**In-app** — **Preferences → Plugins → your plugin → Test Notification**. The notch
shows the alert pill immediately.

**From Terminal** — post a distributed notification (see §8).

**Checklist for a new plugin:**

- [ ] Compiles without overriding `defaultSoundProfile` or `compactStatusToken()`.
- [ ] The tab pill appears and reorders with the user's custom order.
- [ ] The pill shows `displayName`, not a reverse-DNS id.
- [ ] `makeContentView()` fills the declared viewport and the island resizes smoothly.
- [ ] `compactItems()` shows in the left ear; `compactStatusToken()` shows an icon in
      the right ear — and no text appears there.
- [ ] Sound settings appear under **Preferences → Sound Effects** with no extra code.
- [ ] A test notification shows the alert pill and plays the plugin's alert cue.
- [ ] Two simultaneous alerts are both visible (the list is bounded, not a single slot).
- [ ] The web session survives a relaunch (if web-based).
