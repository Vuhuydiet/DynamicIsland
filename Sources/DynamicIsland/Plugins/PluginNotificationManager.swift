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
    
    /// Notifications currently visible in the closed notch, oldest first.
    ///
    /// A list rather than a single optional: the previous `@Published var
    /// activeNotification: IslandNotification?` silently discarded the first alert
    /// when a second arrived, so two simultaneous messages showed one and the user
    /// never learned the other existed. Each entry retires on its own timer, so one
    /// expiring does not clear the rest.
    @Published public var activeNotifications: [IslandNotification] = []

    /// The most recent visible notification, for surfaces that show one at a time.
    public var activeNotification: IslandNotification? {
        activeNotifications.last
    }

    /// Upper bound on simultaneously visible alerts. Older entries are dropped, not
    /// queued, so a burst cannot grow the ear's content without limit.
    public static let maxActiveNotifications = 3

    /// Recent notification history
    @Published public var notificationHistory: [IslandNotification] = []

    private var dismissTimers: [UUID: Timer] = [:]
    private let displayDuration: TimeInterval = 4.5
    private var lastDispatchedTime: [String: Date] = [:]

    /// Tokens for the block-based distributed-notification observers installed in
    /// `init`. Held so `deinit` can unregister them.
    private var observationTokens: [any NSObjectProtocol] = []

    private init() {
        observationTokens = DistributedObservationTokens.observe([
            "com.dynamicisland.pluginNotification": { [weak self] notification in
                let title = notification.userInfo?["title"] as? String ?? "Notification"
                let body = notification.userInfo?["body"] as? String ?? ""
                let pluginId = notification.userInfo?["pluginId"] as? String ?? WebAppLegacyID.messenger
                self?.post(pluginId: pluginId, title: title, body: body)
            },
        ])
    }

    deinit {
        DistributedObservationTokens.remove(observationTokens)
        dismissTimers.values.forEach { $0.invalidate() }
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
        
        let resolvedTab = tab ?? .plugin(id: pluginId)
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

        // 2. Add to the in-notch live alerts. Oldest first, and capped: over the cap
        // the *oldest* entry goes, so the newest alert is always the one kept.
        withAnimation(IslandSpring.expand) {
            self.activeNotifications.append(notif)
            if self.activeNotifications.count > Self.maxActiveNotifications {
                let overflow = self.activeNotifications.removeFirst()
                dismissTimers[overflow.id]?.invalidate()
                dismissTimers[overflow.id] = nil
            }
        }

        // Store in history (max 30)
        self.notificationHistory.insert(notif, at: 0)
        if self.notificationHistory.count > 30 {
            self.notificationHistory.removeLast()
        }

        // 3. Per-item auto-dismiss. Each alert owns its timer, so one expiring
        // leaves the others alone instead of clearing the whole banner.
        let timer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.retire(notif.id)
            }
        }
        dismissTimers[notif.id] = timer

        // 4. Also post to native macOS notification center
        postToSystemNotificationCenter(notif)
    }

    /// Removes one alert, leaving any others visible.
    private func retire(_ id: UUID) {
        dismissTimers[id]?.invalidate()
        dismissTimers[id] = nil
        withAnimation(IslandSpring.collapse) {
            self.activeNotifications.removeAll { $0.id == id }
        }
    }

    /// Dismisses every visible alert in the notch.
    public func dismissActive() {
        dismissTimers.values.forEach { $0.invalidate() }
        dismissTimers.removeAll()
        withAnimation(IslandSpring.collapse) {
            self.activeNotifications.removeAll()
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
