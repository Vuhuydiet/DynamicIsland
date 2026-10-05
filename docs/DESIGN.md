# 🧭 Design Commitments

The decisions this app is built on that are expensive to reverse.

Each one earns its place by being **learned the hard way**.
The *why* is what stops it being reverted as redundant; if a commitment is obvious from the code, it does not belong in this file.

These used to live in [`../AGENTS.md`](../AGENTS.md) §2, where they were mixed in with rules about how to work.
They are separated because they are **commitments about this app**, not instructions to a contributor: a rule earns its place in `AGENTS.md` by applying everywhere, and these apply to one design.

Code cites the numbered commitment it is satisfying, e.g. `AGENTS.md §2.2` → **Fixed Surfaces** below.

---

## 📑 Table of Contents

1. [Fixed Surfaces](#1-fixed-surfaces)
2. [Global State Is Load-Bearing](#2-global-state-is-load-bearing)
3. [Closed Types](#3-closed-types)
4. [Structure vs Content](#4-structure-vs-content)
5. [Discrete Recognizers](#5-discrete-recognizers)
6. [Lossy Signals](#6-lossy-signals)
7. [Honest State](#7-honest-state)

---

## 1. Fixed Surfaces

*A surface's size is a constant.*

When geometry is owned by something you don't control — a cutout, a bezel — let content adapt instead: scale, truncate, or swap to a glyph.
Resizing the surface reads as a glitch.

**In this app:** the closed notch is sized by the hardware notch plus `compactEarWidthFixed`, never by the current activity, so the left ear scales and truncates its text, the right ear is graphical only, and a running countdown drops to its ring glyph when the strip overflows.
Sizing the ears per-state was tried and reverted: an incoming notification ballooned the notch to 135pt per ear, which read as the notch glitching rather than as a notification arriving.

**Scope:** this governs geometry the app does not own.
The **opened** island is user-owned workspace and is resizable — see [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.

---

## 2. Global State Is Load-Bearing, Not Legacy

Singletons are deliberate and the concurrency language mode is coupled to them; modernising is its own project, not a drive-by.

**In this app:** `AppState.shared`, `SettingsManager.shared`, `PluginManager.shared` and the rest are the deliberate architecture, which is why `Package.swift` pins `swiftLanguageMode(.v5)` — under Swift 6 every `static let shared` is a hard `#MutableGlobalVariable` error.
The cost of that choice is a shared id having exactly one owner: adding a preset that is already installed is a no-op rather than a duplicate machine.

---

## 3. Closed Types

*Encode a surface's limits in its type,* not in a render branch, which the next branch you add bypasses silently.
A closed enum is both the enforcement mechanism and the test surface.

**In this app:** the right ear accepts only `RightEarToken`, and no case except `.battery` can carry a string, so a plugin **structurally cannot** put text there.
A plugin that needs readable text in the notch returns a `CompactEarItem` from `compactItems()` instead.
`IslandPluginCapabilities` and `IslandTab` are closed for the same reason: adding a shell or a capability forces a decision at every `switch` over them.

---

## 4. Structure vs Content

Presentation owns framing, navigation, and transitions; needing different content means a new content type, not a new variant.

**In this app:** every opened shell renders tab content through the single `IslandTabContentView`, so a shell never forks a tool view; and `PluginManager` stays ignorant of the `WebAppPlugin` subtype — the favicon fetch hangs off the plugin's own `onRegister()` rather than an `as?` cast in the registry that the next plugin type would have to remember.

---

## 5. Discrete Recognizers

A discrete action needs a discrete recognizer.
A continuous gesture reports nothing on a still input, so never derive select/submit/confirm from its end callback; and transient state whose release can be lost must be dropped, never left pinned.

**In this app:** tab selection lives in `TabDragCoordinator`, not in `DragGesture.onEnded` — a clean click travels zero pixels, so a still click would report nothing and select nothing.
A lost drag release must unpin the coordinator, because a pinned `draggingTab` makes every other pill fail both guards and the bar wedges.

---

## 6. Lossy Signals

System signals are lossy.
Corroborate before acting, debounce noisy ones, and degrade to an honest empty state rather than a confident wrong one.

**In this app:** the page title is content the site controls, so it is never parsed for an unread count — a URL the user typed could display an invented number in a banner wearing the island's identity.
Alerts fire only on a real `new Notification()` from the page, and the alert never quotes the page: `WebAppPlugin.displayNotice(from:appName:)` substitutes the user's own app name and a fixed string.
A failed favicon fetch leaves the neutral globe rather than a broken-image placeholder, because silent failure that looks like success is the failure mode this rule exists to prevent.

---

## 7. Honest State

*Never fabricate system state.*
No demo mocks, simulated activity, or stand-ins for a capability the app does not have.

**In this app:** a web app with no cached logo shows a neutral globe, never an invented brand mark; a malformed `RightEarToken` degrades to the battery fallback rather than leaking content; a missing bundled `DefaultWebApps.json` fails the build loudly instead of silently seeding nothing; and native `.app` embedding is **not offered at all**, because shipping an import affordance that cannot work is worse than not offering it.

An absent or broken input is not a crash and not a fabricated value — it is an honest empty result.
