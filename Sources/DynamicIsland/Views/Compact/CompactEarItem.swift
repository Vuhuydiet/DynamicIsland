import SwiftUI
import AppKit

/// One item's worth of content for the closed-notch left ear.
///
/// The left ear used to take `makeCompactAccessory() -> AnyView?`, which cannot
/// express a scrolling row: a marquee has to *measure* each item to place it, and a
/// view returned from a plugin is already laid out before the ear knows how much room
/// is left. Handing the ear data instead lets presentation own measurement and
/// animation, while a plugin only declares *what* it wants shown (AGENTS.md §2.4).
public struct CompactEarItem: Identifiable, Equatable {
    public enum Lifetime: Equatable {
        /// Present whenever its condition holds, and never scrolled away — a running
        /// countdown that drifts off the edge would expire unseen.
        case resident
        /// Enters at the left, travels right, and is retired once clear of the ear.
        case transient
    }

    public let id: String
    public let symbol: String?
    public let image: NSImage?
    public let text: String?
    public let tint: Color
    public let lifetime: Lifetime

    public init(
        id: String,
        symbol: String? = nil,
        image: NSImage? = nil,
        text: String? = nil,
        tint: Color = .white,
        lifetime: Lifetime = .transient
    ) {
        self.id = id
        self.symbol = symbol
        self.image = image
        self.text = text
        self.tint = tint
        self.lifetime = lifetime
    }

    public static func == (lhs: CompactEarItem, rhs: CompactEarItem) -> Bool {
        lhs.id == rhs.id
            && lhs.symbol == rhs.symbol
            && lhs.text == rhs.text
            && lhs.tint == rhs.tint
            && lhs.lifetime == rhs.lifetime
    }
}
