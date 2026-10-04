import Foundation

// MARK: - Sound Cues

/// A selectable system audio cue. Plugins pick defaults from this curated set and
/// users can override them per-plugin in Preferences → Sound Effects.
public enum IslandSoundCue: String, Codable, CaseIterable, Sendable {
    case pop, tink, blow, bottle, ping, glass
    case hero, morse, purr, funk, sosumi, submarine, frog, basso

    /// User-facing name shown in the cue picker.
    public var displayName: String {
        switch self {
        case .pop: return "Pop"
        case .tink: return "Tink"
        case .blow: return "Blow"
        case .bottle: return "Bottle"
        case .ping: return "Ping"
        case .glass: return "Glass"
        case .hero: return "Hero"
        case .morse: return "Morse"
        case .purr: return "Purr"
        case .funk: return "Funk"
        case .sosumi: return "Sosumi"
        case .submarine: return "Submarine"
        case .frog: return "Frog"
        case .basso: return "Basso"
        }
    }

    /// SF Symbol shown next to the cue in Preferences.
    public var symbolName: String {
        switch self {
        case .pop: return "bubble.left"
        case .tink: return "sparkle"
        case .blow: return "wind"
        case .bottle: return "waterbottle"
        case .ping: return "dot.radiowaves.left.and.right"
        case .glass: return "cup.and.saucer"
        case .hero: return "bolt.horizontal"
        case .morse: return "waveform"
        case .purr: return "cat"
        case .funk: return "music.note"
        case .sosumi: return "leaf"
        case .submarine: return "fish"
        case .frog: return "leaf.circle"
        case .basso: return "speaker.wave.2"
        }
    }

    /// Underlying `NSSound` name in /System/Library/Sounds.
    public var systemSoundName: String {
        rawValue.capitalized
    }
}

// MARK: - Plugin Sound Events

/// The audio events a plugin can emit. Iterating `allCases` lets the Preferences UI
/// render controls for *any* plugin without knowing its concrete type.
public enum IslandPluginSoundEvent: String, Codable, CaseIterable, Sendable {
    /// Incoming alert (chat message, notification, incoming event).
    case alert
    /// Discrete interaction (tab selected, action confirmed, refresh complete).
    case interaction

    public var displayName: String {
        switch self {
        case .alert: return "Incoming Alert"
        case .interaction: return "Interaction Click"
        }
    }

    public var subtitle: String {
        switch self {
        case .alert: return "Plays when the plugin raises a notification."
        case .interaction: return "Plays when the user interacts with the plugin."
        }
    }

    /// Key path to the cue this event resolves to inside a profile.
    public var cueKeyPath: WritableKeyPath<IslandPluginSoundProfile, IslandSoundCue> {
        switch self {
        case .alert: return \.alertCue
        case .interaction: return \.interactionCue
        }
    }
}

// MARK: - Plugin Sound Profile

/// Per-plugin audio configuration. Every `IslandPlugin` must declare a
/// `defaultSoundProfile`, and the user may override any field per plugin.
public struct IslandPluginSoundProfile: Codable, Equatable, Sendable {
    /// Per-plugin mute. Independent of the global `soundEffectsEnabled` master switch.
    public var isEnabled: Bool
    /// 0...1 multiplier applied on top of the global effects volume.
    public var volume: Double
    /// Cue used for `IslandPluginSoundEvent.alert`.
    public var alertCue: IslandSoundCue
    /// Cue used for `IslandPluginSoundEvent.interaction`.
    public var interactionCue: IslandSoundCue

    public init(
        isEnabled: Bool = true,
        volume: Double = 1.0,
        alertCue: IslandSoundCue = .ping,
        interactionCue: IslandSoundCue = .pop
    ) {
        self.isEnabled = isEnabled
        self.volume = min(max(volume, 0.0), 1.0)
        self.alertCue = alertCue
        self.interactionCue = interactionCue
    }

    /// Neutral profile used when a plugin id cannot be resolved to a registered plugin.
    public static let standard = IslandPluginSoundProfile()

    public func cue(for event: IslandPluginSoundEvent) -> IslandSoundCue {
        self[keyPath: event.cueKeyPath]
    }

    public mutating func setCue(_ cue: IslandSoundCue, for event: IslandPluginSoundEvent) {
        self[keyPath: event.cueKeyPath] = cue
    }
}
