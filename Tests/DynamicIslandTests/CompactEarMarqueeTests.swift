import XCTest
import CoreGraphics
@testable import DynamicIsland

/// Guards the left ear's scrolling geometry.
///
/// The specific failure these exist to prevent is *drift*: an accumulating
/// `offset += dt` moves by the sum of every dropped frame, and a backgrounded app
/// delivers one enormous delta that wedges the strip. Deriving the offset from
/// elapsed time makes both cases produce the correct position with no correction,
/// which is only checkable if the function is pure — so it takes `now` as a
/// parameter and never reads the clock (AGENTS.md §3).
final class CompactEarMarqueeTests: XCTestCase {
    private let viewport: CGFloat = 56
    private let slot: CGFloat = 46
    private let speed = CompactEarMarquee.defaultSpeed

    // MARK: - Travel is derived, not accumulated

    func testTravelIsZeroBeforeEntry() {
        XCTAssertEqual(CompactEarMarquee.travel(elapsed: 0, speed: speed), 0)
        XCTAssertEqual(CompactEarMarquee.travel(elapsed: -3, speed: speed), 0)
    }

    func testTravelIsProportionalToElapsedTime() {
        XCTAssertEqual(CompactEarMarquee.travel(elapsed: 2, speed: 10), 20, accuracy: 0.001)
    }

    func testPositionAfterADroppedFrameMatchesUninterruptedRun() {
        // The real drift scenario: frames tick at 30fps, then the app stalls for
        // 2.5s and delivers one enormous delta. An accumulator that added each
        // delta would land somewhere different; a derived position cannot.
        let frame: TimeInterval = 1.0 / 30.0
        let start = 1_000.0

        // Reference: step every frame, accumulating deltas the way a naive
        // implementation would, but recomputing absolute position each step.
        var reference: CGFloat = 0
        var simulatedNow = start
        while simulatedNow < start + 3.0 {
            simulatedNow = min(start + 3.0, simulatedNow + frame)
            reference = CompactEarMarquee.travel(elapsed: simulatedNow - start, speed: speed)
        }

        // Actual: the same instant, reached in one step after a 2.5s stall.
        let afterStall = CompactEarMarquee.travel(elapsed: 3.0, speed: speed)
        XCTAssertEqual(afterStall, reference, accuracy: 0.0001, "A dropped frame must not shift the strip")
    }

    // MARK: - Layout

    func testFirstItemEntersFromTheLeftEdge() {
        let positions = CompactEarMarquee.positions(
            enteredAt: [100], now: 100, speed: speed, slotWidth: slot
        )
        XCTAssertEqual(positions[0], -slot, accuracy: 0.001)
    }

    func testPositionsAreNonDecreasing() {
        // The view lays items out left to right and relies on this ordering; an
        // out-of-order list would render a later alert behind an earlier one.
        let positions = CompactEarMarquee.positions(
            enteredAt: [100, 100.2, 101, 102.5],
            now: 103,
            speed: speed,
            slotWidth: slot
        )
        for (previous, next) in zip(positions, positions.dropFirst()) {
            XCTAssertLessThanOrEqual(previous, next)
        }
    }

    func testSimultaneousItemsDoNotOverlap() {
        // A burst must stay legible rather than stacking three items on one spot.
        // Each item is pushed to its predecessor's trailing edge, so the spacing is
        // exactly one slot regardless of how far the first has already travelled.
        let positions = CompactEarMarquee.positions(
            enteredAt: [100, 100, 100],
            now: 100.5,
            speed: speed,
            slotWidth: slot
        )
        XCTAssertEqual(positions[0], -slot + CompactEarMarquee.travel(elapsed: 0.5, speed: speed), accuracy: 0.001)
        XCTAssertEqual(positions[1] - positions[0], slot, accuracy: 0.001)
        XCTAssertEqual(positions[2] - positions[1], slot, accuracy: 0.001)
    }

    func testLaterItemsTrailTheFirstByTheDistanceTravelled() {
        let positions = CompactEarMarquee.positions(
            enteredAt: [100, 101],
            now: 102,
            speed: speed,
            slotWidth: slot
        )
        // 2s of travel for the first, 1s for the second, so the natural gap is 1s.
        // But a 1s gap (22pt) is narrower than a 46pt slot, so the anti-overlap
        // rule takes over and the second sits exactly one slot behind.
        XCTAssertEqual(positions[0], -slot + CompactEarMarquee.travel(elapsed: 2, speed: speed), accuracy: 0.001)
        XCTAssertEqual(positions[1] - positions[0], slot, accuracy: 0.001)
    }

    func testFutureEntryTimeIsTreatedAsJustArrived() {
        // A clock change or a bad timestamp must not project an item off-screen.
        let positions = CompactEarMarquee.positions(
            enteredAt: [200], now: 100, speed: speed, slotWidth: slot
        )
        XCTAssertEqual(positions[0], -slot, accuracy: 0.001)
    }

    func testEmptyInputProducesNoPositions() {
        XCTAssertTrue(CompactEarMarquee.positions(enteredAt: [], now: 100).isEmpty)
    }

    // MARK: - Retirement

    func testItemIsVisibleImmediatelyAfterEntry() {
        XCTAssertTrue(CompactEarMarquee.isVisible(
            enteredAt: 100, now: 100, speed: speed, viewportWidth: viewport, slotWidth: slot
        ))
    }

    func testItemRetiresOnlyOnceFullyClearOfTheEar() {
        // Retiring early would pop an alert off mid-read; retiring late would strand
        // it past the right edge. The geometric bound is viewport + one slot.
        let justVisible = CompactEarMarquee.isVisible(
            enteredAt: 0, now: 3.0, speed: speed, viewportWidth: viewport, slotWidth: slot
        )
        let gone = CompactEarMarquee.isVisible(
            enteredAt: 0, now: 10.0, speed: speed, viewportWidth: viewport, slotWidth: slot
        )
        XCTAssertTrue(justVisible)
        XCTAssertFalse(gone)
    }

    func testItemIsNotVisibleBeforeItExists() {
        XCTAssertFalse(CompactEarMarquee.isVisible(
            enteredAt: 200, now: 100, speed: speed, viewportWidth: viewport, slotWidth: slot
        ))
    }

    // MARK: - Adaptation

    func testCountdownKeepsItsDigitsWhenNothingElseIsPresent() {
        XCTAssertFalse(CompactEarMarquee.prefersCompactResident(hasTransients: false, overflows: false))
    }

    func testCountdownDropsToItsRingWhenTheStripOverflows() {
        // A numeric readout inside a moving strip is misread at a glance, and the
        // glyph is the sanctioned response to a surface that cannot grow.
        XCTAssertTrue(CompactEarMarquee.prefersCompactResident(hasTransients: true, overflows: true))
    }

    func testCountdownKeepsDigitsWhenStripFitsWithoutOverflow() {
        XCTAssertFalse(CompactEarMarquee.prefersCompactResident(hasTransients: true, overflows: false))
    }
}
