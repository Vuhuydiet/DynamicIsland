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
