import Foundation
import AppKit

public class SoundManager {
    public static let shared = SoundManager()
    
    private init() {}
    
    public enum SoundType: CaseIterable, Sendable {
        case expand
        case collapse
        case click
        case drop
        case timerAlert
        case notification
    }

    /// Resolves the system sound name for an event under a scheme.
    ///
    /// Extracted from `play(_:)` as a pure function so the scheme × event palette
    /// can be unit-tested without a running app, without `UserDefaults`, and without
    /// dispatching `NSSound` (AGENTS.md §3). The guard and the test surface are the
    /// same code: `play` is now only a caller that honours the settings toggles and
    /// then hands off here.
    ///
    /// The palettes are intentionally non-uniform — each scheme is a different
    /// character, so the same event deliberately resolves to different cues per
    /// scheme. `subtle` in particular collapses several events onto a single quiet
    /// cue. That is a decision, and `SoundManagerMappingTests` pins it.
    public static func systemSoundName(for type: SoundType, scheme: SoundScheme) -> String {
        switch scheme {
        case .classic:
            switch type {
            case .expand: return "Pop"
            case .collapse: return "Tink"
            case .click: return "Blow"
            case .drop: return "Bottle"
            case .timerAlert: return "Ping" // High-frequency crisp chime
            case .notification: return "Glass"
            }
        case .modern:
            switch type {
            case .expand: return "Hero"
            case .collapse: return "Morse"
            case .click: return "Ping"
            case .drop: return "Purr"
            case .timerAlert: return "Ping"
            case .notification: return "Hero"
            }
        case .subtle:
            switch type {
            case .expand: return "Tink"
            case .collapse: return "Tink"
            case .click: return "Pop"
            case .drop: return "Tink"
            case .timerAlert: return "Ping"
            case .notification: return "Tink"
            }
        }
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

        let soundName = Self.systemSoundName(for: type, scheme: settings.soundScheme)
        
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
