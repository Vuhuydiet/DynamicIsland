# ✨ Features

The user-facing feature reference. For how any of this is built, see
[`ARCHITECTURE.md`](ARCHITECTURE.md); for writing a plugin, see
[`PLUGINS.md`](PLUGINS.md).

---

## 📑 Table of Contents

1. [The Two States](#1-the-two-states)
2. [The Closed Notch](#2-the-closed-notch)
3. [The Opened Island](#3-the-opened-island)
4. [Tabs & Tools](#4-tabs--tools)
5. [File Drop Shelf](#5-file-drop-shelf)
6. [System HUD](#6-system-hud)
7. [Plugins & Apps](#7-plugins--apps)
8. [Sounds](#8-sounds)
9. [Preferences](#9-preferences)
10. [Shortcuts & Gestures](#10-shortcuts--gestures)

---

## 1. The Two States

The island is either **closed** (a compact bar hugging the notch) or **opened** (the
full multi-tab workspace). It expands on hover or click, collapses when the cursor
leaves, and can be pinned open with 📌.

The closed notch is a **fixed-size window** — its width depends on the hardware
notch, not on what is happening inside it. This is deliberate: a notch that resizes
per-event reads as a glitch. See [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.

---

## 2. The Closed Notch

Two ears flank the hardware notch, sealing flush into the top bezel.

**Left ear** — may carry text. Shows whichever is most relevant:

| State | Content |
| :--- | :--- |
| Plugin notification | App icon + sender name (scaled to fit) |
| Timer finished | Timer glyph + done indicator |
| Timer running | ⏳ live countdown (`04:32`) |
| Stopwatch running | ⏱ live stopwatch time |
| Media playing | Source glyph |
| Media loaded, paused | Source glyph, dimmed |
| Files parked | 📥 parked file count |

**Right ear** — **graphical only**; the sole exception is the battery percentage.
Shows a progress ring for a running timer, a pulse when it completes, a lap flag for
a stopwatch, an equalizer while media plays, a pause glyph when media is loaded but
idle, a folder glyph when files are parked, and a plugin or notification icon for
alerts. This contract is enforced in code by a closed token type — see
[`../AGENTS.md`](../AGENTS.md) §2.3.

**Interaction** — clicking the closed island expands it. If a notification is
showing, tapping it opens straight into that plugin's tab. Tapping while a timer has
finished jumps to the Timer tab.

---

## 3. The Opened Island

| Region | Content |
| :--- | :--- |
| Header left | Clickable `Dynamic Island` title → Preferences |
| Header centre | Notch spacer cutout matching the real hardware notch |
| Header right | System HUD (CPU → RAM → disk), then 📌 pin |
| Tab bar | Full-width sliding pill bar, equal-width pills, reorderable by drag |
| Content | The active tool, centred, in a compact or full-height viewport |

The island **widens** when an integrated app tab is active and morphs back for system
tools, with spring physics on both axes. Exact dimensions:
[`ARCHITECTURE.md`](ARCHITECTURE.md) §3.

**Tab order** is user-configurable (**Preferences → Behavior & Tabs → Island Tabs &
Order**) with up/down arrows, position indicators, and a one-click reset. Tabs are
identifiable by name in Preferences and reorderable by dragging. Newly registered
plugins are appended safely.

**Universal tab content** — the tool views are the same regardless of shell. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) §6.

---

## 4. Tabs & Tools

### 🎵 Media

Detects playback across browsers (Chrome, Safari, Brave, Arc, Edge), music apps
(Apple Music, Spotify), and local players (QuickTime, VLC, IINA). Shows artwork,
title, and artist, with previous / play-pause / next and a draggable scrubber. A
multi-bar equalizer visualizer syncs to active audio output.

IINA is detected through the system's NowPlaying report only — it has no
AppleScript adapter, so its transport controls go through the system-wide path
rather than a targeted one. See [`MEDIA.md`](MEDIA.md).

Full detail, including the platform quirks: [`MEDIA.md`](MEDIA.md).

### ⏱️ Timer & Stopwatch

A mode picker (**Timer** | **Stopwatch**) with a sliding matched indicator.

- **Timer** — H / M / S steppers, plus quick presets `1m`, `5m`, `15m`, `🍅25m`
  (Pomodoro). The countdown ticks live in the closed notch, and completion fires a
  sound plus a system notification.
- **Stopwatch** — millisecond precision with lap timing (`Lap`, `Split`, `Total`).
  The fastest lap is highlighted with a green bolt ⚡ and the slowest with a red
  tortoise 🐢.

### 📋 Clipboard

Automatically captures copied text and links, deduplicating repeats, and persists
recent items. One click re-copies an entry.

### 📝 Notes

A persistent scratchpad with debounced auto-save to disk and one-click export to the
clipboard.

---

## 5. File Drop Shelf

The Drop Shelf is **decoupled from the tab bar** — it has no tab of its own, so it
costs no clutter when empty.

- **Drag over the notch** to auto-expand the island and reveal the shelf, a separate
  floating rectangle 12pt below the main island with an illuminated cyan border.
- **Drop onto the shelf** to park the file. The main island itself deliberately
  rejects drops so you cannot accidentally park a file over your tab content.
- **Retrieve in one action** — hover the notch and drag the file straight out into
  Finder or any app.
- **Per-card actions** — reveal in Finder, copy path, remove.
- **Two card styles** (**Preferences → Behavior & Tabs**): **Square Cards** (default,
  68×66pt with a 32×32 icon and a hover ✕) or **Compact Strip** (horizontal capsules).

Parked files are persisted with security-scoped bookmarks, so they survive a
relaunch. Ingestion has a multi-tier fallback for maximum compatibility with
whatever the dragging app offers.

---

## 6. System HUD

The header's right ear carries a live three-stat readout, refreshed every 2 seconds:

| Stat | Source |
| :--- | :--- |
| ⚙️ **CPU** | Host statistics from CPU tick deltas; colour shifts with load |
| 💾 **RAM** | `host_statistics64` — active + wired pages, in GB |
| 💽 **Disk** | Root volume used space, in GB |

Hovering any stat reveals the precise figure in a tooltip.

---

## 7. Plugins & Web Apps

Any app can be injected into the island — a native Swift tool or a full web
application. See [`PLUGINS.md`](PLUGINS.md).

**Adding a web app takes about ten seconds.** Open **Preferences → Plugins**, paste an
address, press **Add**. There is no plugin to write and no code to compile: each web
app is a stored descriptor that the same `WebAppPlugin` renders. A missing `https://`
is filled in for you, and a bad address is rejected with a specific reason instead of
becoming a tab that loads nothing. Messenger is seeded this way — it is an ordinary
entry you can rename, edit, disable, or delete, and re-add from **Presets**.
> [!NOTE]
> **Native `.app` integration is not offered.** macOS provides no supported way to
> embed another app's UI in a panel. The workarounds (Screen Recording to mirror a
> window, Accessibility to re-render an `AXUIElement` tree) would mean a permission
> prompt in a menu-bar app, and the Accessibility route breaks on every app update —
> so no import affordance ships, rather than shipping one that cannot work.

| Capability | What you get |
| :--- | :--- |
| **Add by URL** | Paste any address; a separate tab and web session are created for it |
| **Dynamic sizing** | Integrated apps get a larger viewport automatically |
| **Persistent login** | Cookies and `localStorage` survive relaunch, per site |
| **Per-site zoom** | Zoom is stored per host, so two web apps don't share one setting |
| **Authentic icons** | Each tab's icon is fetched from the site itself (`/favicon.ico`, then `/apple-touch-icon.png`) and cached on disk, so a new app shows its real logo without you hunting for one. Sites that publish neither keep a neutral globe — a tab never borrows another app's icon |
| **Per-plugin sound** | Every app is sound-configurable with **zero** extra UI code |
| **Live notifications** | A page's own `new Notification()` surfaces as an in-notch alert |
| **Multiple alerts** | Simultaneous alerts all stay visible, each on its own timer |
| **Tab ordering** | Web app tabs participate in your custom tab order |

**In-notch alerts** — a notification arriving while the island is closed scrolls
through the left ear as a marquee: the app's icon and the sender, travelling right and
retiring once clear. The right ear shows the **icon only**, never message text (per the
right-ear contract). The app's own configured alert cue plays. Banners auto-dismiss
after 4.5 seconds; tapping one opens the island directly into that app's tab. The same
alert is also posted as a native macOS notification, and clicking that banner routes to
the tab too.

The ear is a fixed 56pt, so when alerts are scrolling a running timer drops its digits
and shows its icon alone — the countdown keeps its own fixed position rather than
being carried off the edge, where it would expire unseen.

> [!NOTE]
> **Alerts come only from a page asking for them.** The old unread badge, which parsed
> a count out of the page title (`(3) Alice: hi`), is gone. The title is content the
> page controls, so for an address you typed it meant a site could display an invented
> unread count and raise macOS banners on its own. Unread presence is now shown by the
> scrolling alert and the right-ear icon.

---

## 8. Sounds

Tactile audio feedback throughout: clicks, expand, collapse, drop, and a distinct
double-pulse for timer completion.

**Preferences → Sound Effects** controls the master switch, global volume, the audio
theme scheme, and per-event toggles — each with an audition button. Per-plugin
alert and interaction cues are configured for **every registered plugin**
automatically, because the UI is generated by iterating the plugin registry.

---

## 9. Preferences

Open with `⌘,`, by clicking the `Dynamic Island` title in the header, or from the
menu bar.

| Pane | Contents |
| :--- | :--- |
| **General** | Appearance theme, closed-notch style with live interactive preview cards, menu-bar icon toggle, launch at login via `SMAppService` |
| **Animations** | Expansion choreography (Fluid Apple / Holographic HUD), speed multiplier `0.60×`–`1.75×`, and an interactive notch playground that simulates the spring in real time |
| **Behavior & Tabs** | Docking mode (Auto / Attached to Notch / Floating Pill), expansion trigger, hover delay and sensitivity, tab visibility, tab order, drop-shelf card style |
| **Plugins** | Per-plugin enable, zoom, reload, open in browser, test notification, cache reset |
| **Sound Effects** | Master switch, volume, theme scheme, per-event toggles, per-plugin cues |
| **Geometry & Notch** | Live hardware notch telemetry and pixel-accurate offset calibration |
| **Shortcuts** | Global shortcuts and a mouse-gesture cheatsheet |
| **About** | System status, framework badges, quit |

---

## 10. Shortcuts & Gestures

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Expand** | Hover the notch, or click the compact pill |
| **Collapse** | Move the cursor away, or press `Esc` |
| **Toggle expand / collapse** | `⌥ + ⌘ + I` |
| **Open Preferences** | `⌘,` (or `⌥ + ⌘ + ,` globally) |
| **Pin / unpin** | Click 📌 in the header |
| **Park files** | Drag any file over the notch |
| **Reorder tabs** | Drag a tab pill in the opened island |
| **Play / pause media** | Media tab controls, or the system media keys |
