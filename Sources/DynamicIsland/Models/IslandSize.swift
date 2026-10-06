import Foundation
import CoreGraphics

/// The size of the opened island on a plugin tab.
///
/// `width` is the island's own width; `contentHeight` is the content region only.
/// The total height is *derived* by `AppState.expandedHeight`, which adds the notch
/// inset, a 38pt header, and 16pt of bottom padding. Storing the total would mean
/// storing a number that changes meaning the moment the island re-docks to a
/// display with a different notch, so two stored sizes could disagree about one
/// island (docs/DESIGN.md §1).
///
/// Deliberately free of AppKit, SwiftUI, and every global, so the clamp and the
/// drag geometry are pure functions of their parameters and the guard is the same
/// code the tests exercise (AGENTS.md §3).
public struct IslandSize: Codable, Equatable, Sendable {
    /// Island width in points.
    public var width: CGFloat
    /// Height of the content region in points, excluding the header and padding.
    public var contentHeight: CGFloat

    public init(width: CGFloat, contentHeight: CGFloat) {
        self.width = width
        self.contentHeight = contentHeight
    }

    // MARK: - Bounds

    /// Narrower than this and the tab bar cannot fit its pills.
    public static let minWidth: CGFloat = 420.0
    public static let maxWidth: CGFloat = 1200.0
    /// Shorter than this and the header, tab bar, and divider leave no content.
    public static let minContentHeight: CGFloat = 200.0
    public static let maxContentHeight: CGFloat = 900.0

    // MARK: - Clamping

    /// Brings both axes inside the bounds.
    ///
    /// Total and idempotent, so a stored size can be read on every launch without
    /// drifting a little further each time.
    ///
    /// This does **not** make an unusable size usable: `min(max(.nan, lo), hi)`
    /// propagates `NaN`, so a corrupt value must be rejected by `isUsable` before
    /// it reaches here. See `AppState.resolvedSize(for:)`.
    public static func clamp(_ size: IslandSize) -> IslandSize {
        IslandSize(
            width: min(max(size.width, minWidth), maxWidth),
            contentHeight: min(max(size.contentHeight, minContentHeight), maxContentHeight)
        )
    }

    /// Whether both axes are real, finite, positive numbers.
    ///
    /// Separate from `clamp` because clamping cannot repair a `NaN` or an infinity
    /// — it propagates them — and a zero or negative width draws nothing at all.
    /// A stored value that fails this is discarded in favour of the plugin's
    /// declared size, so a corrupt preference degrades to a working island rather
    /// than to an invisible one.
    public static func isUsable(_ size: IslandSize) -> Bool {
        size.width.isFinite && size.contentHeight.isFinite
            && size.width > 0 && size.contentHeight > 0
    }

    // MARK: - Drag geometry

    /// The size a drag produces, derived from the size the drag *started* at.
    ///
    /// Never accumulated. An implementation that added the translation to the
    /// current size on every change would make the result depend on how many
    /// frames the drag happened to produce, so a dropped frame would leave the
    /// island at the wrong size with no way back. Deriving from `start` makes the
    /// result a function of the total movement alone — the same rule
    /// `CompactEarMarquee` follows for the same reason.
    public static func resized(start: IslandSize, translation: CGSize) -> IslandSize {
        clamp(IslandSize(
            width: start.width + translation.width,
            contentHeight: start.contentHeight + translation.height
        ))
    }
}
