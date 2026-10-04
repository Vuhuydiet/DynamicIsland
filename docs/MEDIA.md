# 🎵 Media & NowPlaying Subsystem

How the island detects and controls media playing in *any* application, and the
platform quirks that make it hard.

---

## 📑 Table of Contents

1. [Overview](#1-overview)
2. [MediaRemote Dynamic Binding](#2-mediaremote-dynamic-binding)
3. [Detection Tiers](#3-detection-tiers)
4. [Playback State](#4-playback-state)
5. [Playback Control](#5-playback-control)
6. [Audio Output Monitor](#6-audio-output-monitor)
7. [The Visualizer](#7-the-visualizer)
8. [Gotchas](#8-gotchas)

---

## 1. Overview

`MediaManager` is a four-tier detection pipeline with a control stack that degrades
from most to least invasive. Nothing in it is mocked: production code reflects real
system sessions only.

```
                    ┌──────────────────────────────────┐
   detection ──────▶│ 1. MediaRemote (system-wide)     │──┐
                    │ 2. Apple Music / Spotify         │  │
                    │ 3. Local players (QuickTime/VLC) │  ├──▶ MediaTrack
                    │ 4. Browser active-media tab      │  │
                    └──────────────────────────────────┘  │
                                                          ▼
                    ┌──────────────────────────────────┐
   control  ───────▶│ 1. AppleScript (targeted app)    │──┐
                    │ 2. MRMediaRemoteSendCommand       │  ├──▶ the player
                    │ 3. YouTube DOM button (web only)  │  │
                    │ 4. Synthetic media key event      │──┘
                    └──────────────────────────────────┘
```

A `MediaTrack` carries `title`, `artist`, `album`, `duration`, `position`,
`isPlaying`, `source`, `artworkData`, and `url`.

Recognised sources: `.spotify`, `.youtube`, `.quicktime`, `.vlc`, `.iina`,
`.browser`, `.mediaRemote`, `.music`, `.none`.

---

## 2. MediaRemote Dynamic Binding

macOS ships no public headers for `MediaRemote`, but the symbols exist in the dyld
shared cache. They are resolved at runtime with `dlopen` / `dlsym` and stored as
function pointers — so a missing symbol degrades one capability rather than
crashing the app.

| Symbol | Purpose |
| :--- | :--- |
| `MRMediaRemoteGetNowPlayingInfo` | Current track metadata and artwork |
| `MRMediaRemoteGetNowPlayingApplicationPID` | Which app owns the session |
| `MRMediaRemoteRegisterForNowPlayingNotifications` | Change notifications |
| `MRMediaRemoteSendCommand` | Playback commands |
| `MRMediaRemoteGetNowPlayingApplicationIsPlaying` | Direct boolean play state |
| `MRMediaRemoteGetNowPlayingApplicationPlaybackState` | Raw playback state |
| `MRMediaRemoteSetElapsedTime` | Legacy seek path |

Observed after registration:

| Notification constant | Meaning |
| :--- | :--- |
| `kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification` | Play state flipped |
| `kMRMediaRemoteNowPlayingPlaybackStateDidChangeNotification` | State transition |
| `kMRMediaRemoteNowPlayingInfoDidChangeNotification` | Track metadata changed |
| `kMRMediaRemoteNowPlayingApplicationDidChangeNotification` | Different app took over |

### Command IDs

```swift
public enum MRCommand: Int32 {
    case play                  = 0
    case pause                 = 1
    case togglePlayPause       = 2
    case stop                  = 3
    case nextTrack             = 4
    case previousTrack         = 5
    case seekToPlaybackPosition = 24
}
```

Seeking uses command `24` with the `kMRMediaRemoteOptionPlaybackPosition` key,
which macOS supports natively across Chrome, Edge, Brave, Arc, and Safari.

---

## 3. Detection Tiers

1. **MediaRemote** — the system-wide source of truth. Preferred whenever it
   returns a track.
2. **Apple Music / Spotify** — targeted AppleScript, used when MediaRemote has
   nothing (these apps report inconsistently while backgrounded).
3. **Local video players** — `com.apple.QuickTimePlayerX` (QuickTime) and VLC,
   queried for open documents.
4. **Browser active-media tab** — Chrome, Safari, Brave, Arc, and Edge, queried for
   the active tab's `<video>`/`<audio>` element and its title.

Tiers 2 and 3 are driven by the `DesktopMediaApp` enum: each case carries its own
script, fallback strings, field count, `durationScale`, and `controls` (its
transport verbs). `parse(output:app:)` is pure and unit-tested, which matters
because the parts most likely to be wrong quietly — field order, unit conversion,
and the two state vocabularies — are invisible until someone plays a track in that
app.

> [!IMPORTANT]
> **The declaration order of `DesktopMediaApp` *is* the detection priority.**
> `refreshMedia` walks `allCases` and stops at the first app reporting a track, so
> the enum reads Music → Spotify → QuickTime → VLC. Reordering the cases changes
> which track wins when two apps play at once, with no compile error and no other
> visible symptom. `DesktopMediaAppTests` pins the order for that reason.

> [!NOTE]
> **Spotify reports duration in milliseconds; every other app reports seconds.** That
> difference used to be a literal `/ 1000` *inside* Spotify's AppleScript string, so
> from Swift it was invisible and untestable. It is now `durationScale`, plain data,
> with a test asserting position is *not* scaled alongside it.
>
> The response is `|||`-delimited, and the splitting has a subtlety worth knowing: an
> empty field makes AppleScript emit a **run** of pipes, and
> `components(separatedBy:)` collapsing that run is what keeps the later fields on
> the right indices. `DesktopMediaApp.fields(of:)` is the single splitter for that
> wire format — the browser path uses it too, so the two AppleScript families cannot
> disagree about what a separator means. See the note in
> [`TESTING.md`](TESTING.md) before "simplifying" it.

Tiers are tried in order and the first hit wins. When a later poll finds nothing, the
transition to `.empty` is **debounced** over several consecutive empty readings so a
transient `MediaRemote` timeout during video playback does not make the UI flicker.

`AudioOutputMonitor` acts as a corroborating signal — if the system is actively
producing audio, the last known track is kept rather than cleared.

### Browser registry

The set of supported browsers lives in exactly one place, the `MediaBrowser` enum:
`bundleIdentifier`, `applicationName` (what `tell application "…"` needs, and which
is *not* derivable from the bundle id — Arc is the reason), and `tabScriptStyle`.

| Why it is a type | The bug it prevented |
| :--- | :--- |
| `allCases` is exhaustive, and `detectionOrder` must equal it | A browser could be added, typed, and never consulted |
| `MediaBrowser(bundleIdentifier:)` resolves exactly | A browser could be *detectable* but not *focusable* — the island reads a track and then fails to focus its tab, which reads as a dead button |
| One `bundleIdentifier` each | The mapping was previously written out **four** times across detection, YouTube injection, tab focus, and an inline dictionary, with nothing checking they agreed |

`tabScriptStyle` is the real per-browser API difference: Safari exposes
`current tab of w` and `name of t`, while the Chromium family (Chrome, Brave, Arc,
Edge) exposes `active tab index` and `title of t`. Modelling it as a closed enum
replaces a string comparison on `"Safari"` that would have silently misrouted any
future browser.

### NowPlaying source classification

`MediaSourceClassification.classify(bundleId:artist:title:)` turns a system
NowPlaying report into a `MediaSource`. `MediaRemote` reports only a bundle
identifier — no app name, no media kind — so this is a judgement call, and it is a
pure function so it is unit-testable without a live `dlsym`ed framework pointer.

Two behaviours in it are surprising enough to be worth knowing before "fixing" them:

- **Chrome and Safari are classified `.youtube`, not `.browser`,** for *any* track.
  The YouTube test includes `bundleId.contains("Chrome") || bundleId.contains("Safari")`,
  so it fires even when the metadata never mentions YouTube. Pre-existing, pinned by
  test.
- **A known app outranks YouTube metadata.** The app check runs first, so a Music or
  Spotify report is never reclassified as a web video.

`MediaBrowser.bundleIdentifier` is also what this classification matches against,
which is how a browser cannot be known to one part of the media path and unknown to
another.

---

## 4. Playback State

> [!IMPORTANT]
> **No single signal is trustworthy here, so none is used alone.**
> `checkPlaybackState(rate:)` combines three sources in priority order:
>
> 1. **Positive indicators** — a non-zero playback rate, `MRMediaRemote…IsPlaying`,
>    or a positive MediaRemote state ⇒ playing.
> 2. **Explicit pause** — a MediaRemote paused/stopped state, or a rate of exactly
>    `0.0` ⇒ paused.
> 3. **Hardware fallback** — CoreAudio reporting the output device is running
>    somewhere ⇒ playing, even when MediaRemote has no opinion.

Playback state from `MRMediaRemoteGetNowPlayingApplicationPlaybackState` decodes as
`1 = playing`, `2 = paused`, `3 = stopped`.

### Debounce

- **Flicker guard** — a `false` reading must repeat across several consecutive
  cycles before the UI is allowed to show paused. A `true` reading applies
  immediately, because a stuck "playing" state is far more noticeable than a
  one-cycle delay.
- **User-intent cooldown** — immediately after the user presses a control, state
  polling is suppressed for a short window so the manager does not fight the user's
  own action.

---

## 5. Playback Control

Every control walks the same escalation ladder and stops at the first tier that
reports success.

**Play/pause** — the command sent is *explicit*, not a toggle:

1. AppleScript for the targeted app (Music, Spotify, QuickTime).
2. `MRMediaRemoteSendCommand(.play)` or `(.pause)` — chosen from the state the UI
   already believes it is in.
3. Only if that returns `false`, fall back to `.togglePlayPause`.
4. Synthetic media key (`NX_KEYTYPE_PLAY_PAUSE`).

**Next / previous** — same ladder, ending with a YouTube DOM click
(`.ytp-next-button` / `.ytp-prev-button`) and then the synthetic media key
(`NX_KEYTYPE_NEXT` / `NX_KEYTYPE_PREVIOUS`).

**Seek** — `MRMediaRemoteSendCommand(.seekToPlaybackPosition)` with the position
option, then `MRMediaRemoteSetElapsedTime`, then an app-specific AppleScript
(`set player position to N`).

> [!IMPORTANT]
> **Send explicit play and pause, never the toggle.** Browsers (Chrome, Brave, Arc,
> Edge) routinely ignore command `2` (`kMRTogglePlayPause`) when paused. Choosing
> the command from the state the UI already has is what makes web playback reliable.

### Which app a command is addressed to

`MediaManager.desktopAppOwning(source:bundleIdentifier:)` decides this, as a pure
function so the policy is testable without a live track. It replaced a chain that
appeared **ten times** across the three control methods:

```swift
if currentTrack.source == .music || currentTrack.bundleIdentifier == "com.apple.Music" { … }
else if currentTrack.source == .spotify || currentTrack.bundleIdentifier == "com.spotify.client" { … }
```

Two rules, and the second is the subtle one:

| Reported bundle id | Resolves to | Why |
| :--- | :--- | :--- |
| A recognised one | That app | The id is what the OS actually reported, so it is authoritative |
| Absent or `""` | The app matching `source` | Nothing was reported; the source is the only evidence left |
| Present but unrecognised | **`nil`** | The track came from outside the registry — no desktop app owns it |

Falling through to `source` on an *unrecognised* id is the trap the old `||` fell
into: a track from an app we do not know would be addressed to whichever app its
metadata happened to name. `nil` instead means the caller falls through to
MediaRemote and the media-key fallback knowingly.

The verbs themselves are data on `DesktopMediaApp.controls`, not inline strings. Two
details there are load-bearing rather than stylistic:

- **A missing verb is `nil`, never `""`.** QuickTime has no `next track` concept, so
  the chain falls through to MediaRemote. An empty string would be sent to the
  interpreter and report success while doing nothing.
- **VLC is not seekable here.** It can seek, but this path only *supplements* a
  MediaRemote seek that already covers every player macOS knows about, so
  `setPosition` returns `nil` and the behaviour matches the `switch` it replaced.

**Opening the source** — focus the exact browser tab by URL where possible, then by
track title, then activate the owning application by bundle id, then fall back to
opening the app for the detected source. App selection resolves through
`DesktopMediaApp` and `MediaBrowser` rather than repeating bundle ids, so a
corrected id cannot leave one path stale.

---

## 6. Audio Output Monitor

`AudioOutputMonitor` is a permission-free CoreAudio listener.

| Piece | Detail |
| :--- | :--- |
| System listener | `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default output device |
| Device-change listener | Re-binds when the default output device changes |
| Callback | `onPlaybackStateChanged`, dispatched to the main queue |

It answers exactly one question — *is audio currently coming out of this Mac?* —
and is used both to corroborate playback state and to gate the browser-media
fallback. It requires **no** microphone, accessibility, or screen-recording
permission.

---

## 7. The Visualizer

> [!IMPORTANT]
> **The equalizer is not an audio meter. It never was, and it is not pretending to
> be one.** Read this before changing it.

`visualizerHeights` is a 7-element array driving the equalizer bars, animated by a
`0.12s` repeating timer and smoothed with the `IslandSpring.visualizer` spring. It
advances a fixed rotating pattern while a track is playing, and sits at a flat idle
value when nothing is playing.

It does **not** represent audio levels. It previously used
`CGFloat.random(in: 0.25...1.0)`, which fabricated system state — the island showed
a live-looking meter driven by pure noise, implying it was reading the audio stream.
`AGENTS.md` §2.7 forbids shipping a simulated stand-in for a capability the app does
not have.

Real output metering is genuinely unavailable, and staying that way is the decision:

| Route | Why not |
| :--- | :--- |
| `kAudioDevicePropertyDeviceLevelMeterScalar` | Not exported by any public SDK header. Verified: absent from `AudioToolbox` and `CoreAudio` in the macOS SDK. |
| `AVAudioEngine` tap | macOS has no `AVAudioSession`; there is no tap without an input/IO context this app does not own. |
| `dlsym` on a private selector | The same fragility as the MediaRemote bridge, for a cosmetic animation. Not worth it. |
| A dependency | The project has zero third-party dependencies (`AGENTS.md` §4). |

The animation therefore reflects the one thing that *is* true — whether audio is
playing — and claims nothing beyond it. `startVisualizer()` is the single place to
change if real metering is ever wanted.

The compact notch shows a compact visualizer via `RightEarToken.mediaVisualizer` —
the right ear never shows a text label such as a track name or "Paused". See the
right-ear contract in [`../AGENTS.md`](../AGENTS.md) §2.3.

---

## 8. Gotchas

> [!WARNING]
> **Synthetic media keys are silently ignored without elevated permissions.**
> `NSEvent.otherEvent(with: .systemDefined, …).cgEvent?.post(tap: .cghidEventTap)` is
> dropped by macOS unless the process has Root or Accessibility permission. It is
> the *last* tier of the ladder, never the first, and it posts to both
> `.cghidEventTap` and `.cgSessionEventTap` when used.

> [!WARNING]
> **The toggle command is unreliable in browsers.** Always send explicit play/pause.
> See §5.

> [!WARNING]
> **`MRMediaRemoteGetNowPlayingApplicationPlaybackState` is not sufficient on its
> own.** It can report `<Paused>` for the default player path even while an audio
> session is actively streaming. Use the direct boolean
> `MRMediaRemoteGetNowPlayingApplicationIsPlaying` and corroborate with CoreAudio.

> [!IMPORTANT]
> **No demo player.** Production code must strictly reflect real media sessions.
> Demo mocks, simulated timers, and sparkle stand-ins must not appear in
> `MediaManager` or `MediaView`. If no session exists, show the empty state.
