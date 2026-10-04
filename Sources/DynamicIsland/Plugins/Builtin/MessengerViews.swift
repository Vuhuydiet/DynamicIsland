import SwiftUI
import AppKit
import WebKit

// MARK: - Messenger presentation layer
//
// These are the *views* half of the Messenger integration, split out of
// `MessengerPlugin.swift` so the plugin itself is only the integration contract.
//
// `IslandPlugin` already declares the seam that makes this split meaningful:
// `makeContentView`, `makeSettingsView`, and `makeIconView` are where a plugin hands
// over presentation. Keeping them in a separate file means a second plugin author
// copies ~220 lines of integration and zero lines of view code, instead of the 455
// this file used to be. Nothing here is referenced by the plugin logic except by the
// three `make…View` hooks, so the boundary is real rather than cosmetic.

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
