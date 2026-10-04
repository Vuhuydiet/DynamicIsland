import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Which desktop app a track belongs to
//
// `MediaManager`'s three control methods each began with the same hand-written
// chain:
//
//     if currentTrack.source == .music || currentTrack.bundleIdentifier == "com.apple.Music" { … }
//     else if currentTrack.source == .spotify || currentTrack.bundleIdentifier == "com.spotify.client" { … }
//     else if currentTrack.source == .vlc || currentTrack.bundleIdentifier == "org.videolan.vlc" { … }
//
// Ten branches across three methods, each restating the same mapping. The `||` is
// the defect: it is a *disjunction*, so a track that claimed `source == .music`
// while carrying Spotify's bundle id satisfied the Music branch and was sent
// Music's `next track` — addressed to an app that was not playing.
//
// This is pinned as a pure function over two strings, because that is all the
// policy needs and because a live track cannot be constructed headlessly.

@Suite("Desktop app ownership resolution")
struct MediaManagerOwnershipTests {

    @Test("A known bundle id names the app, whatever the source claims")
    func bundleIdIsAuthoritative() {
        // The regression: with `||`, a contradictory source won by accident of
        // branch order. The id is what the OS actually reported, so it decides.
        #expect(
            MediaManager.desktopAppOwning(source: .music, bundleIdentifier: "com.spotify.client") == .spotify,
            "a Spotify id must resolve to Spotify even if the source says music"
        )
        #expect(
            MediaManager.desktopAppOwning(source: .vlc, bundleIdentifier: "com.apple.Music") == .music
        )
        #expect(
            MediaManager.desktopAppOwning(source: .spotify, bundleIdentifier: "org.videolan.vlc") == .vlc
        )
    }

    @Test("Every app's own id resolves back to that app")
    func everyAppRoundTrips() {
        for app in DesktopMediaApp.allCases {
            #expect(
                MediaManager.desktopAppOwning(source: .none, bundleIdentifier: app.bundleIdentifier) == app,
                "\(app.bundleIdentifier) should resolve to \(app)"
            )
        }
    }

    @Test("With no bundle id, the source is the only evidence available")
    func sourceIsUsedWhenNoIdIsReported() {
        // A MediaRemote track can arrive with no bundle id at all. The source is
        // then the best available answer, so it must still be used — resolving to
        // `nil` here would silently drop playback control for those tracks.
        #expect(MediaManager.desktopAppOwning(source: .music, bundleIdentifier: nil) == .music)
        #expect(MediaManager.desktopAppOwning(source: .quicktime, bundleIdentifier: nil) == .quickTime)
        // An empty string means "not reported", not "an app with a blank id".
        #expect(MediaManager.desktopAppOwning(source: .spotify, bundleIdentifier: "") == .spotify)
    }

    @Test("A browser or system NowPlaying track belongs to no desktop app")
    func nonDesktopSourcesOwnNoApp() {
        // These must return `nil` so the control chain falls through to MediaRemote
        // and the media-key fallback. Claiming an app here would send AppleScript to
        // an app that has nothing to do with the track.
        for source: MediaSource in [.youtube, .browser, .mediaRemote, .iina, .none] {
            #expect(
                MediaManager.desktopAppOwning(source: source, bundleIdentifier: nil) == nil,
                "\(source) should not resolve to a desktop app"
            )
        }
        // Even with a browser bundle id, no desktop app owns it.
        #expect(
            MediaManager.desktopAppOwning(source: .youtube, bundleIdentifier: "com.google.Chrome") == nil
        )
        // IINA is deliberately absent from `DesktopMediaApp`: it is detected via
        // MediaRemote and has no AppleScript adapter, so it must not claim a verb.
        #expect(MediaManager.desktopAppOwning(source: .iina, bundleIdentifier: "iina") == nil)
    }

    @Test("An unknown bundle id does not fall back to a wrong app")
    func unknownBundleIdResolvesToNil() {
        // The dangerous case: an app we do not know reports a track. Falling back to
        // the source alone could address the wrong player, because the source was
        // derived from metadata rather than from the app.
        #expect(
            MediaManager.desktopAppOwning(source: .music, bundleIdentifier: "com.example.Unknown") == nil
        )
        #expect(
            MediaManager.desktopAppOwning(source: .vlc, bundleIdentifier: "org.iina.iina") == nil
        )
    }

    @Test("Ownership is total: every resolution is an app that can accept the verb")
    func resolvedAppsAlwaysHaveControls() {
        // A resolved app with no control verbs would be a dead end the caller cannot
        // detect. This closes that gap: ownership implies drivability.
        for app in DesktopMediaApp.allCases {
            #expect(app.controls != nil, "\(app) is resolvable but has no controls")
        }
    }
}
