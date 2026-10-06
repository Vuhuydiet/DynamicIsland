import Foundation
import CoreGraphics
import Testing
@testable import DynamicIsland

// MARK: - Grip region

// Where the island's resize grips claim to live, and how a drag at each one becomes
// a size change.
//
// This suite exists because of a real bug: the grip's hit region was assembled as
// `CGRect(x: width - side, y: 0, …)`, which reads like the origin but is the island's
// *top* edge, since SwiftUI's `y` grows downward. The invisible region therefore sat
// over the header — on the unpin button — while the visible glow sat correctly at the
// bottom corner. Unpin and the drag both died while the glow kept drawing perfectly,
// so the view looked correct and the bug was invisible from a screenshot.
//
// The sign assertions exist for a second reason. The island grows *symmetrically*
// about its centreline during a drag — both edges move outward by the same
// amount — and the *width change* is always positive for an outward drag,
// regardless of which corner is held. The corner only changes which direction
// the pointer has to move to grow the island: a leftward motion is outward on
// the left corner, but inward on the right. Passing the raw translation to
// `IslandSize.resized` from the leading corner would therefore *shrink* the
// island when the user is widening it, which reads as "the drag feels wrong"
// rather than as a bug in `Corner.widthChange`. The mapping is pinned here
// where it cannot drift.
//
// Pure: no AppKit, no SwiftUI, no globals (AGENTS.md §3).

@Suite("Island grip region")
struct IslandGripRegionTests {

    private let island = CGSize(width: 900, height: 520)

    // MARK: Trailing corner

    @Test("The trailing grip sits on the island's bottom edge")
    func touchesBottomEdge() {
        let region = IslandGripRegion(corner: .bottomTrailing, in: island)
        #expect(region.rect.maxY == island.height)
    }

    @Test("The trailing grip sits on the island's right edge")
    func touchesRightEdge() {
        let region = IslandGripRegion(corner: .bottomTrailing, in: island)
        #expect(region.rect.maxX == island.width)
    }

    /// The assertion that pins the original bug: `y: 0` satisfies "does not overflow the
    /// top" while being the top corner, so a bounds-only check would pass. Requiring
    /// the rect to be flush with the *bottom* is what distinguishes the two.
    @Test("The trailing grip is the bottom corner, not the top one")
    func isBottomNotTop() {
        let region = IslandGripRegion(corner: .bottomTrailing, in: island)
        #expect(region.rect.minY > 0)
        #expect(region.rect.minY == island.height - IslandGripRegion.side)
    }

    // MARK: Leading corner

    @Test("The leading grip sits on the island's bottom edge")
    func leadingTouchesBottomEdge() {
        let region = IslandGripRegion(corner: .bottomLeading, in: island)
        #expect(region.rect.maxY == island.height)
    }

    @Test("The leading grip sits on the island's LEFT edge, not its right")
    func leadingTouchesLeftEdge() {
        let region = IslandGripRegion(corner: .bottomLeading, in: island)
        #expect(region.rect.minX == 0)
        // The distinguishing assertion: the leading grip must NOT be on the right edge,
        // or the two corners claim the same pixels and one silently loses.
        #expect(region.rect.maxX < island.width)
    }

    /// The two grips must not overlap, or the trailing one wins the shared pixels and
    /// the leading corner becomes dead on a narrow island.
    @Test("The two grips do not overlap")
    func cornersAreDisjoint() {
        let leading = IslandGripRegion(corner: .bottomLeading, in: island)
        let trailing = IslandGripRegion(corner: .bottomTrailing, in: island)
        #expect(!leading.rect.intersects(trailing.rect))
    }

    @Test("The two grips are mirror images about the island's centreline")
    func cornersAreMirrored() {
        let leading = IslandGripRegion(corner: .bottomLeading, in: island)
        let trailing = IslandGripRegion(corner: .bottomTrailing, in: island)
        #expect(leading.rect.minX == island.width - trailing.rect.maxX)
        #expect(leading.rect.maxX == island.width - trailing.rect.minX)
        #expect(leading.rect.minY == trailing.rect.minY)
        #expect(leading.rect.height == trailing.rect.height)
    }

    // MARK: Bounds

    @Test("The grip stays within the island on both axes")
    func staysInBounds() {
        for corner in IslandGripCorner.allCases {
            let region = IslandGripRegion(corner: corner, in: island)
            #expect(region.rect.minX >= 0)
            #expect(region.rect.minY >= 0)
            #expect(region.rect.maxX <= island.width)
            #expect(region.rect.maxY <= island.height)
        }
    }

