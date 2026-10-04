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

Tiers are tried in order and the first hit wins. When a later poll finds nothing, the
transition to `.empty` is **debounced** over several consecutive empty readings so a
transient `MediaRemote` timeout during video playback does not make the UI flicker.

`AudioOutputMonitor` acts as a corroborating signal — if the system is actively
producing audio, the last known track is kept rather than cleared.

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

**Opening the source** — focus the exact browser tab by URL where possible, then by
track title, then activate the owning application by bundle id, then fall back to
opening the app for the detected source.

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

`visualizerHeights` is a 7-element array driving the equalizer bars. A `0.12s`
repeating timer animates the bars only while a track is actually playing, drawing
random heights in `0.25...1.0` and smoothing them with the `IslandSpring.visualizer`
spring. When nothing is playing the bars are idle rather than frozen mid-frame.

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
