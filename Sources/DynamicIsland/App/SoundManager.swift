import Foundation
import AppKit

public class SoundManager {
    public static let shared = SoundManager()
    
    private init() {}
    
    public enum SoundType {
        case expand
        case collapse
        case click
        case drop
        case timerAlert
    }
    
    public func play(_ type: SoundType) {
        let settings = SettingsManager.shared
        guard settings.soundEffectsEnabled else { return }
        
        // Check per-event toggles
        switch type {
        case .expand:
            guard settings.soundOnExpand else { return }
        case .collapse:
            guard settings.soundOnCollapse else { return }
        case .click:
            guard settings.soundOnTabSwitch else { return }
        case .drop:
            guard settings.soundOnDrop else { return }
        case .timerAlert:
            guard settings.soundOnTimer else { return }
        }
        
        let soundName: String
        switch settings.soundScheme {
        case .classic:
            switch type {
            case .expand: soundName = "Pop"
            case .collapse: soundName = "Tink"
            case .click: soundName = "Blow"
            case .drop: soundName = "Bottle"
            case .timerAlert: soundName = "Ping" // High-frequency crisp chime
            }
        case .modern:
            switch type {
            case .expand: soundName = "Hero"
            case .collapse: soundName = "Morse"
            case .click: soundName = "Ping"
            case .drop: soundName = "Purr"
            case .timerAlert: soundName = "Ping" // Increased from low-frequency Submarine to high-frequency Ping
            }
        case .subtle:
            switch type {
            case .expand: soundName = "Tink"
            case .collapse: soundName = "Tink"
            case .click: soundName = "Pop"
            case .drop: soundName = "Tink"
            case .timerAlert: soundName = "Ping"
            }
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let sound = NSSound(named: soundName) else { return }
            sound.volume = Float(max(0.0, min(1.0, settings.soundVolume)))
            sound.play()
        }
    }
    
    /// Plays an urgent, high-frequency double-chime pulse for timer alerts
    public func playTimerAlertPulse() {
        play(.timerAlert)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.14) { [weak self] in
            self?.play(.timerAlert)
        }
    }
}
