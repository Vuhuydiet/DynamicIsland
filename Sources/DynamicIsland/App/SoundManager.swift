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
        case notification
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
        case .notification:
            break
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
            case .notification: soundName = "Glass"
            }
        case .modern:
            switch type {
            case .expand: soundName = "Hero"
            case .collapse: soundName = "Morse"
            case .click: soundName = "Ping"
            case .drop: soundName = "Purr"
            case .timerAlert: soundName = "Ping"
            case .notification: soundName = "Hero"
            }
        case .subtle:
            switch type {
            case .expand: soundName = "Tink"
            case .collapse: soundName = "Tink"
            case .click: soundName = "Pop"
            case .drop: soundName = "Tink"
            case .timerAlert: soundName = "Ping"
            case .notification: soundName = "Tink"
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
    
    // MARK: - Plugin Audio
    
    /// Plays a plugin's configured cue for the given event.
    ///
    /// The plugin id is required rather than inferred so that notification audio is
    /// always attributed to the plugin that actually raised it. Both the global master
    /// toggle and the per-plugin mute are honoured, and the per-plugin volume is
    /// multiplied on top of the global effects volume.
    public func playPluginCue(_ event: IslandPluginSoundEvent, pluginId: String) {
        let settings = SettingsManager.shared
        guard settings.soundEffectsEnabled else { return }
        
        let profile = settings.soundProfile(forPlugin: pluginId)
        guard profile.isEnabled else { return }
        
        let cue = profile.cue(for: event)
        let volume = Float(min(1.0, max(0.0, settings.soundVolume * profile.volume)))
        guard volume > 0.0001 else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let sound = NSSound(named: cue.systemSoundName) else { return }
            sound.volume = volume
            sound.play()
        }
    }
}
