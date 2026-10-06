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

Current state: **173 tests** — 84 XCTest plus 89 swift-testing, all passing, completing in
well under a second.

> [!NOTE]
> **A `#if DEBUG` assertion is not a test.** `build_app.sh` invokes `swiftc` with no
> `-D DEBUG` and no `-swift-version`, so the compiler defaults to Swift 5 mode and
> every `#if DEBUG` block in the shipping app is compiled out entirely. Guards that
> matter — the right-ear text ban, the edit-shortcut collision check — therefore live
> here, where a regression fails a build that anyone can see.

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
> [`DESIGN.md`](DESIGN.md) §2), so the language mode is relaxed instead —
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
| `IslandTab.allCases` | Not a pure enumeration. Resolves `SettingsManager.orderedTabs(from: defaultTabs)` → `PluginManager.shared.activePlugins` → one `WKWebView` per web app. Needs a window server. |
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

### `WebAppURLTests` — *"Web app URL validation"*

| Test | Guards |
| :--- | :--- |
| A bare host is upgraded to `https://` | `messenger.com` is what a user actually types |
| An explicit scheme is preserved, and whitespace trimmed | Typing is not rewritten under the user |
| Empty input is `.empty`, not a generic failure | Each rejection has its own user-facing reason |
| A non-http scheme is `.notHTTP` | A web view cannot load `ftp://` |
| A scheme is never double-prefixed | A blind `https://` prefix would make `https://ftp://x`, which parses as host `ftp` and loads the wrong thing |
| Hostless input is `.noHost` | Produces a specific message, not a blank tab |
| Every rejection carries a reason; success carries none | The UI cannot render an empty error |
| Identity is derived from the **host alone** | Editing a path must not orphan the saved tab, icon, or sound |
| Identity is stable and unique per host, namespaced `webapp.` | Two apps must never collide on one id |
| The seeded app keeps its **legacy** id | The shipped `messenger.png` and persisted sound overrides are keyed by it |
| Display names strip `www.`/`web.` and the public suffix | `web.whatsapp.com` reads as "Whatsapp", not "Web Whatsapp Com" |
| A display name is never empty | A blank tab label is a silent failure |

### `IslandSizeTests` — *"Island size clamping and drag geometry"*

The pure core behind the user-resizable island. Nothing here touches AppKit, so the
clamp and the drag arithmetic are both the enforcement and the test surface.

| Test | Guards |
| :--- | :--- |
| Width and content height are clamped at both ends | A drag cannot produce an island the user cannot get out of |
| A size already inside the bounds is unchanged, and clamping twice changes nothing | A stored size read on every launch must not drift |
| A `NaN` dimension is not usable | `min(max(.nan, lo), hi)` **propagates** `NaN` — the whole reason `isUsable` is a separate function from `clamp` |
| An infinite dimension is not usable | Same failure, reached by a different route |
| A zero or negative dimension is not usable | A 0pt or negative width draws nothing at all |
| Clamping an unusable size does not make it usable | Proves the guard is load-bearing, not decorative |
| A zero translation leaves the size at the start | A click on the grip is not a resize |
| Dragging right/down grows and left/up shrinks | A y-axis sign error is invisible until the island is inverted |
| A drag re-derived from its start 60 times lands where one total delta does | The drift guard: an accumulating `+=` would make the result depend on frame count |
| A drag past either bound is clamped | |
| A size survives a JSON round trip | A `Codable` type that fails to decode is silently ignored on read, so the size would revert every launch |

> [!NOTE]
> **The drift test compares with a tolerance, and the reason is arithmetic, not
> laxity.** Summing `3.0` sixty times in binary floating point is not exactly `180.0`
> — measured, it lands on `179.99999999999997`. An accumulating implementation would
> diverge by *whole points* after a dropped frame, so a `0.001` tolerance separates
> the two failure modes completely. Asserting exact equality here would have failed
> for a correct implementation.

### `CompactEarMarqueeTests` — *"Left ear marquee geometry"*

