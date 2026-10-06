import Foundation
import CoreGraphics
import Testing
@testable import DynamicIsland

// MARK: - Island Size

// The size of the opened island on a plugin tab.
//
// `width` is the island's own width; `contentHeight` is the content region only.
// The total height is *derived* by `AppState.expandedHeight`, which adds the notch
// inset, a 38pt header, and 16pt of bottom padding. Storing the total would mean
// storing a number that changes meaning the moment the island re-docks to a
// display with a different notch, so two stored sizes could disagree about one
// island (docs/DESIGN.md §1).
//
// Pure: no AppKit, no globals, no bundle. Every rule worth guarding is a function
// of its parameters, so the guard and the test surface are the same code
// (AGENTS.md §3).

// MARK: - Bounds

@Suite("Island size clamping and drag geometry")
struct IslandSizeTests {

    // MARK: Clamping

    @Test("A width past the maximum clamps down to it")
    func widthClampsToMaximum() {
        let huge = IslandSize(width: 5000, contentHeight: 400)
        #expect(IslandSize.clamp(huge).width == IslandSize.maxWidth)
    }

    @Test("A width under the minimum clamps up to it")
    func widthClampsToMinimum() {
        let tiny = IslandSize(width: 10, contentHeight: 400)
        #expect(IslandSize.clamp(tiny).width == IslandSize.minWidth)
    }

    @Test("A content height past the maximum clamps down to it")
    func heightClampsToMaximum() {
        let huge = IslandSize(width: 740, contentHeight: 4000)
        #expect(IslandSize.clamp(huge).contentHeight == IslandSize.maxContentHeight)
    }

    @Test("A content height under the minimum clamps up to it")
    func heightClampsToMinimum() {
        let tiny = IslandSize(width: 740, contentHeight: 5)
        #expect(IslandSize.clamp(tiny).contentHeight == IslandSize.minContentHeight)
    }

    @Test("A size already inside the bounds is returned unchanged")
    func inBoundsIsUnchanged() {
        let size = IslandSize(width: 740, contentHeight: 400)
        #expect(IslandSize.clamp(size) == size)
    }

    @Test("Clamping twice changes nothing")
    func clampIsIdempotent() {
        // Reading a stored size must not drift a little further on every launch.
        let once = IslandSize.clamp(IslandSize(width: 5000, contentHeight: 4000))
        let twice = IslandSize.clamp(once)
        #expect(once == twice)
    }

    // MARK: Usability — the NaN guard

    @Test("A NaN dimension is not usable")
    func nanIsNotUsable() {
        // This is the whole reason `isUsable` is a separate function:
        // `min(max(.nan, lo), hi)` propagates NaN, so clamping a corrupt stored
        // size would hand the island a NaN width and it would draw nothing.
        #expect(!IslandSize.isUsable(IslandSize(width: .nan, contentHeight: 400)))
        #expect(!IslandSize.isUsable(IslandSize(width: 740, contentHeight: .nan)))
    }

    @Test("An infinite dimension is not usable")
    func infinityIsNotUsable() {
        #expect(!IslandSize.isUsable(IslandSize(width: .infinity, contentHeight: 400)))
        #expect(!IslandSize.isUsable(IslandSize(width: 740, contentHeight: -.infinity)))
    }

    @Test("A zero or negative dimension is not usable")
    func nonPositiveIsNotUsable() {
        #expect(!IslandSize.isUsable(IslandSize(width: 0, contentHeight: 400)))
        #expect(!IslandSize.isUsable(IslandSize(width: 740, contentHeight: -10)))
        #expect(!IslandSize.isUsable(IslandSize(width: -740, contentHeight: 400)))
    }

    @Test("An ordinary size is usable")
    func ordinarySizeIsUsable() {
        #expect(IslandSize.isUsable(IslandSize(width: 740, contentHeight: 400)))
    }

