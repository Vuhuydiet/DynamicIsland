import Foundation
import SwiftUI
import Combine

/// Central registry and coordinator for Dynamic Island plugins and injected applications.
public class PluginManager: ObservableObject {
    public static let shared = PluginManager()
    
    @Published public private(set) var plugins: [any IslandPlugin] = []
    @Published public private(set) var activePlugins: [any IslandPlugin] = []
    
    private var isSetup = false
    
    private init() {}
    
    public func setup() {
        guard !isSetup else { return }
        isSetup = true
        // Web apps are data, not a hardcoded registration. `sync` builds one
        // `WebAppPlugin` per stored descriptor, so the seeded entry and anything the
        // user adds later are registered by the same call.
        WebAppRegistry.shared.sync()
    }
    
    // MARK: - App Icon Utilities
    
    /// Helper to query the official macOS app icon for an installed application bundle ID.
    public static func appIcon(bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    /// Helper to query the official macOS app icon for an installed app path.
    public static func appIcon(atPath path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    // MARK: - Registration
    
    public func register(plugin: any IslandPlugin) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else { return }
        plugins.append(plugin)
        plugin.onRegister()
        updateActivePlugins()
    }
    
    public func unregister(id: String) {
        if let idx = plugins.firstIndex(where: { $0.id == id }) {
            let plugin = plugins.remove(at: idx)
            plugin.onDisable()
            updateActivePlugins()
        }
    }
    
    public func plugin(for id: String) -> (any IslandPlugin)? {
        plugins.first(where: { $0.id == id })
    }
    
    public func isPluginEnabled(id: String) -> Bool {
        plugin(for: id)?.isEnabled ?? false
    }
    
    public func enablePlugin(id: String) {
        if let p = plugin(for: id) {
            p.isEnabled = true
            updateActivePlugins()
        }
    }
    
    public func disablePlugin(id: String) {
        if let p = plugin(for: id) {
            p.isEnabled = false
            updateActivePlugins()
        }
    }
    
    public func togglePlugin(id: String) {
        if let p = plugin(for: id) {
            p.isEnabled.toggle()
            updateActivePlugins()
        }
    }
    
    public func notifyPluginStateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateActivePlugins()
            self?.objectWillChange.send()
        }
    }
    
    private func updateActivePlugins() {
        activePlugins = plugins.filter { $0.isEnabled }
        objectWillChange.send()
    }
}