| Test | Guards |
| :--- | :--- |
| Travel is zero before entry, and for a negative elapsed | A clock change must not project an item off-screen |
| Travel is linear in elapsed time | The drift guard: an accumulating `offset += dt` would depend on frame count |
| A dropped frame does not shift the strip | A 2.5s stall arrives as one delta; the position must be identical either way |
| The first item enters from the left edge | The strip starts off-screen, not inside the ear |
| Positions are non-decreasing | The view lays items out left to right and relies on this |
| Simultaneous items are exactly one slot apart | A burst stays legible instead of stacking |
| A later item trails by travel distance, or one slot if closer | Overlap rule, and the natural spacing it overrides |
| A future entry time is treated as just arrived | A bad timestamp degrades safely |
| An item retires only once fully clear of the ear | Not early (popped mid-read), not late (stranded) |
| An item is not visible before it exists | Retired items must not flash back in |
| A countdown drops its digits only when the strip overflows | Content degrades; the 56pt ear never grows |

### `WebAppTabMigrationTests` — *"Legacy tab id migration"*

| Test | Guards |
| :--- | :--- |
| `"Messenger"` maps to the seeded descriptor id | Both `customTabOrder` and `hiddenTabs` store the raw string |
| Built-in tool ids and unknown plugin ids pass through | The mapping is narrow, not a rewrite |
| The mapping is idempotent | It runs on **every read**, not once at launch |
| A legacy entry keeps its position in the stored order | An upgrading user must not lose their tab order |
| No entry is dropped by the migration | Silent data loss is the failure being guarded |
| A hidden Messenger stays hidden | A tab the user hid must not reappear |
| Migration cannot resurrect another hidden tab | The rewrite is a mapping, not a reset |
| `init?(rawValue:)` builds `.plugin(id:)` from a legacy value | Persisted and deep-linked ids take this path |

### `DockingModeTests` — *"Docking mode policy"*

| Test | Guards |
| :--- | :--- |
| An explicit preference always wins over the detected hardware | `.notch` on a notchless screen and `.floating` on a notched one both work |
| Auto follows the hardware in both directions | The default path |
| Every style resolves, for both hardware states | Totality: a new `NotchStyle` cannot be added without deciding its answer |

### `RightEarTokenTests` — *"Right ear: text-free token contract"*

| Test | Guards |
| :--- | :--- |
| Battery is the only text-bearing token | The "graphical only, battery excepted" rule, enforced by `isTextBearing` |
| A blank icon symbol is rejected | `Image(systemName: "")` renders a mystery box in the notch |
| A whitespace-only icon symbol is rejected too | Pins the `trimmingCharacters` call, not just an `isEmpty` check |
| A valid icon symbol passes through unchanged | Sanitising is not lossy for compliant tokens |
| No token ever degrades to anything other than the battery fallback | A malformed token must fail safe, not leak content |

### `IslandEditActionTests` — *"Edit shortcut contract"*

| Test | Guards |
| :--- | :--- |
| The installed edit menu has no duplicate key equivalents | A duplicate makes one menu item silently unreachable (fixed in `3195a56`) |
| A deliberate collision is detected, not silently accepted | Proves the validator is not vacuously empty |
| Shift and lowercase variants of the same physical key collide | Pins the `lowercased()` normalisation |
| Every installed action resolves to a real AppKit selector | Selectors are built with `#selector`, so a renamed AppKit API fails to compile |
| Delete is menu-only and is not part of the shortcut contract | `delete` claims no key and is appended separately in `buildMainMenu` |

### `SoundManagerMappingTests` — *"Sound scheme → cue mapping"*

| Test | Guards |
| :--- | :--- |
| Every scheme resolves every event to its intended system sound | The full palette, written longhand so a change without updating it is a failing diff |
| No event is unmapped in any scheme | A new `SoundType` case cannot silently play silence |
| The schemes remain distinct | `subtle` collapsing events onto one cue is deliberate, not a bug to "fix" |
| Every mapped cue is a real system sound on this Mac | A typo is silent at runtime. Checked against `/System/Library/Sounds` on disk rather than `NSSound(named:)`, which is lenient enough to accept a name with stray whitespace |

