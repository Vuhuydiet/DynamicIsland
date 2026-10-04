import Foundation

/// The browsers the island knows how to read media from, and the one place their
/// identity is written down.
///
/// ## Why this is a type
///
/// Adding browser support previously meant editing **three** unrelated regions of
/// `MediaManager`: the detection chain in `fetchWebVideoTrack`, the YouTube button
/// injector, and the tab-focus/activate chain in `openMediaPage` — which itself
/// carried a *fourth*, inline copy of the bundle-id → app-name mapping. Nothing
/// checked those four lists against each other, so a browser added to one was
/// silently missing from the others: the island could detect a track and then fail
/// to focus its tab, which reads to the user as a broken button.
///
/// The mapping is now data, in one place, and it is `CaseIterable` so a new browser
/// cannot be added without it appearing in every place the list is consumed. A
/// bundle id that is not in the list is not a supported browser, which is a
/// statement the compiler can now make (AGENTS.md §1.1, levels 1 and 2).
///
/// The `tabScriptStyle` is the genuinely per-browser difference: Safari exposes
/// `current tab of w` and `name of t`, while the Chromium family exposes
/// `active tab index` and `title of t`. That is a real API difference and is
/// modelled as a closed enum rather than a string comparison.
public enum MediaBrowser: String, CaseIterable, Sendable, Equatable {
    case chrome
    case safari
    case brave
    case arc
    case edge

    /// The bundle identifier, which is the only stable key for a running app.
    public var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .safari: return "com.apple.Safari"
        case .brave:  return "com.brave.Browser"
        case .arc:    return "company.thebrowser.Browser"
        case .edge:   return "com.microsoft.edgemac"
        }
    }

    /// The name to address the app by in AppleScript. This is what the user sees
    /// in Script Editor and what `tell application "…"` must match — it is *not*
    /// derivable from the bundle id (Arc is the obvious one).
    public var applicationName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .safari: return "Safari"
        case .brave:  return "Brave Browser"
        case .arc:    return "Arc"
        case .edge:   return "Microsoft Edge"
        }
    }

    /// Which AppleScript vocabulary this browser exposes.
    public var tabScriptStyle: TabScriptStyle {
        switch self {
        // Safari is the odd one out: it addresses tabs by object and spells the
        // title property `name`.
        case .safari: return .safari
        // Chrome, Brave, Arc, and Edge all descend from Chromium's AppleScript
        // dictionary and share one vocabulary.
        case .chrome, .brave, .arc, .edge: return .chromium
        }
    }

    /// Resolves a bundle identifier to a supported browser, or `nil` if this app is
    /// not a browser the island knows how to drive.
    public init?(bundleIdentifier: String) {
        guard let match = Self.allCases.first(where: { $0.bundleIdentifier == bundleIdentifier })
        else { return nil }
        self = match
    }

    public enum TabScriptStyle: Sendable, Equatable {
        /// Chromium family: `active tab index` (1-based, per window) and `title`.
        case chromium
        /// Safari: `current tab of w` and `name of t`.
        case safari
    }
}

// MARK: - Detection order

extension MediaBrowser {
    /// Browsers in the order they are consulted for a media track.
    ///
    /// Order is a deliberate policy, not an accident: Chromium browsers come first
    /// because they expose tabs to AppleScript reliably, then Safari. Preserve it
    /// when adding a browser — appending a Chromium variant to the end means it is
    /// only reached when every earlier browser has failed, which is correct, but
    /// inserting it early will make it shadow browsers the user actually has open.
    public static let detectionOrder: [MediaBrowser] = [
        .chrome, .safari, .brave, .arc, .edge,
    ]

    /// URL fragments that mark a tab as carrying media the island should report.
    ///
    /// Shared by every browser so that adding a site means editing one list rather
    /// than one per browser. `spotify.com` is here because Spotify's web player is
    /// a real page a user may be listening to even with the desktop app closed.
    public static let mediaURLKeywords: [String] = [
        "youtube.com", "youtu.be", "netflix.com", "twitch.tv",
        "vimeo.com", "soundcloud.com", "bilibili.com", "spotify.com",
    ]

    /// The subset consulted for the YouTube transport controls.
    ///
    /// Only the two browsers the media path can produce a YouTube `url` for are
    /// listed; injecting into a tab in every browser would be a user-visible side
    /// effect (clicking a button on a background tab) for no benefit.
    public static let youTubeControlBrowsers: [MediaBrowser] = [.chrome, .safari]
}
