import Foundation

/// A desktop media app the island can query directly with AppleScript.
///
/// ## Why this is data
///
/// The four direct-query adapters — Music, Spotify, QuickTime, VLC — were four
/// near-identical `fetch…Track()` methods. Music and Spotify were the worst: ~30
/// identical lines each, differing only in the app name, a fallback artist string,
/// the source case, the bundle id, and a `/ 1000` on duration that was buried
/// *inside* the AppleScript text.
///
/// That last one is the reason this is a type rather than a loop. Spotify reports
/// duration in milliseconds and Music in seconds, and because the conversion lived
/// in the script string it was invisible from Swift and untestable. It is now
/// `durationScale`, plain data, checked by `DesktopMediaAppTests`.
///
/// The scripts still differ per app — QuickPlayer addresses `document 1` while
/// Music addresses `current track` — so each case owns its own script. What is
/// shared is the *parsing*, which is the part that can be wrong quietly: a field
/// count that is off by one, a state string that means "playing" in one app and
/// "true" in another, a duration in the wrong unit.
public enum DesktopMediaApp: String, CaseIterable, Sendable, Equatable {
    // ⚠️ DECLARATION ORDER IS DETECTION PRIORITY.
    //
    // `MediaManager.refreshMedia` walks `allCases` in order and stops at the first
    // app that reports a track, so this sequence *is* the tier order: Music, then
    // Spotify, then the two document players. It replaces an explicit chain that
    // happened to be in this order.
    //
    // With two apps playing at once, reordering these cases changes which track the
    // island shows, with no compile error and no other visible symptom. That is why
    // `DesktopMediaAppTests` pins the order explicitly rather than treating it as an
    // implementation detail. Add new apps at the position their priority implies.
    case music
    case spotify
    case quickTime
    case vlc

    /// The name used in `tell application "…"`.
    public var applicationName: String {
        switch self {
        case .music:    return "Music"
        case .spotify:  return "Spotify"
        case .quickTime: return "QuickTime Player"
        case .vlc:      return "VLC"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .music:    return "com.apple.Music"
        case .spotify:  return "com.spotify.client"
        case .quickTime: return "com.apple.QuickTimePlayerX"
        case .vlc:      return "org.videolan.vlc"
        }
    }

    public var source: MediaSource {
        switch self {
        case .music:    return .music
        case .spotify:  return .spotify
        case .quickTime: return .quicktime
        case .vlc:      return .vlc
        }
    }

    /// Shown as the artist when the app reports none. These are apps, not artists,
    /// so a blank row would be worse than naming the app.
    public var fallbackArtist: String {
        switch self {
        case .music:    return "Apple Music"
        case .spotify:  return "Spotify"
        case .quickTime: return "QuickTime Player"
        case .vlc:      return "VLC Media Player"
        }
    }

    /// Shown as the title when the app reports none.
    public var fallbackTitle: String {
        switch self {
        case .music, .spotify: return "Unknown Title"
        case .quickTime: return "Video"
        case .vlc:      return "Media File"
        }
    }

    /// Fixed album label. The document players have no album concept, and an empty
    /// album renders as a blank row in the expanded view.
    public var albumLabel: String? {
        switch self {
        case .music, .spotify: return nil   // reported by the app
        case .quickTime: return "Local Video"
        case .vlc:      return "Video / Audio"
        }
    }

    /// Multiplier applied to the reported duration to yield seconds.
    ///
    /// Spotify's AppleScript reports milliseconds; every other app here reports
    /// seconds. Previously this was a literal `/ 1000` inside Spotify's script
    /// string, which meant the unit difference was untestable and easy to lose.
    public var durationScale: Double {
        self == .spotify ? 0.001 : 1.0
    }

    /// The AppleScript that returns `|||`-delimited fields, or `"stopped"`.
    public var script: String {
        switch self {
        case .music, .spotify:
            // Shared shape: both expose a player with a `current track`.
            return """
            tell application "\(applicationName)"
                if player state is playing or player state is paused then
                    set pState to player state as string
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tPos to player position
                    set tDur to duration of current track
                    return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tPos & "|||" & tDur
                else
                    return "stopped"
                end if
            end tell
            """
        case .quickTime:
            return """
            tell application "\(applicationName)"
                if (count of documents) > 0 then
                    set doc to document 1
                    set pState to playing of doc
                    set docName to name of doc
                    set curTime to current time of doc
                    set docDur to duration of doc
                    return (pState as string) & "|||" & docName & "|||" & curTime & "|||" & docDur
                else
                    return "stopped"
                end if
            end tell
            """
        case .vlc:
            // VLC's script only emits a row when it is already playing, so the
            // literal state is always "playing".
            return """
            tell application "\(applicationName)"
                if playing then
                    set tName to name of current item
                    set curTime to current time
                    set tDur to duration of current item
                    return "playing|||" & tName & "|||" & curTime & "|||" & tDur
                else
                    return "stopped"
                end if
            end tell
            """
        }
    }

