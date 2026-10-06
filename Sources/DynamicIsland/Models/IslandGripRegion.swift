import CoreGraphics

/// Which bottom corner of the island a resize grip occupies.
///
/// A closed enum rather than a `Bool`, because the corner decides **the sign of the
/// width change** and getting that wrong does not fail loudly — it produces an island
/// that mirrors the pointer instead of following it, which reads as "the drag is
/// inverted" rather than as a bug in the corner's arithmetic.
public enum IslandGripCorner: Sendable, CaseIterable, Equatable {
    /// The bottom-**left** corner.
    case bottomLeading
    /// The bottom-**right** corner.
    case bottomTrailing

    /// How a pointer movement becomes a change in island width.
    ///
    /// The island grows symmetrically about its panel centreline during the drag
    /// — both bottom edges move outward by the same amount — so the **width**
    /// change is always `|translation.width|` for an outward drag, regardless of
    /// which corner the user is holding. The corner only affects the *sign* of
    /// the translation, because a leftward pointer movement means "outward" at
    /// the leading corner and "inward" at the trailing one:
    ///
    ///   • Dragging the **right** corner outward (`width > 0`) widens the island.
    ///   • Dragging the **left** corner outward (`width < 0`) also widens the island,
    ///     so the sign is **inverted**.
    ///
    /// Height is the same for both corners because the island is top-anchored,
    /// not centre-anchored on that axis — both bottom corners drag downward to
    /// grow and upward to shrink.
    ///
    /// Why the function takes the corner at all: getting the sign wrong does not
    /// fail loudly — the island mirrors the drag instead of following it, which
    /// reads as "the drag feels off" rather than as a sign error. Pinning the
    /// mapping here, once, means no caller can pass an already-inverted delta by
    /// accident.
    public func widthChange(for translation: CGSize) -> CGFloat {
        switch self {
        case .bottomLeading:  return -translation.width
        case .bottomTrailing: return translation.width
        }
    }

    /// How a pointer movement becomes a change in the island's height.
    ///
    /// Identical for both corners because the island grows downward from a fixed top
    /// edge. Kept beside `widthChange` so the whole drag mapping is readable in one
    /// place, rather than one axis living here and the other in the view.
    public func heightChange(for translation: CGSize) -> CGFloat {
        translation.height
    }

    /// How far the island must be shifted sideways during a resize drag.
    ///
    /// The island is **always centre-anchored**, including during a drag — the two
    /// bottom edges are mirrors of each other and grow outward together. The pointer is
    /// a "grow or shrink by this much" knob, not a slice that pins one edge.
    ///
    /// That is the design that felt right on try: an island whose edges both move is
    /// the only one that reads as growing, and a centre-anchored growth is the only
    /// way to keep the layout balanced as it gets bigger. Pinning one edge and letting
    /// the other do the resize felt like dragging a clip that happened to have a
    /// shadow on the right — neither edge looked like it was *doing* anything.
    ///
    /// Centring also gives symmetric resize for free: dragging the trailing corner
    /// outward and dragging the leading corner outward produce identical islands, so
    /// the two grips are interchangeable. The user picks whichever corner is more
    /// convenient; the result is the same.
    ///
    /// `currentWidth` is the width the island has *already* reached, so the result is
    /// a pure function of the drag so far and re-derives correctly on every frame —
    /// including after a clamp. Returns `0` for a no-op drag, and the caller zeroes it
    /// when no drag is live so the island stays centred at rest.
    public static func horizontalOffset(
        startWidth: CGFloat,
        currentWidth: CGFloat,
        at corner: IslandGripCorner
    ) -> CGFloat {
        _ = corner  // symmetric: the corner does not affect the shift
        return 0
    }
}

/// The rectangle the island's resize grip occupies.
///
/// Pure geometry with no AppKit, SwiftUI, or globals, so the corner the grip claims
/// is a value the tests can pin rather than a rect each view hand-assembles
/// (AGENTS.md §3).
///
/// This type exists because of a sign error that disabled both unpin and the drag at
/// once while the glow rendered perfectly. The grip's hit region was written as
/// `y: 0`, which reads as the origin but is the island's **top** edge: SwiftUI's `y`
/// grows downward, so the bottom edge is `maxY`. The invisible hit region therefore
/// sat over the header, on the pin button, while the visible glow sat correctly at the
/// bottom corner. Nothing in the view looked wrong, which is what made it hard to see.
///
/// An explicit named constructor is the enforcement: a caller asks for a
/// `bottomLeading` or `bottomTrailing` corner and gets it, and a test can assert the
/// rect actually touches the matching bottom edge — the assertion that would have
/// failed on the old code.
public struct IslandGripRegion: Equatable, Sendable {
    /// The grip's side, in points.
    ///
    /// Large enough that the corner is findable by feel — nothing is drawn there, so
    /// the region *is* the affordance — and far smaller than the island, so it cannot
    /// shadow the header controls.
    public static let side: CGFloat = 64.0

    /// Which corner this region covers.
    public let corner: IslandGripCorner

    /// The grip's rect, guaranteed to touch the island's bottom edge and the side edge
    /// its corner names, and to lie wholly within the island.
    public let rect: CGRect

    /// The named bottom corner of `size`.
    public init(corner: IslandGripCorner, in size: CGSize) {
        // `min` so a very small island still yields a valid, non-negative rect inside
        // its bounds rather than one hanging off the edge.
        let side = min(Self.side, size.width, size.height)
        // Named for what they are, because the two are the whole bug: `y` grows
        // DOWNWARD here, so the island's bottom edge is its *maximum* y.
        let bottomEdge = size.height
        self.corner = corner
        rect = CGRect(
            x: corner == .bottomLeading ? 0 : size.width - side,
            y: bottomEdge - side,
            width: side,
            height: side
        )
    }
}
