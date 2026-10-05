import Foundation

// MARK: - Compact Ear Marquee Geometry
//
// Pure geometry for the left ear's scrolling notification strip. This file imports
// nothing but Foundation on purpose: every function is a pure function of its
// parameters, so the rule that governs the strip is also the test surface
// (AGENTS.md §3). Nothing here reads the clock — callers pass `now` — so a test can
// evaluate any instant deterministically.
//
// The strip scrolls because the closed notch is a fixed 56pt surface (AGENTS.md §2.2).
// Content adapts; the ear never grows.

public enum CompactEarMarquee {

    /// How long a transient item stays on screen, matching the notification banner's
    /// own display duration so an item never outlives the alert that produced it.
    public static let transientLifetime: TimeInterval = 4.5

    /// Points per second the strip travels. Slow enough to read at a glance.
    public static let defaultSpeed: CGFloat = 22.0

    /// Horizontal slot reserved for one transient item, including its gap.
    public static let slotWidth: CGFloat = 46.0

    // MARK: - Travel

    /// Distance a single item has travelled since it entered.
    ///
    /// Derived from elapsed time and never accumulated. An accumulating
    /// `offset += dt` drifts by exactly the sum of every dropped frame and wedges
    /// outright when the app is backgrounded mid-scroll; deriving from `elapsed`
    /// makes both cases produce the correct position with no correction.
    public static func travel(elapsed: TimeInterval, speed: CGFloat) -> CGFloat {
        guard elapsed > 0 else { return 0 }
        return CGFloat(elapsed) * speed
    }

    /// True while a transient entered at `enteredAt` is still on screen.
    ///
    /// An item retires once its leading edge has cleared the viewport, which happens
    /// strictly before its `transientLifetime` expires at the default speed — the
    /// geometric bound is what governs, so a slower or faster speed cannot leave a
    /// stranded item or clip one mid-view.
    public static func isVisible(
        enteredAt: TimeInterval,
        now: TimeInterval,
        speed: CGFloat = defaultSpeed,
        viewportWidth: CGFloat,
        slotWidth: CGFloat = slotWidth
    ) -> Bool {
        let elapsed = now - enteredAt
        guard elapsed >= 0 else { return false }
        return travel(elapsed: elapsed, speed: speed) <= viewportWidth + slotWidth
    }

    // MARK: - Layout

    /// Horizontal position for each transient, given the times they entered.
    ///
    /// `enteredAt` must be ordered oldest-first. Every item moves at the same speed
    /// from the same left edge, so the natural spacing between two items is the
    /// distance travelled between their entries. When two arrive close enough that
    /// they would overlap, the later one is pushed to its predecessor's trailing
    /// edge instead — so a burst of simultaneous alerts stays legible rather than
    /// stacking into an unreadable pile.
    ///
    /// The returned positions are non-decreasing, which is the invariant the view
    /// relies on when it lays items out left to right.
    public static func positions(
        enteredAt: [TimeInterval],
        now: TimeInterval,
        speed: CGFloat = defaultSpeed,
        slotWidth: CGFloat = slotWidth
    ) -> [CGFloat] {
        var result: [CGFloat] = []
        result.reserveCapacity(enteredAt.count)

        var previousTrailing: CGFloat = -.infinity

        for entry in enteredAt {
            let elapsed = now - entry
            // A future entry time is a caller bug or a clock change; treat it as just
            // entered rather than projecting it off the left edge.
            let x = -slotWidth + travel(elapsed: max(0, elapsed), speed: speed)
            let placed = max(x, previousTrailing)
            result.append(placed)
            previousTrailing = placed + slotWidth
        }

        return result
    }

    // MARK: - Adaptation

    /// Whether a resident item must drop its digits and show a glyph instead.
    ///
    /// The ear is a fixed width, so a numeric readout competes for space it cannot
    /// have. When the row is already carrying a transient strip, a running countdown
    /// falls back to its ring rather than being clipped mid-glyph — content degrading
    /// is the sanctioned response to a surface that cannot grow (AGENTS.md §2.2).
    public static func prefersCompactResident(hasTransients: Bool, overflows: Bool) -> Bool {
        hasTransients && overflows
    }
}