    /// How many `|||`-delimited fields a non-`"stopped"` response carries.
    ///
    /// Music-shaped apps report state, name, artist, album, position, duration.
    /// Document players report state, name, position, duration — there is no artist
    /// or album, so those come from `fallbackArtist` and `albumLabel`.
    public var fieldCount: Int {
        albumLabel == nil ? 6 : 4
    }

    // MARK: - Playback control

    /// The transport verbs this app understands, as AppleScript source.
    ///
    /// These used to be inline string literals in `MediaManager`'s three control
    /// methods, which meant the same three facts were restated per verb per app:
    /// `tell application "Music" to next track` and `tell application "VLC" to
    /// next` are *not* the same command, and the difference was invisible — it read
    /// as a copy-paste that happened to differ.
    ///
    /// Modelling it as an optional makes absence meaningful rather than a
    /// fall-through. QuickTime has no `next track` concept at all, and the old
    /// chain simply had no branch for it; here that is `controls == nil`, which the
    /// compiler keeps honest if a new app is added without deciding what it can do.
    public var controls: PlaybackControls? {
        switch self {
        case .music, .spotify:
            // Both expose the player-scoped verbs, and both spell them the same way.
            return PlaybackControls(
                owner: self,
                play: "tell application \"\(applicationName)\" to play",
                pause: "tell application \"\(applicationName)\" to pause",
                next: "tell application \"\(applicationName)\" to next track",
                previous: "tell application \"\(applicationName)\" to previous track",
                seekable: true
            )
        case .quickTime:
            // A document player, not a playlist: it has documents, and it has no
            // notion of a next track. `count of documents` guards the command so
            // that pressing play with nothing open is a no-op rather than an error.
            return PlaybackControls(
                owner: self,
                play: """
                tell application "\(applicationName)"
                    if (count of documents) > 0 then play document 1
                end tell
                """,
                pause: """
                tell application "\(applicationName)"
                    if (count of documents) > 0 then pause document 1
                end tell
                """,
                next: nil,
                previous: nil,
                seekable: true
            )
        case .vlc:
            // VLC's verbs are the bare ones, with no `track` noun.
            //
            // `seekable` is deliberately false even though VLC can seek: this path
            // is a *supplement* to the MediaRemote seek already sent above, which
            // covers every player macOS knows about. Adding a second, untestable
            // seek path for one app would be scope creep, not a fix — and it keeps
            // the behaviour identical to the `switch` this replaced.
            return PlaybackControls(
                owner: self,
                play: "tell application \"\(applicationName)\" to play",
                pause: "tell application \"\(applicationName)\" to pause",
                next: "tell application \"\(applicationName)\" to next",
                previous: "tell application \"\(applicationName)\" to previous",
                seekable: false
            )
        }
    }

    /// The AppleScript for one app's transport verbs.
    ///
    /// A verb is `nil` where the app has no such concept, which is a fact about
    /// the app rather than a missing implementation — the distinction matters,
    /// because an empty string here would be sent to the interpreter and fail at
    /// runtime.
    ///
    /// `setPosition` is a *method* rather than a stored closure so the type stays
    /// `Equatable` and so the seek script is a pure function of its argument —
    /// which is what makes it testable, and a closure property would block both.
    public struct PlaybackControls: Sendable, Equatable {
        public var play: String
        public var pause: String
        /// `nil` when the app has no notion of a next track (document players).
        public var next: String?
        public var previous: String?
        /// `nil` for apps with no seekable timeline in this vocabulary (VLC).
        public var seekable: Bool

        public init(
            owner: DesktopMediaApp,
            play: String,
            pause: String,
            next: String?,
            previous: String?,
            seekable: Bool
        ) {
            self.owner = owner
            self.play = play
            self.pause = pause
            self.next = next
            self.previous = previous
            self.seekable = seekable
        }

