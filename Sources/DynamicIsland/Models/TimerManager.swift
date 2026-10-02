import Foundation
import Combine
import AppKit
import UserNotifications

public enum TimerMode: String, CaseIterable, Identifiable {
    case timer = "Timer"
    case stopwatch = "Stopwatch"
    
    public var id: String { rawValue }
}

public class TimerManager: ObservableObject {
    public static let shared = TimerManager()
    
    @Published public var mode: TimerMode = .timer
    
    // Countdown Timer state
    @Published public var totalSeconds: Int = 300 // 5 mins default
    @Published public var remainingSeconds: Int = 300
    @Published public var isTimerRunning: Bool = false
    @Published public var isTimerPaused: Bool = false
    /// Set to true when the countdown reaches zero; cleared on start/reset/dismiss.
    @Published public var isTimerFinished: Bool = false
    
    // Stopwatch state
    @Published public var stopwatchElapsed: Double = 0.0
    @Published public var isStopwatchRunning: Bool = false
    @Published public var laps: [Double] = []
    
    private var countdownTimer: Timer?
    private var stopwatchTimer: Timer?
    private var alertRepeatTimer: Timer?
    private var stopwatchStartDate: Date?
    private var accumulatedStopwatchElapsed: Double = 0.0
    
    private init() {
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.bundleIdentifier != "com.apple.Terminal" else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[TimerManager] Notification auth error: \(error)")
            } else if !granted {
                print("[TimerManager] Notification permission denied.")
            }
        }
    }
    
    // MARK: - Countdown Timer Controls
    public func startTimer(seconds: Int? = nil) {
        if let sec = seconds {
            totalSeconds = sec
            remainingSeconds = sec
        }
        guard remainingSeconds > 0 else { return }
        
        isTimerRunning = true
        isTimerPaused = false
        isTimerFinished = false
        stopAlertRepeat()
        SoundManager.shared.play(.click)
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.timerFinished()
            }
        }
    }
    
    public func pauseTimer() {
        isTimerRunning = false
        isTimerPaused = true
        countdownTimer?.invalidate()
        SoundManager.shared.play(.click)
    }
    
    public func resumeTimer() {
        startTimer()
    }
    
    public func resetTimer() {
        countdownTimer?.invalidate()
        isTimerRunning = false
        isTimerPaused = false
        isTimerFinished = false
        remainingSeconds = totalSeconds
        stopAlertRepeat()
        SoundManager.shared.play(.click)
    }
    
    /// Dismiss the finished banner without resetting the timer.
    public func dismissFinished() {
        isTimerFinished = false
        stopAlertRepeat()
    }
    
    // MARK: - Alert helpers
    private func stopAlertRepeat() {
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
    }
    
    private func timerFinished() {
        countdownTimer?.invalidate()
        isTimerRunning = false
        isTimerPaused = false
        isTimerFinished = true
        
        DispatchQueue.main.async {
            AppState.shared.activeTab = .timer
        }
        
        // Play sound immediately, repeat 2 more times for prominence
        SoundManager.shared.play(.timerAlert)
        var repeatsLeft = 2
        alertRepeatTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            SoundManager.shared.play(.timerAlert)
            repeatsLeft -= 1
            if repeatsLeft <= 0 {
                self.alertRepeatTimer?.invalidate()
                self.alertRepeatTimer = nil
            }
        }
        
        // System notification
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.bundleIdentifier != "com.apple.Terminal" else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⏱ Timer Finished!"
        content.body = "Your \(formatDuration(totalSeconds)) timer has ended."
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "timer-finished-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[TimerManager] Notification error: \(error)")
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
    
    // MARK: - Stopwatch Controls
    public func startStopwatch() {
        guard !isStopwatchRunning else { return }
        isStopwatchRunning = true
        stopwatchStartDate = Date()
        SoundManager.shared.play(.click)
        
        stopwatchTimer?.invalidate()
        let t = Timer(timeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.stopwatchStartDate else { return }
            self.stopwatchElapsed = self.accumulatedStopwatchElapsed + Date().timeIntervalSince(start)
        }
        RunLoop.main.add(t, forMode: .common)
        stopwatchTimer = t
    }
    
    public func pauseStopwatch() {
        guard isStopwatchRunning else { return }
        isStopwatchRunning = false
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        if let start = stopwatchStartDate {
            accumulatedStopwatchElapsed += Date().timeIntervalSince(start)
            stopwatchElapsed = accumulatedStopwatchElapsed
        }
        stopwatchStartDate = nil
        SoundManager.shared.play(.click)
    }
    
    public func resetStopwatch() {
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        isStopwatchRunning = false
        stopwatchStartDate = nil
        accumulatedStopwatchElapsed = 0.0
        stopwatchElapsed = 0.0
        laps.removeAll()
        SoundManager.shared.play(.click)
    }
    
    public func addLap() {
        laps.insert(stopwatchElapsed, at: 0)
        SoundManager.shared.play(.click)
    }
    
    // MARK: - Formatted Strings
    public var formattedRemainingTime: String {
        let hours = remainingSeconds / 3600
        let mins = (remainingSeconds % 3600) / 60
        let secs = remainingSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    public var formattedStopwatchTime: String {
        let total = Int(stopwatchElapsed)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        let hundredths = Int((stopwatchElapsed.truncatingRemainder(dividingBy: 1.0)) * 100)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, mins, secs, hundredths)
        } else {
            return String(format: "%02d:%02d.%02d", mins, secs, hundredths)
        }
    }
    
    public var formattedCompactStopwatchTime: String {
        let total = Int(stopwatchElapsed)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        let tenths = Int((stopwatchElapsed.truncatingRemainder(dividingBy: 1.0)) * 10)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d.%d", mins, secs, tenths)
        }
    }
    
    public var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
}