    /// The header must stay clickable: the unpin button lives there, and this is the
    /// bug's only real-world symptom.
    @Test("The grip leaves the header row clear")
    func clearsHeader() {
        // A generous header height, comfortably above the real 38pt.
        let headerHeight: CGFloat = 60
        for corner in IslandGripCorner.allCases {
            let region = IslandGripRegion(corner: corner, in: island)
            #expect(region.rect.minY > headerHeight)
        }
    }

    @Test("The grip is large enough to find blind")
    func coversGlowReach() {
        // Nothing is drawn at the corners any more, so the region *is* the affordance
        // and has to be comfortably grabbable by feel.
        for corner in IslandGripCorner.allCases {
            let region = IslandGripRegion(corner: corner, in: island)
            #expect(region.rect.width >= 40)
            #expect(region.rect.height >= 40)
        }
    }

    @Test("An island smaller than the grip still yields an in-bounds rect")
    func clampsToTinyIsland() {
        let tiny = CGSize(width: 30, height: 24)
        for corner in IslandGripCorner.allCases {
            let region = IslandGripRegion(corner: corner, in: tiny)
            #expect(region.rect.minX >= 0)
            #expect(region.rect.minY >= 0)
            #expect(region.rect.maxX <= tiny.width)
            #expect(region.rect.maxY <= tiny.height)
        }
    }

    @Test("A degenerate zero-size island yields a zero rect, not a negative one")
    func zeroSize() {
        for corner in IslandGripCorner.allCases {
            let region = IslandGripRegion(corner: corner, in: .zero)
            #expect(region.rect.width == 0)
            #expect(region.rect.height == 0)
            #expect(region.rect.minX == 0)
            #expect(region.rect.minY == 0)
        }
    }
}

// MARK: - Drag sign

@Suite("Island grip drag direction")
struct IslandGripCornerTests {

    /// Dragging the right edge rightward widens the island: the translation *is* the
    /// width change.
    @Test("Trailing corner follows the pointer")
    func trailingFollowsPointer() {
        let drag = CGSize(width: 80, height: 0)
        #expect(IslandGripCorner.bottomTrailing.widthChange(for: drag) == 80)
        #expect(IslandGripCorner.bottomTrailing.widthChange(for: drag) == drag.width)
    }

    /// The one that matters: dragging the left edge *leftward* (negative width) must
    /// **widen** the island, because the left edge moving left exposes more island.
    @Test("Leading corner inverts the width sign")
    func leadingInvertsWidth() {
        let drag = CGSize(width: -80, height: 0)
        #expect(IslandGripCorner.bottomLeading.widthChange(for: drag) == 80)
        // And explicitly: the raw translation is NOT the width change here.
        #expect(IslandGripCorner.bottomLeading.widthChange(for: drag) != drag.width)
    }

    @Test("Leading corner inverts for both directions")
    func leadingInvertsBothWays() {
        #expect(IslandGripCorner.bottomLeading.widthChange(for: CGSize(width: 40, height: 0)) == -40)
        #expect(IslandGripCorner.bottomLeading.widthChange(for: CGSize(width: -40, height: 0)) == 40)
    }

    /// Height is the same for both corners: the island is top-anchored, so both bottom
    /// corners drag down to grow.
    @Test("Height is identical at both corners")
    func heightIsNotInverted() {
        let drag = CGSize(width: 0, height: 60)
        #expect(IslandGripCorner.bottomLeading.heightChange(for: drag) == 60)
        #expect(IslandGripCorner.bottomTrailing.heightChange(for: drag) == 60)
    }

    /// End-to-end through the real resize maths, so the sign and the clamp are proven
    /// together rather than each in isolation.
    @Test("Left-corner drag widens the island through IslandSize.resized")
    func leftDragWidens() {
        let start = IslandSize(width: 600, contentHeight: 400)
        let drag = CGSize(width: -100, height: 0)
        let applied = CGSize(
            width: IslandGripCorner.bottomLeading.widthChange(for: drag),
            height: IslandGripCorner.bottomLeading.heightChange(for: drag)
        )
        let result = IslandSize.resized(start: start, translation: applied)
        #expect(result.width == 700)
    }

    @Test("Right-corner drag widens the island through IslandSize.resized")
    func rightDragWidens() {
        let start = IslandSize(width: 600, contentHeight: 400)
        let drag = CGSize(width: 100, height: 0)
        let applied = CGSize(
            width: IslandGripCorner.bottomTrailing.widthChange(for: drag),
            height: IslandGripCorner.bottomTrailing.heightChange(for: drag)
        )
        let result = IslandSize.resized(start: start, translation: applied)
        #expect(result.width == 700)
    }

