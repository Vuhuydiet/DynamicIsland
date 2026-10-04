import SwiftUI
import AppKit
import WebKit

/// Facebook Messenger Integration Plugin for Dynamic Island.
public class MessengerPlugin: ObservableObject, IslandPlugin {
    public static let shared = MessengerPlugin()
    public static let pluginID = "com.dynamicisland.plugin.messenger"
    
    public let id: String = MessengerPlugin.pluginID
    public let name: String = "Messenger"
    public let icon: String = "bubble.left.and.bubble.right.fill"
    public let subtitle: String = "Facebook Messenger chat inside the notch"
    public let author: String = "Meta / Dynamic Island"
    public let version: String = "1.0.0"
    
    public var capabilities: IslandPluginCapabilities {
        [.variableHeight, .compactAccessory, .customSettings]
    }
    
    private var isInitialized = false
    
    @Published public var isEnabled: Bool = true {
        didSet {
            guard isInitialized else { return }
            UserDefaults.standard.set(isEnabled, forKey: "plugin_\(id)_enabled")
            PluginManager.shared.notifyPluginStateChanged()
        }
    }
    
    public var preferredContentHeight: CGFloat {
        return 400.0
    }
    
    public var preferredIslandWidth: CGFloat? {
        return 740.0
    }
    
    public var tabBadge: String? {
        if webController.pageTitleUnreadCount > 0 {
            return "\(webController.pageTitleUnreadCount)"
        }
        return nil
    }
    
    /// Chat alerts use a bright double chime; tab entry stays a soft pop.
    public var defaultSoundProfile: IslandPluginSoundProfile {
        IslandPluginSoundProfile(
            isEnabled: true,
            volume: 0.9,
            alertCue: .ping,
            interactionCue: .pop
        )
    }
    
    // Dedicated Web Controller
    public private(set) var webController: IslandWebController!
    
    public static let messengerBlue = Color(red: 0.0, green: 0.52, blue: 1.0) // Facebook Messenger #0084FF
    
    private init() {
        let savedEnabled = UserDefaults.standard.object(forKey: "plugin_\(id)_enabled") as? Bool ?? true
        self.isEnabled = savedEnabled
        
        let css = """
        /* Hide bulky custom scrollbars and streamline view for notch panel */
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
        
        let config = IslandWebConfiguration(
            initialURL: URL(string: "https://www.messenger.com/")!,
            customUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            zoomFactor: 0.88,
            customCSS: css,
            customJS: nil,
            allowsBackForwardNavigationGestures: true
        )
        
        self.webController = IslandWebController(configuration: config)
        self.setupNotificationBridge()
        self.isInitialized = true
    }
    
    private func setupNotificationBridge() {
        webController.onNotificationReceived = { [weak self] title, body, icon in
            guard let self = self, self.isEnabled else { return }
            PluginNotificationManager.shared.post(
                pluginId: self.id,
                tab: .messenger,
                title: title.isEmpty ? "Messenger" : title,
                body: body.isEmpty ? "New message received" : body,
                subtitle: "Facebook Messenger",
                iconURL: icon.flatMap { URL(string: $0) },
                soundEnabled: true
            )
        }
        
        webController.onTitleNotificationTriggered = { [weak self] count, rawTitle in
            guard let self = self, self.isEnabled else { return }
            let title: String
            let body: String
            if rawTitle.contains(":") {
                let parts = rawTitle.split(separator: ":", maxSplits: 1).map(String.init)
                title = parts[0].trimmingCharacters(in: .whitespaces)
                body = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "New message"
            } else if !rawTitle.isEmpty && !rawTitle.lowercased().contains("messenger") {
                title = "Messenger"
                body = rawTitle
            } else {
                title = "Messenger"
                body = count == 1 ? "1 new unread message" : "\(count) new unread messages"
            }
            
            PluginNotificationManager.shared.post(
                pluginId: self.id,
                tab: .messenger,
                title: title,
                body: body,
                subtitle: "Facebook Messenger",
                soundEnabled: true
            )
        }
    }
    
    // MARK: - Lifecycle Hooks
    
    public func onRegister() {
        // Ready on app launch
    }
    
    public func onEnable() {
        PluginManager.shared.notifyPluginStateChanged()
    }
    
    public func onDisable() {
        PluginManager.shared.notifyPluginStateChanged()
    }
    
    public func onTabSelected() {
        // Refresh or restore view if needed
    }
    
    public func onTabDeselected() {
        // Idle state
    }
    
    // MARK: - App Icon Integration
    
    public static var installedAppIcon: NSImage? {
        let bundleIDs = [
            "com.facebook.archon",
            "com.facebook.messenger",
            "com.facebook.Messenger"
        ]
        for bid in bundleIDs {
            if let img = PluginManager.appIcon(bundleIdentifier: bid) {
                return img
            }
        }
        return nil
    }
    
    public func makeIconView(size: CGFloat) -> AnyView? {
        AnyView(MessengerAppIconView(size: size))
    }
    
    // MARK: - View Providers
    
    @ViewBuilder
    public func makeContentView() -> AnyView {
        AnyView(MessengerContentView(plugin: self))
    }
    
    public func makeCompactAccessory() -> AnyView? {
        guard webController.pageTitleUnreadCount > 0 else { return nil }
        
        return AnyView(
            HStack(spacing: 3) {
                MessengerAppIconView(size: 13)
                Text("\(webController.pageTitleUnreadCount)")
                    .font(IslandFont.metricNumeric)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MessengerPlugin.messengerBlue.opacity(0.4), lineWidth: 0.5))
        )
    }
    
    /// Right-ear presence is a text-free blue bolt while there are unread messages.
    /// The unread *count* itself lives on the left ear, where text is permitted.
    public func compactStatusToken() -> RightEarToken? {
        guard webController.pageTitleUnreadCount > 0 else { return nil }
        return .pluginIcon(systemName: icon)
    }
    
    public func makeSettingsView() -> AnyView? {
        AnyView(MessengerSettingsCard(plugin: self))
    }
}

