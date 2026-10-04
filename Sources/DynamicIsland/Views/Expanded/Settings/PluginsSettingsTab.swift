import SwiftUI

// MARK: - Pane 8: Plugins & app integrations

// MARK: - Tab: Plugins & App Integrations

public struct PluginsSettingsTab: View {
    @ObservedObject var pluginManager = PluginManager.shared
    @ObservedObject var messenger = MessengerPlugin.shared
    // `currentZoom` (and the other web session state) is `@Published` on
    // `IslandWebController`, not on `MessengerPlugin`. Observing only the plugin
    // left the zoom readout frozen at its initial value: `setZoom` really did
    // apply `webView.pageZoom`, but no `objectWillChange` ever reached this view,
    // so the percentage never re-rendered. Observing the controller itself is
    // what makes the zoom buttons visibly respond.
    @ObservedObject private var messengerWeb = MessengerPlugin.shared.webController
    @ObservedObject var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Overview Card
            SettingsCard(
                title: "App Plugins & Injections",
                icon: "puzzlepiece.extension.fill",
                iconColor: .cyan,
                subtitle: "Extend your Dynamic Island by injecting chat apps, web services, and custom tools directly into the notch."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "app.badge.checkmark.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Standardized Plugin System")
                                .font(.system(size: 13, weight: .bold))
                            Text("Plugins use standardized island components, custom viewport heights, tab badges, and closed-notch ear accessories.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            
            // 2. Facebook Messenger Card
            SettingsCard(
                title: "Facebook Messenger",
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: MessengerPlugin.messengerBlue,
                subtitle: "Instant messaging directly inside the opened notch with persistent login, unread badges, and fast chat access."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        MessengerAppIconView(size: 38, withSquircle: true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Messenger for Notch")
                                    .font(.system(size: 13, weight: .bold))
                                Text("v1.0.0")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Text("Status: \(messenger.isEnabled ? "Active & Ready" : "Disabled") • Expanded Size: Large (740 × 400 pt)")
                                .font(.system(size: 11))
                                .foregroundColor(messenger.isEnabled ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $messenger.isEnabled)
                            .labelsHidden()
                    }
                    
                    if messenger.isEnabled {
                        Divider()
                        
                        HStack(spacing: 12) {
                            Button {
                                appState.expand(tab: .messenger)
                            } label: {
                                Label("Open Messenger in Notch", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MessengerPlugin.messengerBlue)
                            
                            Button {
                                messenger.webController.openInExternalBrowser()
                            } label: {
                                Label("Open in Browser", systemImage: "arrow.up.right")
                            }
                            
                            Button {
                                messenger.webController.reload()
                            } label: {
                                Label("Reload", systemImage: "arrow.clockwise")
                            }
                            
                            Button {
                                PluginNotificationManager.shared.post(
                                    pluginId: MessengerPlugin.pluginID,
                                    title: "Sarah Jenkins",
                                    body: "Hey! Did you see the new notification update?",
                                    subtitle: "Facebook Messenger"
                                )
                            } label: {
                                Label("Test Notification", systemImage: "bell.badge")
                            }
                            .help("Send a test notification banner to the notch")
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text("Zoom:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    messenger.webController.zoomOut()
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .help("Zoom Out")
                                
                                Text(String(format: "%.0f%%", messengerWeb.currentZoom * 100))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .frame(width: 40)
                                
                                Button {
                                    messenger.webController.zoomIn()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .help("Zoom In")
                            }
                            
                            Button(role: .destructive) {
                                messenger.webController.clearCache()
                            } label: {
                                Label("Log Out", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            // 3. Developer Integration Guide Card
            SettingsCard(
                title: "Inject Your Own App (Developer API)",
                icon: "chevron.left.forwardslash.chevron.right",
                iconColor: .purple,
                subtitle: "Integrate other web apps (Slack, WhatsApp, Discord, ChatGPT) or native tools using the IslandPlugin interface."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Implementing `IslandPlugin` or `IslandWebPlugin` takes under 20 lines of code:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("""
                    // Example: Injecting any web application into Dynamic Island
                    let config = IslandWebConfiguration(
                        initialURL: URL(string: "https://web.whatsapp.com/")!,
                        zoomFactor: 0.88
                    )
                    let controller = IslandWebController(configuration: config)
                    PluginManager.shared.register(plugin: myCustomPlugin)
                    """)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }
}
