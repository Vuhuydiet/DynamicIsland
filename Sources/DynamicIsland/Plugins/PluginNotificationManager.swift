import Foundation
import AppKit
import SwiftUI
import UserNotifications
import Combine

/// Standardized notification model for all Dynamic Island plugins and injected apps.
public struct IslandNotification: Identifiable, Equatable {
    public let id: UUID
    public let pluginId: String
    public let tab: IslandTab
    public let title: String
    public let body: String
    public let subtitle: String?
    public let timestamp: Date
    public let iconURL: URL?
    public let soundEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        pluginId: String,
        tab: IslandTab,
        title: String,
        body: String,
        subtitle: String? = nil,
        timestamp: Date = Date(),
        iconURL: URL? = nil,
        soundEnabled: Bool = true
    ) {
        self.id = id
        self.pluginId = pluginId
        self.tab = tab
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.iconURL = iconURL
        self.soundEnabled = soundEnabled
    }
}

/// Central manager for receiving, coordinating, and presenting notifications dispatched by plugins and web apps.
public class PluginNotificationManager: ObservableObject {
    public static let shared = PluginNotificationManager()
    
    /// Currently visible notification banner on the compact notch
    @Published public var activeNotification: IslandNotification?
    
    /// Recent notification history
    @Published public var notificationHistory: [IslandNotification] = []
    
    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 4.5
    private var lastDispatchedTime: [String: Date] = [:]
    
    private init() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.pluginNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let title = notification.userInfo?["title"] as? String ?? "Notification"
            let body = notification.userInfo?["body"] as? String ?? ""
            let pluginId = notification.userInfo?["pluginId"] as? String ?? MessengerPlugin.pluginID
            self?.post(pluginId: pluginId, title: title, body: body)
        }
    }
    
    /// Posts a notification to Dynamic Island from any plugin or tool.
    public func post(
        pluginId: String,
        tab: IslandTab? = nil,
        title: String,
        body: String,
        subtitle: String? = nil,
        iconURL: URL? = nil,
        soundEnabled: Bool = true
    ) {
        // Prevent rapid duplicate spamming (within 1.2s for identical title/body)
        let dedupeKey = "\(pluginId):\(title):\(body)"
        if let last = lastDispatchedTime[dedupeKey], Date().timeIntervalSince(last) < 1.2 {
            return
        }
        lastDispatchedTime[dedupeKey] = Date()
        
        let resolvedTab = tab ?? (pluginId == MessengerPlugin.pluginID ? .messenger : .plugin(id: pluginId))
        let notif = IslandNotification(
            pluginId: pluginId,
            tab: resolvedTab,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date(),
            iconURL: iconURL,
            soundEnabled: soundEnabled
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.displayNotification(notif)
        }
    }
    
    private func displayNotification(_ notif: IslandNotification) {
        // 1. Audio alert feedback — delegated to the plugin's own configured cue so
        // every plugin is individually muteable and re-themeable in Preferences.
        if notif.soundEnabled {
            SoundManager.shared.playPluginCue(.alert, pluginId: notif.pluginId)
        }
        
        // 2. Set active notification for in-notch live balloon animation
        withAnimation(IslandSpring.expand) {
            self.activeNotification = notif
        }
        
        // Store in history (max 30)
        self.notificationHistory.insert(notif, at: 0)
        if self.notificationHistory.count > 30 {
            self.notificationHistory.removeLast()
        }
        
        // 3. Schedule auto-dismiss for compact notch HUD banner
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(IslandSpring.collapse) {
                    if self?.activeNotification?.id == notif.id {
                        self?.activeNotification = nil
                    }
                }
            }
        }
        
        // 4. Also post to native macOS notification center
        postToSystemNotificationCenter(notif)
    }
    
    /// Dismisses any active notification banner currently shown in the notch.
    public func dismissActive() {
        dismissTimer?.invalidate()
        withAnimation(IslandSpring.collapse) {
            self.activeNotification = nil
        }
    }
    
    private func postToSystemNotificationCenter(_ notif: IslandNotification) {
        let content = UNMutableNotificationContent()
        content.title = notif.title.isEmpty ? "Dynamic Island" : notif.title
        if let sub = notif.subtitle, !sub.isEmpty {
            content.subtitle = sub
        }
        content.body = notif.body
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "pluginId": notif.pluginId,
            "tab": notif.tab.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: notif.id.uuidString,
            content: content,
            trigger: nil // immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[PluginNotificationManager] macOS notification error: \(error)")
            }
        }
    }
}
