# 📚 Documentation Index

Feature and architecture documentation for **Dynamic Island for macOS**. Start with
[`../README.md`](../README.md) (what it is, how to build) and
[`../AGENTS.md`](../AGENTS.md) (rules for changing it).

Each fact below has exactly one home. If you need something not listed here, it is
either in the code or in the file that owns it.

| Doc | Owns |
| :--- | :--- |
| [`FEATURES.md`](FEATURES.md) | The user-facing feature reference: the closed notch, the opened island, every tab, the drop shelf, system HUD, every Preferences pane, and the full shortcut & gesture list |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | How it is built: panel geometry, hit-testing, notch sealing & shapes, materials, the animation system, docking modes, focus handling, the framework inventory, the settings window |
| [`MEDIA.md`](MEDIA.md) | The media subsystem: NowPlaying detection, the private `MediaRemote` binding, the browser and desktop-app registries, playback control and app ownership, and the platform gotchas behind them |
| [`PLUGINS.md`](PLUGINS.md) | The plugin system: the `IslandPlugin` protocol, web-app host, icon pipeline, notifications, per-plugin sound, and a worked tutorial |
| [`TESTING.md`](TESTING.md) | The test target: how to run it, the two-toolchain split, what may live in it, and the headless traps |

## Conventions

- Numbers reflect the current code. Where a value is likely to change, the doc names
  the file that owns it rather than repeating the number in several places.
- Gotchas are recorded with the reason they exist, so nobody "cleans them up".
- Anything describing how the app *currently* works lives here, not in `AGENTS.md`.
  See the documentation rules in [`../AGENTS.md`](../AGENTS.md) §5.
