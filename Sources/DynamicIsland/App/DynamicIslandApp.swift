import AppKit
import SwiftUI
import UserNotifications

public class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    public static var shared: AppDelegate!
    public var statusItem: NSStatusItem?
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no dock icon, sits in menu bar & floating island)
        NSApp.setActivationPolicy(.accessory)
        
        // Become the UNUserNotificationCenter delegate so banners show while app is active
        UNUserNotificationCenter.current().delegate = self
        
        // Initialize window and notch detector
        _ = NotchDetector.shared
        WindowController.shared.setup()
        
        // Initialize timer manager (triggers notification permission request)
        _ = TimerManager.shared
        
        // Initialize settings controller to observe notifications
        _ = SettingsWindowController.shared
        
        // Setup menu bar extra
        setupStatusItem()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Show notification banners even when the app is in the foreground.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap – expand island to Timer tab.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            AppState.shared.expand(tab: .timer)
        }
        completionHandler()
    }
    
    // MARK: - Status Item
    
    public func updateStatusItemVisibility(_ isVisible: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isVisible {
                if self.statusItem == nil {
                    self.setupStatusItem()
                }
            } else {
                if let item = self.statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    self.statusItem = nil
                }
            }
        }
    }
    
    public func setupStatusItem() {
        guard SettingsManager.shared.showMenuBarIcon else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.image = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "Dynamic Island")?
                .withSymbolConfiguration(config)
            button.imagePosition = .imageOnly
        }
        
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.state = SettingsManager.shared.launchAtLogin ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Dynamic Island", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    @objc public func toggleIsland() {
        AppState.shared.toggleExpand()
    }
    
    @objc public func openSpecificTab(_ sender: NSMenuItem) {
        if let tab = sender.representedObject as? IslandTab {
            AppState.shared.expand(tab: tab)
        }
    }
    
    @objc public func openPreferences() {
        SettingsWindowController.shared.show()
    }
    
    @objc public func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !SettingsManager.shared.launchAtLogin
        SettingsManager.shared.setLaunchAtLogin(newState)
        sender.state = newState ? .on : .off
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        if let loginItem = menu.item(withTitle: "Launch at Login") {
            loginItem.state = SettingsManager.shared.launchAtLogin ? .on : .off
        }
    }

    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
