import Testing
import Foundation
@testable import DynamicIsland

// MARK: - NowPlaying source classification
//
// `MediaSourceClassification` was extracted from a chain of string comparisons
// buried inside `buildMediaRemoteTrack`, a method that could only be reached with a
// live `dlopen`ed `MediaRemote` framework pointer in hand. That made the policy
// untestable, so the one piece of the media subsystem that is pure was the one
// piece with no coverage.
//
// These tests pin the *previous* behaviour exactly, quirks included. The point is
// not that the behaviour is right — one of these is surprising — but that changing
// it is now a deliberate, visible edit rather than an accident nobody can see.

@Suite("NowPlaying source classification")
struct MediaSourceClassificationTests {

    @Test("A known app's bundle id decides the source")
    func knownBundleIdsMapToTheirSource() {
        let cases: [(String, MediaSource)] = [
            ("com.apple.Music", .music),
            ("com.spotify.client", .spotify),
            ("com.apple.QuickTimePlayerX", .quicktime),
            ("org.videolan.vlc", .vlc),
        ]
        for (bundleId, expected) in cases {
            let result = MediaSourceClassification.classify(bundleId: bundleId, artist: "", title: "")
            #expect(result.source == expected, "\(bundleId) should be \(expected)")
        }
    }

    @Test("IINA is matched loosely, so its id may vary across releases")
    func iinaIsMatchedLoosely() {
        // IINA's bundle id has changed shape over releases. Substring matching is
        // deliberate; pinning the exact id would re-break IINA on its next rename.
        for bundleId in ["iina", "iina.mpv", "org.iina.iina", "xyz.iina-thing"] {
            #expect(
                MediaSourceClassification.classify(bundleId: bundleId, artist: "", title: "").source == .iina,
                "\(bundleId) should be iina"
            )
        }
    }

    @Test("A known app wins even when the metadata says YouTube")
    func knownAppOutranksYouTubeMetadata() {
        // The app chain is checked first, so a browser-adjacent bundle id that also
        // happens to contain a known id must not be reclassified.
        let result = MediaSourceClassification.classify(
            bundleId: "com.apple.Music", artist: "YouTube", title: "Some Video"
        )
        #expect(result.source == .music)
    }

    @Test("Chrome and Safari are classified as YouTube, not as browser")
    func chromiumAndSafariWithAnyContentBecomeYouTube() {
        // Surprising, and pre-existing: the YouTube test includes
        // `bundleId.contains("Chrome") || bundleId.contains("Safari")`, so *any*
        // track from these browsers is `.youtube` even with no YouTube in the
        // metadata. Pinned deliberately — see the type's doc comment.
        for bundleId in ["com.google.Chrome", "com.apple.Safari"] {
            let result = MediaSourceClassification.classify(
                bundleId: bundleId, artist: "Some Band", title: "A Song"
            )
            #expect(result.source == .youtube, "\(bundleId) should classify as youtube")
            #expect(result.fallbackArtist == "YouTube")
        }
    }

    @Test("A non-Chromium browser with no YouTube metadata is a generic web video")
    func otherBrowsersAreGenericBrowser() {
        for bundleId in ["com.brave.Browser", "company.thebrowser.Browser", "com.microsoft.edgemac"] {
            let result = MediaSourceClassification.classify(
                bundleId: bundleId, artist: "Some Band", title: "A Song"
            )
            #expect(result.source == .browser, "\(bundleId) should be browser")
            #expect(result.fallbackArtist == "Web Video")
        }
    }

    @Test("YouTube metadata alone is enough, whatever the app")
    func youTubeMetadataAloneIsEnough() {
        // No recognised browser id, but the artist or title says YouTube.
        #expect(MediaSourceClassification.classify(
            bundleId: "com.example.player", artist: "YouTube", title: "x"
        ).source == .youtube)
        #expect(MediaSourceClassification.classify(
            bundleId: "com.example.player", artist: "x", title: "Video - youtube"
        ).source == .youtube)
        // Case-insensitive, because app metadata casing is not dependable.
        #expect(MediaSourceClassification.classify(
            bundleId: "com.example.player", artist: "YOUTUBE", title: "x"
        ).source == .youtube)
    }

    @Test("An unrecognised app is system NowPlaying, with a real fallback artist")
    func unrecognisedAppFallsBackToMediaRemote() {
        let result = MediaSourceClassification.classify(
            bundleId: "com.example.unknown", artist: "", title: ""
        )
        #expect(result.source == .mediaRemote)
        #expect(result.fallbackArtist == "Now Playing")
    }

    @Test("Classification never overwrites an artist the system actually reported")
    func reportedArtistIsNeverReplaced() {
        // The fallback exists only to avoid a blank row. Overwriting a real artist
        // would mislabel the track — so `buildMediaRemoteTrack` applies the fallback
        // only when the reported artist is empty.
        let result = MediaSourceClassification.classify(
            bundleId: "com.google.Chrome", artist: "Real Artist", title: "Real Title"
        )
        #expect(result.source == .youtube)
        #expect(result.fallbackArtist == "YouTube")
        // i.e. the classifier reports what to use *if* the artist is blank; it is
        // the caller's job not to clobber a reported value. Assert the classifier
        // does not itself decide, so the intent is explicit.
        #expect(result.fallbackArtist != "Real Artist")
    }

    @Test("An empty bundle id does not crash and degrades to system NowPlaying")
    func emptyBundleIdIsSafe() {
        let result = MediaSourceClassification.classify(bundleId: "", artist: "", title: "")
        #expect(result.source == .mediaRemote)
    }
}