### `MediaBrowserTests` — *"Media browser registry"*

| Test | Guards |
| :--- | :--- |
| Detection order covers every browser exactly once | A browser added, typed, and never consulted |
| Bundle identifiers are unique | Lookup must be unambiguous |
| Every bundle id round-trips through the lookup | A browser could be detectable but not focusable — a dead button |
| An app that is not a browser resolves to nil | No guessing; `com.apple.Music` is not a browser |
| Safari is the only browser with a different tab script vocabulary | A third vocabulary must be added to the enum, not smuggled in as a name |
| No application name is blank | Each is interpolated into `tell application "…"` |
| YouTube control injection is a subset of detectable browsers | The play/pause button must not act on an undetected tab |
| Media keywords are non-empty, unique, quote-free | A quote would break the script for every browser |

### `MediaSourceClassificationTests` — *"NowPlaying source classification"*

| Test | Guards |
| :--- | :--- |
| A known app's bundle id decides the source | Music, Spotify, QuickTime, VLC |
| IINA is matched loosely | Its id has changed across releases; an exact match would re-break it |
| A known app wins even when the metadata says YouTube | The app chain is checked first |
| Chrome and Safari are classified as YouTube, not browser | Surprising, pre-existing, and deliberately pinned |
| A non-Chromium browser with no YouTube metadata is a generic web video | **This test found a real bug** — see below |
| YouTube metadata alone is enough, whatever the app | And is case-insensitive |
| An unrecognised app is system NowPlaying | With a real fallback artist |
| Classification never overwrites a reported artist | The fallback applies only when the artist is blank |
| An empty bundle id does not crash | Degrades to `.mediaRemote` |

> [!IMPORTANT]
> **`otherBrowsersAreGenericBrowser` found a live bug.** Browser detection matched a
> hand-typed list of display-name fragments (`"Chrome"`, `"Safari"`, `"Brave"`,
> `"Arc"`, `"Edge"`) against the bundle id. Three never matched anything: the real
> ids are `com.brave.Browser`, `company.thebrowser.Browser`, and
> `com.microsoft.edgemac`, none containing their fragment at that capitalisation. So
> a Brave, Arc, or Edge tab was never reported as `.browser` — it fell through to
> `.mediaRemote` and the island showed "Now Playing" with no source accent. Now
> matched against `MediaBrowser.bundleIdentifier`. This is the argument for making
> the policy pure and testing it: the bug was invisible because the only way to
> observe it was to play a video in Brave.

### `DesktopMediaAppTests` — *"Desktop media app parsing"*

The parsing for the direct-query tier (Music, Spotify, QuickTime, VLC) was inline and
untestable before `DesktopMediaApp.parse(output:app:)` made it pure. These are the
failures that are invisible until someone plays a track in that specific app.

| Test | Guards |
| :--- | :--- |
| Bundle identifiers and sources are unique across apps | No app may claim another's source, or the accent and icon lie |
| Only Spotify reports duration in milliseconds | The `/ 1000` was inside Spotify's script string, so the unit difference was invisible from Swift. A 3-minute track would show as 180000 s |
| Only the music apps report an album | 6 fields vs 4; the document players carry a fixed label |
| Every app's script names itself | The app name is interpolated into `tell application "…"` |
| A Music response parses with all six fields in order | Field order |
| A Spotify duration in milliseconds is converted to seconds | And that **position** is *not* also scaled |
| A paused state is read as not playing, in both vocabularies | `"paused"` and `"false"` |
| A document player reports true as playing | QuickTime returns a boolean string, not `"playing"` |
| A QuickTime response fills artist and album from the app | A blank row is worse than naming the app |
| A VLC response is always playing | Its script only runs when it is |
| Blank title or artist falls back, without shifting fields | Uses captured interpreter output |
| Field splitting treats a run of pipes as one delimiter | See the note below |
| Stopped, empty, and truncated responses yield no track | A short row must not become a track with zeroed timings |
| Non-numeric timings degrade to zero rather than dropping the track | Dropping it would flicker to "No Media Playing" mid-playback |
| Detection queries apps in the order the old tier chain used | `refreshMedia` walks `allCases`, so enum declaration order *is* detection priority |
| Every control verb addresses its own app and no other | The verbs were inline literals; a copy-paste addressing Music from Spotify's branch compiled fine and played the wrong track |
| Document players have no next/previous | QuickTime has documents, not a queue — the old chain had no branch, which read as an oversight rather than a fact |
| Only the document player guards on having a document open | Play with nothing loaded must be a no-op, not an error |
| Seeking is offered only where supported, and embeds the time | VLC stays off deliberately; a rounded time would misplace the scrubber |
| No control verb is blank | A `""` executes as an empty script and reports success while doing nothing |