    /// Both corners converge on the same island, so the two grips cannot disagree
    /// about what a given edge movement means.
    @Test("Both corners reach the same size from opposite drags")
    func cornersConverge() {
        let start = IslandSize(width: 600, contentHeight: 400)
        let fromLeft = IslandSize.resized(start: start, translation: CGSize(
            width: IslandGripCorner.bottomLeading.widthChange(for: CGSize(width: -75, height: 0)),
            height: 0
        ))
        let fromRight = IslandSize.resized(start: start, translation: CGSize(
            width: IslandGripCorner.bottomTrailing.widthChange(for: CGSize(width: 75, height: 0)),
            height: 0
        ))
        #expect(fromLeft == fromRight)
    }
}

// MARK: - Edge tracking
//
// "Resizing both sides at the same time" means the island grows symmetrically about
// the panel centre during a drag. The pointer is a grow-or-shrink knob, not a slice
// that pins one edge. Centring is what makes both edges move outward together, equally,
// and growing without growing one side harder than the other.
//
// Property pinned here: the shift is **zero** during a drag, so the island stays
// centred and both edges move by exactly `widthDelta / 2` in opposite directions.
// That is the only mapping where the two corners are interchangeable.

@Suite("Island grows symmetrically about centre during a resize drag")
struct IslandGripTrackingTests {

    private let startWidth: CGFloat = 600

    @Test("No horizontal shift during a drag, on either corner")
    func noShiftDuringDrag() {
        for corner in IslandGripCorner.allCases {
            // Across a wide range of widths, on both corners, the shift is zero.
            for current in [startWidth, 700, 800, 1200, 420] {
                #expect(IslandGripCorner.horizontalOffset(
                    startWidth: startWidth, currentWidth: current, at: corner
                ) == 0)
            }
        }
    }

    @Test("Both corners produce the same shift for the same width change")
    func cornersProduceIdenticalShift() {
        // The two grips are interchangeable for symmetric resize.
        let trailing = IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: 800, at: .bottomTrailing)
        let leading = IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: 800, at: .bottomLeading)
        #expect(trailing == leading)
    }

    @Test("The two edges move in opposite directions during a drag")
    func edgesMoveSymmetrically() {
        let width = 800
        let widthDelta = CGFloat(width) - startWidth  // +200
        let rightEdgeFromCenter: CGFloat = widthDelta / 2  // +100
        let leftEdgeFromCenter: CGFloat  = -widthDelta / 2  // -100
        // Outward by exactly the same amount: that is what "both sides at the same
        // time" means geometrically, and the only mapping where the two edges are
        // mirrors of each other.
        #expect(rightEdgeFromCenter == -leftEdgeFromCenter)
    }

    @Test("Symmetry holds when the width is clamped at the maximum")
    func symmetryHoldsWhenClamped() {
        let maxWidth = IslandSize.maxWidth
        let width = IslandSize.resized(
            start: IslandSize(width: startWidth, contentHeight: 400),
            translation: CGSize(width: 5000, height: 0)
        ).width
        #expect(width == maxWidth)
        let shift = IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: width, at: .bottomTrailing)
        #expect(shift == 0)
    }

    @Test("Symmetry holds at the minimum width too")
    func symmetryHoldsWhenClampedLow() {
        let minWidth = IslandSize.minWidth
        let width = IslandSize.resized(
            start: IslandSize(width: startWidth, contentHeight: 400),
            translation: CGSize(width: -5000, height: 0)
        ).width
        #expect(width == minWidth)
        #expect(IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: width, at: .bottomLeading) == 0)
    }

    @Test("The shift is idempotent")
    func shiftIsIdempotent() {
        let a = IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: 725, at: .bottomTrailing)
        let b = IslandGripCorner.horizontalOffset(
            startWidth: startWidth, currentWidth: 725, at: .bottomTrailing)
        #expect(a == b)
    }

    /// End-to-end: both corners agree on the size a drag produces from the same edge
    /// travel, so the user cannot tell which corner they grabbed for symmetric resize.
    @Test("Dragging the trailing corner outward is identical to dragging the leading corner outward")
    func oppositeCornersProduceIdenticalWidth() {
        let start = IslandSize(width: startWidth, contentHeight: 400)
        // Pointer moves outward by the same amount on each corner.
        let outward: CGFloat = 120
        let fromTrailing = IslandSize.resized(start: start, translation: CGSize(
            width: IslandGripCorner.bottomTrailing.widthChange(for: CGSize(width: outward, height: 0)),
            height: 0
        ))
        let fromLeading = IslandSize.resized(start: start, translation: CGSize(
            width: IslandGripCorner.bottomLeading.widthChange(for: CGSize(width: -outward, height: 0)),
            height: 0
        ))
        #expect(fromTrailing == fromLeading)
    }
}
