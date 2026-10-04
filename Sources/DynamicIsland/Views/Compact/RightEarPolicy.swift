import SwiftUI

// MARK: - Right Ear Token

/// A closed, text-free description of something the closed-notch **right ear** can show.
///
/// ## Why this is a token type instead of a `View`
///
/// The right ear sits immediately beside the camera notch and is read as a *glanceable
/// status* surface, not a reading surface. Historically, text leaked into it from many
/// independent sources: the live-activity `if/else` chain rendered `"Timer"`,
/// `"Paused"`, `"Stopwatch"`, `"Done!"` and `"L3"`, notification banners rendered
/// message bodies, and plugins could inject arbitrary strings through
/// `makeCompactAccessory()`.
///
/// A comment or a review checklist cannot prevent that, because the ear accepts
/// `AnyView` and any new branch can trivially reintroduce text. So the right ear does not
/// accept views at all — it accepts **only** the cases below, each of which is
/// graphical by construction:
///
/// - `battery` is the single deliberate exception: it renders the battery percentage,
///   a short fixed-width monospaced numeric readout.
/// - Every other case is a glyph, a ring, a bar, or a dot. There is no way to
///   construct one from a string, so there is no way for text to appear.
/// - A plugin wanting right-ear presence must return one of these tokens from
///   `compactStatusToken`; anything it cannot express simply does not render there.
///
/// Adding a new right-ear appearance therefore requires adding a `case` here, which
/// forces an explicit decision about whether that appearance is graphical. The set of
/// possible right-ear states is finite and auditable in one place.
public enum RightEarToken: Equatable, Sendable {
    /// Battery percentage + charging bolt. The one allowlisted text-bearing token.
    case battery
    /// Animated equalizer bars mirroring the active media session.
    case mediaVisualizer
    /// A pause glyph, shown when a media session is present but not playing.
    case mediaPauseGlyph
    /// Circular countdown ring for a running timer.
    case timerProgressRing
    /// Pulsing dot shown when a timer has completed.
    case timerDonePulse
    /// Flag glyph shown while a stopwatch has recorded laps.
    case stopwatchLapFlag
    /// Running/paused state dot for the stopwatch.
    case stopwatchStateDot
    /// Folder glyph shown when files are parked on the drop shelf.
    case dropShelfGlyph
    /// A plugin's own icon, with no accompanying label or message text.
    case pluginIcon(systemName: String)
    /// The notifying plugin's icon, shown while an alert banner is displayed.
    case notificationIcon(systemName: String)
    
    /// Tokens permitted to render a text glyph. Used by tests and by debug tooling
    /// to assert the "no text except battery" contract holds.
    public var isTextBearing: Bool {
        if case .battery = self { return true }
        return false
    }
}

// MARK: - Right Ear Policy

/// Code-enforced policy for the closed-notch right ear.
///
/// The policy is enforced by the *type* of the right-ear API (`RightEarToken`), by
/// `RightEarPolicy.sanitized(_:)`, which rejects any attempt to smuggle a view in, and
/// by `RightEarPolicy.token(for:)` being the only way the ear resolves its content.
public enum RightEarPolicy {
    /// Validates a token before it reaches the ear.
    ///
    /// Returns the token unchanged when it is permitted, or `nil` when the token would
    /// violate the contract. A nil result makes the ear fall back to the battery
    /// readout, so an unrecognised or malformed token degrades to something safe
    /// rather than leaking content.
    public static func sanitized(_ token: RightEarToken?) -> RightEarToken? {
        guard let token else { return nil }
        
        switch token {
        case .battery, .mediaVisualizer, .mediaPauseGlyph, .timerProgressRing,
             .timerDonePulse, .stopwatchLapFlag, .stopwatchStateDot, .dropShelfGlyph:
            return token
            
        case .pluginIcon(let systemName), .notificationIcon(let systemName):
            // Reject blank symbols — an empty `Image(systemName:)` renders a mystery box.
            let trimmed = systemName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                #if DEBUG
                print("[RightEarPolicy] Rejected right-ear token with a blank symbol name.")
                #endif
                return nil
            }
            return token
        }
    }
    
    /// The single sanctioned way to resolve what the right ear displays.
    ///
    /// Sanitising here means every render path is covered, including any added later,
    /// because callers cannot obtain an unsanitised token from this entry point.
    public static func token(for token: RightEarToken?) -> RightEarToken {
        sanitized(token) ?? .battery
    }
    
    /// Debug/test helper describing a contract violation, or `nil` when compliant.
    public static func violationDescription(for token: RightEarToken?) -> String? {
        guard let token else { return nil }
        switch token {
        case .battery:
            return nil
        case .mediaVisualizer, .mediaPauseGlyph, .timerProgressRing, .timerDonePulse,
             .stopwatchLapFlag, .stopwatchStateDot, .dropShelfGlyph:
            return nil
        case .pluginIcon(let systemName), .notificationIcon(let systemName):
            if systemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Right-ear icon token has a blank symbol name."
            }
            return nil
        }
    }
}