> [!IMPORTANT]
> **The empty-field case is subtle, and the obvious reading of it is wrong.**
> `components(separatedBy:)` looks like it *drops* empty fields, which reads like a
> bug — until you check what AppleScript actually emits. An empty field produces a
> **run** of pipes, not a single delimiter. Verified against the real interpreter
> (`osascript`, not by reasoning):
>
> ```
> "playing" & "|||" & "" & "|||" & "" & "|||" & "Album"  =>  playing|||||||||Album
> ```
>
> That is **nine** pipes, and `components(separatedBy: "|||")` splits it into exactly
> `[playing, "", "", Album]` — the four fields the script meant. The run collapsing
> is what keeps later fields on the right indices, so position and duration do not
> slide up one slot.
>
> A hand-rolled splitter that consumed exactly three characters per step was tried
> here first and removed: it produces identical output on every captured row,
> including a trailing empty field and the empty string, so it was ~10 lines of
> hand-rolled string walking that could only introduce a bug `components` does not
> have.
>
> **Build fixtures by joining fields, never by counting pipes.** The tests use a
> `row(...)` helper that concatenates the same `& "|||" &` terms the script does.
> The hand-written literals were wrong repeatedly, and wrong *quietly*: a fixture
> written `"playing|||||Album"` is one field short — five pipes is one delimiter
> plus a stray `|` — so it parses as four fields with the artist read as
> `"|Album"`, and the assertion that looks like it is testing a fallback is
> actually testing a corrupted string. Counting pipes by eye cannot be made safe;
> joining fields cannot be miscounted.

### `MediaManagerOwnershipTests` — *"Desktop app ownership resolution"*

`MediaManager.desktopAppOwning(source:bundleIdentifier:)` decides which app a
control command is addressed to. It replaced a chain that appeared ten times across
the three control methods, each branch a hand-maintained copy of the same mapping.

| Test | Guards |
| :--- | :--- |
| A known bundle id names the app, whatever the source claims | The old chain used `source == .music \|\| bundleId == "com.apple.Music"`, so a contradictory source won by branch order and Music's `next track` went to Spotify |
| Every app's own id resolves back to that app | Ownership is total for the registry |
| With no bundle id, the source is the only evidence | A MediaRemote track can arrive with no id; resolving to `nil` would silently drop control for it |
| A browser or system NowPlaying track belongs to no desktop app | Must fall through to MediaRemote, not claim an app that is not playing |
| An unknown bundle id does not fall back to a wrong app | The dangerous case: an app outside the registry must not be addressed to whichever app its metadata named |
| Ownership is total: every resolution can accept the verb | Closes the dead end where a resolved app has no `controls` |

> [!NOTE]
> **Watch the `??` precedence when writing assertions against optionals.**
> `controls?.play ?? ""` inside a `.contains(…)` call parses as
> `controls?.(play ?? "")` and yields `Optional<Bool>`. Since `!Optional<Bool>` is
> always `false`, `#expect(!(app.controls?.play ?? "").contains("x"))` passes no
> matter what the string contains. Unwrap into a local first. This is not
> hypothetical — it produced a test here that asserted nothing.