        /// The script that seeks to `seconds`, or `nil` if this app cannot seek here.
        ///
        /// Kept beside the verbs so the app name is interpolated from the same
        /// source as `play` and `pause`, rather than restated at the call site.
        public func setPosition(_ seconds: Double) -> String? {
            guard seekable else { return nil }
            switch owner {
            case .music, .spotify:
                return "tell application \"\(owner.applicationName)\" to set player position to \(seconds)"
            case .quickTime:
                return """
                tell application "\(owner.applicationName)"
                    if (count of documents) > 0 then
                        set current time of document 1 to \(seconds)
                    end if
                end tell
                """
            case .vlc:
                // Unreachable while `seekable` is false, but stated rather than
                // `unreachable`: adding a seekable VLC later must not silently
                // produce an empty script.
                return "tell application \"\(owner.applicationName)\" to set current time to \(seconds)"
            }
        }

        /// Which app these verbs belong to.
        public let owner: DesktopMediaApp
    }

    /// Whether this app reports an album of its own.
    private var reportsAlbum: Bool { albumLabel == nil }

    /// Splits a delimited response into its fields, **preserving empty fields**.
    ///
    /// `String.components(separatedBy:)` looks like the obvious choice and it looks
    /// wrong here, because a reader can reasonably assume it *drops* empty fields.
    /// It does not, and that is why this wrapper exists: the behaviour is
    /// load-bearing and non-obvious, so it is stated and pinned rather than left
    /// for the next reader to re-litigate.
    ///
    /// An empty title or artist makes AppleScript emit *consecutive* delimiters.
    /// Verified against the real interpreter (`osascript`, not by reasoning):
    ///
    ///     "playing" & "|||" & "" & "|||" & "" & "|||" & "Album"
    ///         => playing|||||||||Album      (9 pipes, not 6)
    ///
    /// and `components(separatedBy: "|||")` splits that into exactly
    /// `[playing, "", "", Album]` — the four fields the script meant. Empty fields
    /// are the *normal* case for an untitled file or an untagged track, not an edge
    /// case, and preserving them is what keeps position and duration on their own
    /// indices instead of sliding up one slot.
    ///
    /// A hand-rolled three-chars-at-a-time splitter was tried here first and removed:
    /// it produces identical output on every captured row (including a trailing empty
    /// field and the empty string), so it was ~10 lines of hand-rolled string walking
    /// that could only ever introduce a bug `components` does not have. The
    /// hand-piped fixtures in `DesktopMediaAppTests` are built by concatenating the
    /// same `& "|||" &` terms the script uses, so a future reader cannot repeat the
    /// mistake of writing a literal with too few pipes.
    static func fields(of output: String) -> [String] {
        output.components(separatedBy: PIPE_DELIMITER)
    }

    /// The delimiter every AppleScript response in this subsystem uses.
    ///
    /// One constant, so the script that emits a row and the code that splits it
    /// cannot drift apart. Long enough to be unlikely inside a track title, and a
    /// run of it collapses cleanly so consecutive empty fields still split.
    static let PIPE_DELIMITER = "|||"

    /// Parses a `|||`-delimited AppleScript response into a track.
    ///
    /// Pure, so the whole shape is unit-testable: field order, unit conversion, and
    /// the two different state vocabularies. Returns `nil` for `"stopped"`, for empty
    /// output, and for a short row — a truncated response must not produce a track
    /// with silently zeroed timings, which is how a media bug becomes an
    /// un-attributable "the island showed the wrong time" report.
    public static func parse(output: String, app: DesktopMediaApp) -> MediaTrack? {
        guard !output.isEmpty, output != "stopped" else { return nil }
        let parts = fields(of: output)
        guard parts.count >= app.fieldCount else { return nil }

        // Music and Spotify say "playing"/"paused"; the document players return a
        // boolean string. VLC's script only runs when playing, so its literal
        // "playing" is already handled by the first test.
        let state = parts[0].lowercased()
        let isPlaying = state.contains("playing") || state.contains("true")

        let title = parts[1].isEmpty ? app.fallbackTitle : parts[1]
        let position = Double(parts[app.reportsAlbum ? 4 : 2]) ?? 0
        let duration = (Double(parts[app.reportsAlbum ? 5 : 3]) ?? 0) * app.durationScale

        let artist: String
        let album: String
        if app.reportsAlbum {
            artist = parts[2].isEmpty ? app.fallbackArtist : parts[2]
            album = parts[3]
        } else {
            artist = app.fallbackArtist
            album = app.albumLabel ?? ""
        }

        return MediaTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            source: app.source,
            artworkData: nil,
            url: nil,
            bundleIdentifier: app.bundleIdentifier
        )
    }
}
