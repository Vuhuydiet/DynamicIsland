import SwiftUI
import AppKit

// MARK: - Plugin Capabilities

/// Capability flags that a Dynamic Island plugin can declare.
public struct IslandPluginCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Supports custom/variable expanded height inside the opened island.
    public static let variableHeight   = IslandPluginCapabilities(rawValue: 1 << 0)
    /// Supports compact notch accessory when notch is closed (e.g. unread badge in ear).
    public static let compactAccessory = IslandPluginCapabilities(rawValue: 1 << 1)
    /// Provides dedicated configuration UI for Preferences -> Plugins.
    public static let customSettings   = IslandPluginCapabilities(rawValue: 1 << 2)
    /// Can receive and handle custom deep links (e.g. `dynamicisland://plugin/<id>`).
    public static let deepLinking      = IslandPluginCapabilities(rawValue: 1 << 3)
}

// MARK: - Island Plugin Protocol

/// Universal protocol for plugins that inject applications and tools into Dynamic Island.
public protocol IslandPlugin: AnyObject, Identifiable {
    /// Unique reverse-DNS identifier (e.g., "com.dynamicisland.plugin.messenger")
    var id: String { get }
    
    /// Human-readable display name shown in tab bar and settings (e.g. "Messenger")
    var name: String { get }
    
    /// SF Symbol icon name representing this plugin in the tab bar
    var icon: String { get }
    
    /// Short description of what this plugin provides
    var subtitle: String { get }
    
    /// Author / Developer / Vendor
    var author: String { get }
    
    /// Semantic version string (e.g. "1.0.0")
    var version: String { get }
    
    /// Capability flags
    var capabilities: IslandPluginCapabilities { get }
    
    /// Whether this plugin is currently enabled by the user
    var isEnabled: Bool { get set }
    
    /// Preferred viewport height when opened (defaults to 400.0pt for integrated apps, 170.0pt for compact tools)
    var preferredContentHeight: CGFloat { get }
    
    /// Optional preferred island width when opened (defaults to 740.0pt for integrated apps, nil for standard width)
    var preferredIslandWidth: CGFloat? { get }
    
    /// Optional dynamic badge for tab pill (e.g. unread count "3" or nil)
    var tabBadge: String? { get }
    
    /// ── Required sound contract ──────────────────────────────────────────────
    /// Audio defaults for this plugin's events. Declaring this on the protocol makes
    /// sound configuration a compile-time obligation: a new plugin cannot be registered
    /// without stating which cues it uses, and `SettingsManager` derives a persisted
    /// per-plugin override map from every registered plugin automatically.
    var defaultSoundProfile: IslandPluginSoundProfile { get }
    
    // MARK: - Lifecycle Hooks
    
    /// Invoked once when the plugin is registered with PluginManager.
    func onRegister()
    
    /// Invoked when the user activates/enables this plugin.
    func onEnable()
    
    /// Invoked when the user deactivates/disables this plugin.
    func onDisable()
    
    /// Invoked when the user switches to this plugin's tab in the opened island.
    func onTabSelected()
    
    /// Invoked when the user switches away or the island collapses.
    func onTabDeselected()
    
    // MARK: - View Providers
    
    /// Returns the main content view to display when this plugin's tab is active.
    @ViewBuilder
    func makeContentView() -> AnyView
    
    /// Returns an optional compact ear accessory to display in the closed notch (e.g. unread bubble).
    func makeCompactAccessory() -> AnyView?
    
    /// Returns an optional **text-free** status token for the closed-notch right ear.
    ///
    /// The right ear is a reserved, glanceable surface: only `RightEarToken` values are
    /// accepted, and every token is graphical except `battery`. This is the correct hook
    /// for plugins that want presence in the right ear (e.g. an unread dot). Use
    /// `makeCompactAccessory()` for the *left* ear, which does permit text.
    func compactStatusToken() -> RightEarToken?
    
    /// Returns an optional settings view for the Preferences window.
    func makeSettingsView() -> AnyView?
    
    /// Returns an optional custom icon view for tab bars and headers (e.g. multi-color app logo or NSImage).
    func makeIconView(size: CGFloat) -> AnyView?
}

// MARK: - Default Protocol Implementations

public extension IslandPlugin {
    var subtitle: String { "" }
    var author: String { "Dynamic Island Community" }
    var version: String { "1.0.0" }
    var capabilities: IslandPluginCapabilities { [] }
    var preferredContentHeight: CGFloat { 400.0 }
    var preferredIslandWidth: CGFloat? { 740.0 }
    var tabBadge: String? { nil }
    var defaultSoundProfile: IslandPluginSoundProfile { .standard }
    
    func onRegister() {}
    func onEnable() {}
    func onDisable() {}
    func onTabSelected() {}
    func onTabDeselected() {}
    func makeCompactAccessory() -> AnyView? { nil }
    func compactStatusToken() -> RightEarToken? { nil }
    func makeSettingsView() -> AnyView? { nil }
    func makeIconView(size: CGFloat) -> AnyView? { nil }
    
    /// Helper to query the official macOS app icon for an installed application bundle ID.
    static func appIcon(bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    /// Helper to query the official macOS app icon for an installed app path.
    static func appIcon(atPath path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
}
