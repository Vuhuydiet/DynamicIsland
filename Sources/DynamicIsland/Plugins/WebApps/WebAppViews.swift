import SwiftUI
import AppKit
import WebKit

// MARK: - Web App presentation layer
//
// The views half of the web app integration, split from `WebAppPlugin.swift` so the
// plugin file is only the integration contract. Nothing here is app-specific: the
// header, the toolbar, and the settings card are all driven by the descriptor, so
// adding a site produces a complete UI with no new view code.

// MARK: - Content View

/// Renders one web app inside the opened island.
public struct WebAppContentView: View {
    @ObservedObject var plugin: WebAppPlugin
    @ObservedObject var controller: IslandWebController

    public init(plugin: WebAppPlugin) {
        self.plugin = plugin
        self.controller = plugin.webController
    }

    private var host: String {
        plugin.webController.configuration.initialURL.host ?? plugin.name
    }

    public var body: some View {
        VStack(spacing: 6) {
            IslandHeaderView(
                iconView: plugin.iconViewForHeader(),
                title: plugin.name,
                subtitle: controller.isLoading ? "Connecting to \(host)..." : host,
                statusBadge: nil,
                statusColor: .cyan
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
                    .help("Reload")

                    IslandButton(nil, icon: "arrow.up.right.square", variant: .secondary, size: .small) {
                        controller.openInExternalBrowser()
                    }
                    .help("Open in Safari / Default Browser")
                }
            }

            IslandCardView(cornerRadius: 10) {
                ZStack {
                    IslandWebViewHost(controller: controller)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if controller.isLoading && controller.estimatedProgress < 0.25 {
                        IslandEmptyStateView(
                            icon: "globe",
                            title: "Connecting to \(host)...",
                            subtitle: "Loading \(plugin.name)"
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

// MARK: - Settings Card

/// Per-web-app settings, shown in Preferences -> Plugins.
public struct WebAppSettingsCard: View {
    @ObservedObject var plugin: WebAppPlugin
    @State private var showingClearAlert = false
    @State private var draftName: String = ""

    public init(plugin: WebAppPlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                WebAppIconView(pluginId: plugin.id, symbol: plugin.icon, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name)
                        .font(IslandFont.title)
                        .foregroundColor(.white)
                    Text(plugin.webController.configuration.initialURL.host ?? "")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.50))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { plugin.isEnabled = $0 }
                ))
                .labelsHidden()
            }

            IslandDivider()

            HStack(spacing: 8) {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        WebAppStore.shared.rename(id: plugin.id, to: draftName)
                    }
                    .onAppear { draftName = plugin.name }

                IslandButton("Save", icon: "checkmark", variant: .secondary, size: .small) {
                    WebAppStore.shared.rename(id: plugin.id, to: draftName)
                }
            }

            HStack(spacing: 10) {
                IslandButton("Open in Browser", icon: "arrow.up.right", variant: .secondary, size: .small) {
                    plugin.webController.openInExternalBrowser()
                }

                IslandButton("Reload Page", icon: "arrow.clockwise", variant: .secondary, size: .small) {
                    plugin.webController.reload()
                }

                Spacer()

                IslandButton("Clear Cache", icon: "trash", variant: .danger, size: .small) {
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

// MARK: - Icon View

/// A web app's icon: a cached logo when one exists, otherwise its SF Symbol.
///
/// A user-added site has no authentic logo available, so the neutral globe is the
/// honest fallback — inventing a branded mark would be fabricating identity
/// (docs/DESIGN.md §7).
public struct WebAppIconView: View {
    let pluginId: String
    let symbol: String
    let size: CGFloat

    public init(pluginId: String, symbol: String, size: CGFloat) {
        self.pluginId = pluginId
        self.symbol = symbol
        self.size = size
    }

    public var body: some View {
        if let image = PluginIconManager.shared.icon(for: pluginId) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}

extension WebAppPlugin {
    /// The icon shown in the island header, preferring a cached logo.
    func iconViewForHeader() -> AnyView {
        AnyView(WebAppIconView(pluginId: id, symbol: icon, size: 18))
    }
}
