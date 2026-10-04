import Foundation

/// Decides which `MediaSource` a system NowPlaying notification belongs to.
///
/// ## Why this is a pure function
///
/// The system `MediaRemote` bridge reports a track plus the **bundle identifier of
/// whichever app produced it**, and nothing else — no app name, no media kind, no
/// playback type. Turning that into "the user is listening to Spotify" is a
/// judgement call, and it was previously made inline in `buildMediaRemoteTrack` as a
/// chain of string comparisons on a bundle id.
///
/// That chain was untestable, because it sat in the middle of a method that also
/// needed a live `dlopen`ed framework pointer to have been reached at all. It is now
/// a pure function over two strings, so the whole policy is a headless unit test
/// (AGENTS.md §3: the guard and the test surface are the same code).
///
/// The judgement is genuinely ambiguous in places, and the previous behaviour is
/// preserved exactly — including the quirks, which are now documented and pinned
/// rather than accidentally load-bearing:
///
/// - A Chrome or Safari tab playing an ordinary web video is classified `.youtube`,
///   not `.browser`. That is deliberate but surprising, and predates this type.
/// - The YouTube test is `artist`/`title` containing "youtube" **or** the bundle id
///   containing Chrome or Safari, so it fires even when the metadata never says
///   "YouTube".
/// - Browser detection previously used a hand-typed list of *display-name* fragments
///   (`"Chrome"`, `"Safari"`, `"Brave"`, `"Arc"`, `"Edge"`) matched against the
///   bundle id. Three of those never matched anything: the real ids are
///   `com.brave.Browser`, `company.thebrowser.Browser`, and `com.microsoft.edgemac`,
///   none of which contain their fragment with that capitalisation. So a Brave, Arc,
///   or Edge tab was never reported as `.browser` — it fell through to
///   `.mediaRemote` and the island showed "Now Playing" with no source accent. It is
///   now matched against `MediaBrowser.bundleIdentifier`, the same list the rest of
///   the media path uses, so a browser cannot be known to one and unknown to the
///   other. Pinned by `MediaSourceClassificationTests`.
public enum MediaSourceClassification: Sendable, Equatable {

    /// The result of classifying a system NowPlaying report.
    public struct Result: Sendable, Equatable {
        /// The source the island should present the track as.
        public let source: MediaSource
        /// What to show as the artist when the report carried none.
        public let fallbackArtist: String

        public init(source: MediaSource, fallbackArtist: String) {
            self.source = source
            self.fallbackArtist = fallbackArtist
        }
    }

    /// Classifies a NowPlaying report.
    ///
    /// - Parameters:
    ///   - bundleId: The reporting app's bundle identifier, or `""` if unknown.
    ///   - artist: The reported artist, possibly empty.
    ///   - title: The reported track/tab title, possibly empty.
    /// - Returns: The source plus the artist to display when none was reported.
    public static func classify(bundleId: String, artist: String, title: String) -> Result {
        if let known = knownSource(forBundleId: bundleId) {
            return Result(source: known, fallbackArtist: "Now Playing")
        }

        let isKnownBrowser = MediaBrowser.allCases.contains { bundleId == $0.bundleIdentifier }
        let isYouTube = artist.lowercased().contains("youtube")
            || title.lowercased().contains("youtube")
            || bundleId.contains("Chrome")
            || bundleId.contains("Safari")

        if isYouTube {
            return Result(source: .youtube, fallbackArtist: "YouTube")
        } else if isKnownBrowser {
            return Result(source: .browser, fallbackArtist: "Web Video")
        }
        return Result(source: .mediaRemote, fallbackArtist: "Now Playing")
    }

    /// The bundle identifiers that name a specific app we drive directly.
    ///
    /// Order does not matter here: the ids are distinct, so this is a lookup rather
    /// than a chain of `else if`. `iina` is substring-matched because IINA's id has
    /// varied across releases (`iina`, `iina.mpv`, and org/re variants), and the
    /// previous code matched loosely on purpose to keep working across them.
    private static let knownBundleIds: [(contains: String, source: MediaSource)] = [
        ("com.apple.Music", .music),
        ("com.spotify.client", .spotify),
        ("com.apple.QuickTimePlayerX", .quicktime),
        ("org.videolan.vlc", .vlc),
        ("iina", .iina),
    ]

    private static func knownSource(forBundleId bundleId: String) -> MediaSource? {
        knownBundleIds.first { bundleId.contains($0.contains) }?.source
    }
}
