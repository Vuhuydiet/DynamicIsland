# Dynamic Island for macOS

A native macOS menu-bar app that wraps around the MacBook hardware display notch — or floats as an iPhone-style capsule on external displays — turning the top of the screen into an interactive hub for media, timers, clipboard, notes, file parking, and chat apps.

---

## ✨ Highlights

- **Adaptive notch & Liquid Glass** — the physical notch is measured at runtime and the island seals around it with tangent-continuous bezier flares, so there is no visible gap.
- **System-wide media hub** — detects and controls playback across browsers, music apps, and local players.
- **Drag-to-notch file shelf** — park files at the top of the screen and drag them back out.
- **Timers & stopwatch** — live countdown in the closed notch, laps, and completion alerts.
- **Clipboard history & quick notes** — automatic capture plus a persistent scratchpad.
- **Live system HUD** — CPU, RAM, and disk usage inline in the header.
- **Extensible app plugins** — inject web or native apps (Messenger ships built in) with per-plugin sound, icons, and notifications.

📖 Full feature documentation lives in [`docs/`](docs/), including the complete
[shortcut and gesture reference](docs/FEATURES.md#10-shortcuts--gestures).

---

## 📋 Requirements

| | |
| :--- | :--- |
| **OS** | macOS 14.0+ (Apple Silicon or Intel) |
| **Toolchain** | Xcode command line tools — `xcode-select --install` |
| **Third-party dependencies** | **None.** No package manager, no CocoaPods, no Carthage. |

Everything the app needs is a system framework; the inventory and what each one is
used for is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 🛠️ Build & Run

Build, install, and relaunch in one step:

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/build_app.sh && \
pkill -f DynamicIsland || true && \
sleep 0.4 && \
open /Applications/DynamicIsland.app
```

The script compiles the sources, assembles the `.app` bundle, generates `Info.plist`, copies the app icon and plugin icons into `Contents/Resources/`, and installs the result to **`/Applications/DynamicIsland.app`**. Always run and test the app from that path.

> [!IMPORTANT]
> **Keep only one copy of the app on disk.** A second copy is the *same bundle id*, and Launch Services does not guarantee which one it launches — so a change can appear to have no effect because a stale build won. The build script installs to `/Applications` and warns when it finds another copy elsewhere; remove that one rather than leaving it to chance. If `/Applications` is not writable, the script fails and tells you to re-run with `sudo` instead of quietly installing somewhere else.

> [!IMPORTANT]
> **Always prefix build commands with `DEVELOPER_DIR`.** Without it, `swiftc` can block on an interactive Xcode license prompt on machines where the GUI license was never accepted. The build script sets this internally, but any manual `swiftc`/`xcodebuild` invocation must set it too.

---

## 🧪 Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

The test target is deliberately narrow: **pure logic only**, running headless. What
that excludes, and the specific traps, are in [`docs/TESTING.md`](docs/TESTING.md).

Current suites: `CompactEarMarqueeTests`, `DefaultWebAppConfigTests`, `DesktopMediaAppTests`,
`DockingModeTests`, `FaviconCandidateTests`, `IslandEditActionTests`, `MediaBrowserTests`,
`MediaManagerOwnershipTests`, `MediaSourceClassificationTests`, `RightEarTokenTests`,
`SoundManagerMappingTests`, `TabDragCoordinatorTests`, `WebAppNoticeTests`,
`WebAppTabMigrationTests`, `WebAppURLTests`. (`TabDragCoordinatorTests` and
`TabReorderTests` are two suites in one file —
`Tests/DynamicIslandTests/TabDragCoordinatorTests.swift`.)

---

## 📂 Project Structure

```
dynamic-island/
├── Package.swift                    # Test-only manifest (not the shipping build)
├── scripts/
│   ├── build_app.sh                 # Compile + bundle + install
│   ├── generate_icon.swift          # Icon generator
│   └── AppIcon.icns                 # 1024×1024 app icon
├── Resources/PluginIcons/           # Bundled plugin logos
├── Tests/DynamicIslandTests/        # Headless pure-logic tests
├── docs/                            # Feature & architecture documentation
└── Sources/DynamicIsland/
    ├── App/                         # App delegate, panels, sound, focus
    ├── Models/                      # Managers & persisted state (singletons)
    ├── Utilities/                   # Typography, notification-token registrar
    ├── Views/
    │   ├── Compact/                 # Closed-notch ears
    │   ├── Expanded/                # Opened island + tool views
    │   │   └── Settings/            # One file per Preferences pane
    │   ├── Components/              # Shapes, springs, shared components
    │   └── IslandContainerView.swift
    ├── Plugins/                     # Plugin protocol, registry, web host
    │   └── Builtin/                 # Messenger plugin + its views
    └── main.swift
```

---

## 📄 License

MIT — free for personal and commercial use.
