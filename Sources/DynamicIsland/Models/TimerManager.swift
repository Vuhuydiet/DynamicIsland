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
    
    // Stopwatch state
    @Published public var stopwatchElapsed: Double = 0.0
    @Published public var isStopwatchRunning: Bool = false
    @Published public var laps: [Double] = []
    
    private var countdownTimer: Timer?
    private var stopwatchTimer: Timer?
    
    private init() {
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleIdentifier != "com.apple.Terminal" else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        remainingSeconds = totalSeconds
        SoundManager.shared.play(.click)
    }
    
    private func timerFinished() {
        countdownTimer?.invalidate()
        isTimerRunning = false
        isTimerPaused = false
        SoundManager.shared.play(.timerAlert)
        
        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = "Dynamic Island Timer"
            content.body = "Your timer has completed!"
            content.sound = UNNotificationSound.default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    // MARK: - Stopwatch Controls
    public func startStopwatch() {
        isStopwatchRunning = true
        SoundManager.shared.play(.click)
        
        stopwatchTimer?.invalidate()
        stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.stopwatchElapsed += 0.1
        }
    }
    
    public func pauseStopwatch() {
        isStopwatchRunning = false
        stopwatchTimer?.invalidate()
        SoundManager.shared.play(.click)
    }
    
    public func resetStopwatch() {
        stopwatchTimer?.invalidate()
        isStopwatchRunning = false
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
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public var formattedStopwatchTime: String {
        let mins = Int(stopwatchElapsed) / 60
        let secs = Int(stopwatchElapsed) % 60
        let tenths = Int((stopwatchElapsed.truncatingRemainder(dividingBy: 1.0)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }
    
    public var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
}
