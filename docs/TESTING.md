# 🧪 Testing

The test target is small on purpose. This doc explains what may live in it and, more
importantly, why most of the app cannot.

---

## 📑 Table of Contents

1. [Running the Tests](#1-running-the-tests)
2. [The Two Toolchains](#2-the-two-toolchains)
3. [Pure Logic Only](#3-pure-logic-only)
4. [Headless Traps](#4-headless-traps)
5. [Designing for Testability](#5-designing-for-testability)
6. [Existing Suites](#6-existing-suites)

---

## 1. Running the Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Current state: **11 tests across 2 suites**, all passing, completing in well under a
second.

---

## 2. The Two Toolchains

| | Shipping app | Tests |
| :--- | :--- | :--- |
| **Manifest** | none — `scripts/build_app.sh` | `Package.swift` |
| **Toolchain** | Command Line Tools | **Xcode** |
| **Command** | `./scripts/build_app.sh` | `swift test` |
| **Produces** | `/Applications/DynamicIsland.app` | test results |

Two consequences that are easy to trip over:

> [!WARNING]
> **The Command Line Tools cannot run the tests.** `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift test` fails to even *load* the manifest (`Undefined symbols … PackageDescription`).

> [!IMPORTANT]
> **This is also why `Package.swift` pins `swiftLanguageMode(.v5)`.** Under the
> default Swift 6 language mode, every `static let shared` singleton in the app is
> a hard `#MutableGlobalVariable` error and the package would not build at all. The
> singletons are the deliberate architecture (see
> [`../AGENTS.md`](../AGENTS.md) §2.1), so the language mode is relaxed instead —
> which also matches what the `swiftc` build path actually uses, so the two paths
> cannot disagree about what compiles.

---

## 3. Pure Logic Only

The test target has **no window server, no app launch, and no `UserDefaults` sandbox
you should rely on**.

Only types free of AppKit/SwiftUI runtime dependencies belong here. A test that needs
a running app does not belong in this target — it belongs behind a manual checklist,
or the logic should be extracted until it *is* pure.

---

## 4. Headless Traps

These resolve through a chain that reaches a `WKWebView`. In a headless `swift test`
process they trap with **SIGTRAP** (reported by SwiftPM as `exited with unexpected
signal code 5`) — or, worse, silently exercise nothing:

| Trap | Why |
| :--- | :--- |
| `IslandTab.allCases` | Not a pure enumeration. Resolves `SettingsManager.orderedTabs(from: defaultTabs)` → `MessengerPlugin.shared.isEnabled` → a `WKWebView`. Needs a window server. |
| `PluginManager.shared` / `PluginIconManager.shared` | Same chain: `defaultTabs` walks `activePlugins`. |
| `AppState.shared` | Reaches `SettingsManager` and the plugin registry. |
| `SoundManager.shared.play(_:)` | Reaches `SettingsManager` and dispatches `NSSound`. |
| Any `SettingsManager.shared` | `UserDefaults` — works, but state leaks between tests. Prefer passing values in. |

---

## 5. Designing for Testability

The trap above is a **design signal**, not just a testing inconvenience. A rule that
is worth guarding usually became untestable for one reason: it read a global
internally instead of accepting its inputs.

The fix is the same code the guard needs anyway — a pure policy function:

```swift
// Untestable: the order comes from a global that reaches a WKWebView.
static func reorderedTabs(dragging: IslandTab, from: [IslandTab], to: Int) -> [IslandTab] {
    let full = IslandTab.allCases        // ← trap
    ...
}

// Testable: the order is data.
static func reorderedTabs(
    dragging: IslandTab, from: [IslandTab], to: Int,
    visibleOnly: Bool, fullOrder: [IslandTab]
) -> [IslandTab]
```

Making it testable forced the signature to be honest about its real inputs, and that
in turn made the guard itself simpler. **The guard and the test surface are the same
code.**

`onDragChanged` takes `fullOrder` as an `@autoclosure` default so the hot path
resolves it once per drag start rather than on every `onChanged` frame — production
keeps the ergonomic default, tests inject a literal:

```swift
coordinator.onDragChanged(
    tab: .media, translation: 40, orderedTabs: fullOrder,
    slotStep: 90, fullOrder: fullOrder        // explicit, headless-safe
)
```

### Conventions for new tests

- Pass `fullOrder:` (or the equivalent) **explicitly**. Never rely on the default
  that reads a global.
- Prefer a `private let` literal like `fullOrder` at file scope over constructing
  arrays inline in every test.
- Comment *why* a test exists, and name the defect it guards. `TabDragCoordinatorTests`
  cites the commit (`17d114e`) so the next person knows whether the test is still
  load-bearing.
- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`) — this is what
  the existing suites use.

---

## 6. Existing Suites

### `TabDragCoordinatorTests` — *"Tab bar gesture state machine"*

| Test | Guards |
| :--- | :--- |
| A clean click with no pointer travel leaves the coordinator neutral | Selection was owned by `DragGesture.onEnded`, which reports nothing on a still click |
| A lost drag release no longer blocks every other tab | A pinned `draggingTab` made every other pill fail both guards — the bar wedged |
| A release for a dead drag is cleaned up rather than ignored | `onDragEnded` used to return early and leave state pinned |
| Every tab's gesture ends in a neutral state | Exhaustive: no tab can wedge the bar |
| Jitter under the tap slop is tracked exactly, not snapped | Pins both sides of the `tapSlop` boundary |
| The drag only latches onto the pill it started on | A second pill must not steal a live drag |

### `TabReorderTests` — *"Tab reorder order computation"*

| Test | Guards |
| :--- | :--- |
| Dragging the first tab to the end reverses the visible bar | Basic correctness |
| Target index is clamped | An over-drag cannot corrupt the order |
| A reorder is a pure permutation | No tab is ever lost or duplicated |
| Reordering the visible bar leaves hidden tabs in their original slots | Reordering what the user can see must not relocate what they cannot |
| `visibleOnly: false` returns just the moved list, unfiltered | The non-weaving path |
