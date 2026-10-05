import SwiftUI
import AppKit
import WebKit

/// The single `IslandPlugin` implementation behind every web app.
///
/// There is deliberately no per-app subclass. `MessengerPlugin` existed only because
/// one hardcoded site made a class look necessary; with the site as data, every web
/// app — seeded, typed by the user, or restored from a preset — takes this one path.
/// Per-app behaviour that cannot be derived from the descriptor does not belong here
/// at all; it belongs in the page.
public final class WebAppPlugin: ObservableObject, IslandPlugin {
    public let id: String
    public var name: String
    public var icon: String
    public var subtitle: String { "Web app inside the notch" }
    public var author: String { "Dynamic Island Community" }
    public var version: String { "1.0.0" }

    public var capabilities: IslandPluginCapabilities {
        [.variableHeight, .compactAccessory, .customSettings]
    }

    /// Backing data. Mutations go through `apply` so the descriptor stays the
    /// single source of truth rather than drifting from the live fields.
    public private(set) var descriptor: WebAppDescriptor

    public private(set) var webController: IslandWebController!

    public var isEnabled: Bool {
        get { descriptor.isEnabled }
        set {
            guard descriptor.isEnabled != newValue else { return }
            descriptor.isEnabled = newValue
            WebAppStore.shared.setEnabled(newValue, id: id)
        }
    }

    public init(descriptor: WebAppDescriptor) {
        self.descriptor = descriptor
        self.id = descriptor.id
        self.name = descriptor.name
        self.icon = WebAppPlugin.systemSymbol(for: descriptor)
        self.webController = IslandWebController(configuration: WebAppPlugin.configuration(for: descriptor))
        self.webController.onNotificationReceived = { [weak self] title, body, iconURL in
            self?.handleNotification(title: title, body: body, iconURL: iconURL)
        }
    }

    /// Re-points this plugin at an edited descriptor, rebuilding the web session
    /// only when the URL actually changed — a rename must not drop a live session.
    func apply(_ updated: WebAppDescriptor) {
        let urlChanged = updated.url != descriptor.url
        descriptor = updated
        name = updated.name
        if urlChanged {
            webController = IslandWebController(configuration: WebAppPlugin.configuration(for: updated))
            webController.onNotificationReceived = { [weak self] title, body, iconURL in
                self?.handleNotification(title: title, body: body, iconURL: iconURL)
            }
        }
        objectWillChange.send()
    }

    // MARK: - Derived configuration

    static func configuration(for descriptor: WebAppDescriptor) -> IslandWebConfiguration {
        IslandWebConfiguration(
            initialURL: descriptor.url,
            customUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            zoomFactor: 0.88,
            customCSS: Self.notchCSS,
            customJS: nil,
            allowsBackForwardNavigationGestures: true
        )
    }

    /// Thins out the page's own scrollbars so they don't fight the island's chrome.
    private static let notchCSS = """
    ::-webkit-scrollbar {
        width: 4px;
        height: 4px;
    }
    ::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.25);
        border-radius: 4px;
    }
    ::-webkit-scrollbar-track {
        background: transparent;
    }
    """

    /// A neutral SF Symbol. A web app has no authentic logo unless one was cached,
    /// and inventing a branded glyph would be fabricating identity (AGENTS.md §2.7).
    static func systemSymbol(for descriptor: WebAppDescriptor) -> String {
        "globe"
    }

    public var preferredContentHeight: CGFloat { 400.0 }
    public var preferredIslandWidth: CGFloat? { 740.0 }

    /// Never a fabricated count.
    ///
    /// The old Messenger badge parsed `(3) Alice: hi` out of the page title, which is
    /// page-controlled content — a URL the user typed could display an invented
    /// unread count. Unread presence is carried by the ear and the right-ear icon
    /// instead.
    public var tabBadge: String? { nil }

    public var defaultSoundProfile: IslandPluginSoundProfile {
        IslandPluginSoundProfile(isEnabled: true, volume: 0.9, alertCue: .ping, interactionCue: .pop)
    }

    // MARK: - Notifications

    /// Alerts only on a real `new Notification()` from the page.
    ///
    /// The HTML5 bridge stays, because a site asking permission and then firing a
    /// notification is the genuine article. The page-title heuristic is gone: it
    /// turned ordinary page text into a native macOS banner.
    private func handleNotification(title: String, body: String, iconURL: String?) {
        guard isEnabled else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        PluginNotificationManager.shared.post(
            pluginId: id,
            tab: .plugin(id: id),
            title: trimmedTitle.isEmpty ? name : trimmedTitle,
            body: body.isEmpty ? "New notification" : body,
            subtitle: name,
            iconURL: iconURL.flatMap { URL(string: $0) },
            soundEnabled: true
        )
    }

    // MARK: - Lifecycle

    public func onRegister() {
        // Fetched from the plugin's own lifecycle hook rather than from
        // `PluginManager.register`, so the manager never needs to know this plugin
        // type and the fetch stays attached to the object that has a URL.
        FaviconFetcher.fetchIfAbsent(for: descriptor, into: PluginIconManager.shared)
    }

    public func onEnable() { PluginManager.shared.notifyPluginStateChanged() }
    public func onDisable() { PluginManager.shared.notifyPluginStateChanged() }

    // MARK: - View Providers

    @ViewBuilder
    public func makeContentView() -> AnyView {
        AnyView(WebAppContentView(plugin: self))
    }

    /// Left-ear items for a live alert: the app's glyph plus the sender's name.
    ///
    /// Text is permitted on the left ear, and the sender is the one piece of
    /// information that makes an alert actionable, so the count is not needed.
    public func compactItems() -> [CompactEarItem] {
        guard let live = PluginNotificationManager.shared.activeNotification,
              live.pluginId == id else { return [] }

        return [CompactEarItem(
            id: "webapp-\(live.id.uuidString)",
            symbol: icon,
            image: PluginIconManager.shared.icon(for: id),
            text: live.title,
            tint: .white
        )]
    }

    public func compactStatusToken() -> RightEarToken? {
        guard let live = PluginNotificationManager.shared.activeNotification,
              live.pluginId == id else { return nil }
        return .notificationIcon(systemName: icon)
    }

    public func makeSettingsView() -> AnyView? {
        AnyView(WebAppSettingsCard(plugin: self))
    }
}