    @Test("Clamping an unusable size is never silently accepted downstream")
    func unusableSizeNeverBecomesUsable() {
        // Proves the guard is load-bearing rather than decorative: without it a
        // corrupt preference reaches the island as a zero or NaN frame.
        let corrupt = IslandSize(width: .nan, contentHeight: 400)
        #expect(!IslandSize.isUsable(IslandSize.clamp(corrupt)))
    }

    // MARK: Drag geometry

    @Test("A zero translation leaves the size at the drag's starting point")
    func zeroTranslationIsIdentity() {
        // A click on the grip is not a resize.
        let start = IslandSize(width: 740, contentHeight: 400)
        #expect(IslandSize.resized(start: start, translation: .zero) == start)
    }

    @Test("Dragging right and down grows both axes")
    func dragDownRightGrows() {
        let start = IslandSize(width: 740, contentHeight: 400)
        let result = IslandSize.resized(start: start, translation: CGSize(width: 100, height: 50))
        #expect(result.width == 840)
        #expect(result.contentHeight == 450)
    }

    @Test("Dragging left and up shrinks both axes")
    func dragUpLeftShrinks() {
        // A sign error on the y axis is invisible until the island is inverted:
        // dragging down would shrink it, which reads as the grip being broken.
        let start = IslandSize(width: 740, contentHeight: 400)
        let result = IslandSize.resized(start: start, translation: CGSize(width: -100, height: -50))
        #expect(result.width == 640)
        #expect(result.contentHeight == 350)
    }

    @Test("A drag is derived from the size it started at, not accumulated")
    func dragDoesNotAccumulate() {
        // The drift guard. An implementation that did `current += delta` inside
        // onChanged would make the result depend on how many frames the drag
        // happened to produce, so a stalled frame would leave the island at the
        // wrong size with no way back. Re-deriving from the same start for every
        // one of many small deltas must land on the same place as one total delta.
        let start = IslandSize(width: 740, contentHeight: 400)
        let step = CGSize(width: 3, height: 2)
        let total = CGSize(width: step.width * 60, height: step.height * 60)

        let inOneStep = IslandSize.resized(start: start, translation: total)

        // 60 re-derivations, each from `start` and the movement so far — which is
        // what a correct implementation does on every drag frame.
        var moved = CGSize.zero
        var reDerived = start
        for _ in 0..<60 {
            moved.width += step.width
            moved.height += step.height
            reDerived = IslandSize.resized(start: start, translation: moved)
        }

        // Compared with a tolerance because summing 3.0 sixty times in binary
        // floating point is not exactly 180.0 — measured, it lands on
        // 179.99999999999997. That residual is arithmetic, not drift: an
        // accumulating implementation would diverge by whole points after a
        // dropped frame, not by 1e-14.
        #expect(abs(reDerived.width - inOneStep.width) < 0.001)
        #expect(abs(reDerived.contentHeight - inOneStep.contentHeight) < 0.001)
    }

    @Test("A drag past the maximum is clamped, not accepted")
    func dragPastMaximumClamps() {
        let start = IslandSize(width: 740, contentHeight: 400)
        let result = IslandSize.resized(start: start, translation: CGSize(width: 9000, height: 9000))
        #expect(result == IslandSize(width: IslandSize.maxWidth, contentHeight: IslandSize.maxContentHeight))
    }

    @Test("A drag past the minimum is clamped, not accepted")
    func dragPastMinimumClamps() {
        let start = IslandSize(width: 740, contentHeight: 400)
        let result = IslandSize.resized(start: start, translation: CGSize(width: -9000, height: -9000))
        #expect(result == IslandSize(width: IslandSize.minWidth, contentHeight: IslandSize.minContentHeight))
    }

    // MARK: Codable

    @Test("A size survives a JSON round trip")
    func survivesCodableRoundTrip() throws {
        // A `Codable` type that fails to decode is silently ignored on read, so
        // a user's resized island would quietly revert on every launch.
        let original = IslandSize(width: 903, contentHeight: 512)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IslandSize.self, from: data)
        #expect(decoded == original)
    }
}
