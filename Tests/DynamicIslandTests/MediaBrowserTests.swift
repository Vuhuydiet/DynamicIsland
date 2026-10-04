import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Browser registry
//
// The bundle-id → app-name mapping used to be written out four times across
// `MediaManager`, in four regions that nothing kept in step. The failure mode was
// silent and user-visible: a browser added to the detection chain but not the focus
// chain meant the island could read a track and then fail to focus its tab, which
// looks like a dead button rather than a missing registry entry.
//
// These tests pin the *invariants* that made the four copies diverge, not the
// individual names. A new browser that breaks the invariants fails here.

@Suite("Media browser registry")
struct MediaBrowserTests {

    @Test("Detection order covers every browser exactly once")
    func detectionOrderIsExhaustiveAndUnique() {
        // The bug this prevents: a browser present in `allCases` but missing from
        // `detectionOrder` would be permanently unreachable — added, typed, and
        // never consulted.
        #expect(MediaBrowser.detectionOrder.count == MediaBrowser.allCases.count)
        #expect(Set(MediaBrowser.detectionOrder) == Set(MediaBrowser.allCases))
    }

    @Test("Bundle identifiers are unique, so lookup is unambiguous")
    func bundleIdentifiersAreUnique() {
        let ids = MediaBrowser.allCases.map(\.bundleIdentifier)
        #expect(Set(ids).count == ids.count, "duplicate bundle id in \(ids)")
    }

    @Test("Every bundle id round-trips through the lookup")
    func bundleIdentifiersRoundTrip() {
        // A browser whose id does not resolve would be detectable but not focusable —
        // the exact split-brain this type exists to remove.
        for browser in MediaBrowser.allCases {
            #expect(MediaBrowser(bundleIdentifier: browser.bundleIdentifier) == browser)
        }
    }

    @Test("An app that is not a browser resolves to nil rather than guessing")
    func unknownBundleIdResolvesToNil() {
        #expect(MediaBrowser(bundleIdentifier: "com.apple.Music") == nil)
        #expect(MediaBrowser(bundleIdentifier: "com.spotify.client") == nil)
        #expect(MediaBrowser(bundleIdentifier: "") == nil)
        #expect(MediaBrowser(bundleIdentifier: "com.example.Chromeish") == nil)
    }

    @Test("Safari is the only browser with a different tab script vocabulary")
    func safariIsTheOnlyNonChromiumBrowser() {
        // This is the real per-browser API difference, and it is why `tabScriptStyle`
        // exists instead of a string comparison on the app name. If a future browser
        // needs a third vocabulary, it must be added to the enum rather than smuggled
        // in as a name that happens not to be "Safari".
        let nonChromium = MediaBrowser.allCases.filter { $0.tabScriptStyle != .chromium }
        #expect(nonChromium == [.safari])
        #expect(MediaBrowser.safari.tabScriptStyle == .safari)
    }

    @Test("No application name is blank, since each is interpolated into AppleScript")
    func applicationNamesAreUsable() {
        // Every `applicationName` lands inside `tell application "…"` / `tell
        // application '…'`. A blank one would produce a script that targets a
        // different app, or a syntax error, and neither is obvious from the UI.
        for browser in MediaBrowser.allCases {
            #expect(!browser.applicationName.isEmpty, "\(browser) has a blank app name")
            #expect(!browser.bundleIdentifier.isEmpty)
        }
        // Safari's name must be the plain one — a "Safari Technology Preview" style
        // variant would silently miss the running app.
        #expect(MediaBrowser.safari.applicationName == "Safari")
    }

    @Test("YouTube control injection is a subset of the browsers media can come from")
    func youTubeControlBrowsersAreDetectable() {
        // Injecting into a tab is a user-visible side effect, so this list is
        // deliberately narrow — but nothing in it may be a browser the island cannot
        // read media from, or the play/pause button would act on a tab it never
        // detected.
        for browser in MediaBrowser.youTubeControlBrowsers {
            #expect(MediaBrowser.detectionOrder.contains(browser), "\(browser) is not detectable")
        }
    }

    @Test("Media keywords are non-empty and free of duplicates")
    func mediaKeywordsAreWellFormed() {
        let keywords = MediaBrowser.mediaURLKeywords
        #expect(!keywords.isEmpty)
        #expect(Set(keywords).count == keywords.count, "duplicate keyword in \(keywords)")
        // These are interpolated into an AppleScript `URL contains "…"` clause, so a
        // keyword containing a quote would break the script for every browser.
        for keyword in keywords {
            #expect(!keyword.contains("\""), "\(keyword) contains a quote")
        }
    }
}
