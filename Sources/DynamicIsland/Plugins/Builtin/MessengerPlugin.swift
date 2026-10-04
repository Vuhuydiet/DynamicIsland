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

// MARK: - Authentic Messenger Icon Geometry

/// Crisp mathematical lightning bolt shape inside the Facebook Messenger bubble.
public struct MessengerBoltShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.70, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.46))
        path.closeSubpath()
        
        return path
    }
}

/// Standalone authentic Facebook Messenger gradient logo with lightning bolt.
public struct MessengerLogoView: View {
    public var size: CGFloat
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public static let gradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.04, green: 0.82, blue: 1.00), location: 0.0), // #00D2FF Cyan
            .init(color: Color(red: 0.00, green: 0.52, blue: 1.00), location: 0.35), // #0084FF Messenger Blue
            .init(color: Color(red: 0.63, green: 0.22, blue: 0.98), location: 0.70), // #A137FA Purple
            .init(color: Color(red: 1.00, green: 0.35, blue: 0.55), location: 1.0)  // #FF598B Hot Pink
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
    
    public var body: some View {
        ZStack {
            Image(systemName: "bubble.left.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Self.gradient)
            
            MessengerBoltShape()
                .fill(Color.white)
                .frame(width: size * 0.52, height: size * 0.48)
                .offset(x: -size * 0.02, y: -size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// Official macOS App Icon style for Facebook Messenger (squircle or standalone logo).
public struct MessengerAppIconView: View {
    public var size: CGFloat
    public var withSquircle: Bool
    
    public init(size: CGFloat = 16, withSquircle: Bool = false) {
        self.size = size
        self.withSquircle = withSquircle
    }
    
    public var body: some View {
        if let directImg = PluginIconManager.shared.icon(for: MessengerPlugin.pluginID) {
            if withSquircle {
                Image(nsImage: directImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: size * 0.08, y: size * 0.04)
            } else {
                Image(nsImage: directImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        } else if withSquircle, let appImg = MessengerPlugin.installedAppIcon {
            Image(nsImage: appImg)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if withSquircle {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.95, green: 0.96, blue: 0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: size * 0.08, y: size * 0.04)
                
                MessengerLogoView(size: size * 0.74)
            }
            .frame(width: size, height: size)
        } else {
            MessengerLogoView(size: size)
        }
    }
}

// MARK: - Messenger Content View

public struct MessengerContentView: View {
    @ObservedObject var plugin: MessengerPlugin
    @ObservedObject var controller: IslandWebController
    
    public init(plugin: MessengerPlugin) {
        self.plugin = plugin
        self.controller = plugin.webController
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header Bar with Real App Icon
            IslandHeaderView(
                iconView: AnyView(MessengerAppIconView(size: 18, withSquircle: true)),
                title: "Messenger",
                subtitle: controller.isLoading ? "Connecting to chat..." : "Ready to chat",
                statusBadge: controller.pageTitleUnreadCount > 0 ? "\(controller.pageTitleUnreadCount) new" : nil,
                statusColor: MessengerPlugin.messengerBlue
            ) {
                HStack(spacing: 5) {
                    if controller.canGoBack {
                        IslandButton(nil, icon: "chevron.left", variant: .ghost, size: .small) {
                            controller.goBack()
                        }
                    }
                    
                    IslandButton(nil, icon: "minus.magnifyingglass", variant: .ghost, size: .small) {
                        controller.zoomOut()
                    }
                    .help("Zoom Out")
                    
                    IslandButton(nil, icon: "plus.magnifyingglass", variant: .ghost, size: .small) {
                        controller.zoomIn()
                    }
                    .help("Zoom In")
                    
                    IslandButton(nil, icon: "arrow.clockwise", variant: .ghost, size: .small) {
                        controller.reload()
                    }
                    .help("Reload Messenger")
                    
                    IslandButton(nil, icon: "arrow.up.right.square", variant: .secondary, size: .small) {
                        controller.openInExternalBrowser()
                    }
                    .help("Open in Safari / Default Browser")
                }
            }
            
            // Web View Host inside standard frosted card with generous margins
            IslandCardView(cornerRadius: 10) {
                ZStack {
                    IslandWebViewHost(controller: controller)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    if controller.isLoading && controller.estimatedProgress < 0.25 {
                        IslandEmptyStateView(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Connecting to Messenger...",
                            subtitle: "Loading your conversations and messages"
                        )
                        .background(Color.black.opacity(0.60))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Messenger Settings Card

public struct MessengerSettingsCard: View {
    @ObservedObject var plugin: MessengerPlugin
    @State private var showingClearAlert = false
    
    public init(plugin: MessengerPlugin) {
        self.plugin = plugin
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MessengerAppIconView(size: 34, withSquircle: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Facebook Messenger")
                        .font(IslandFont.title)
                        .foregroundColor(.white)
                    Text("Official web messenger integration for quick chatting")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.50))
                }
                
                Spacer()
                
                Toggle("", isOn: $plugin.isEnabled)
                    .labelsHidden()
            }
            
            IslandDivider()
            
            HStack(spacing: 10) {
                IslandButton("Open in Browser", icon: "arrow.up.right", variant: .secondary, size: .small) {
                    plugin.webController.openInExternalBrowser()
                }
                
                IslandButton("Reload Page", icon: "arrow.clockwise", variant: .secondary, size: .small) {
                    plugin.webController.reload()
                }
                
                Spacer()
                
                IslandButton("Log Out / Clear Cache", icon: "trash", variant: .danger, size: .small) {
                    plugin.webController.clearCache()
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
