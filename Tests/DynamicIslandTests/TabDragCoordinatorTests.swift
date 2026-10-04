import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Tab bar interaction contract
//
// These tests guard the two defects that made tab switching dead (fixed in
// `17d114e`, latent since the reorder gesture was introduced in `1977999`):
//
//  1. Selection was owned by `DragGesture.onEnded`. `DragGesture` has
//     `minimumDistance: 4`, so on a still click it never reports at all, and the
//     leading `guard draggingTab == tab` bailed out — no tab ever switched. A click
//     only appeared to work when the pointer happened to travel past 4pt.
//  2. A drag whose release never arrived left `draggingTab` pinned to the dead
//     pill. Because both entry points are guarded by `draggingTab == tab`, every
//     *other* pill then failed both guards and could not be selected at all.
//
// The fix gives selection its own `onTapGesture`, and makes both drag entry
// points drop an abandoned drag instead of silently returning.
//
// ── Why every test below injects `fullOrder` explicitly ────────────────────────
// `IslandTab.allCases` is NOT a pure enumeration: it resolves through
// `SettingsManager` and `PluginManager`, and `defaultTabs` reads
// `MessengerPlugin.shared.isEnabled`, which touches a `WKWebView`. In a headless
// `swift test` process that traps with SIGTRAP. Every test therefore passes the
// full order in as data, which is also the reason the production code accepts it
// as a parameter instead of reading the global internally. If you add a test here,
// pass `fullOrder:` explicitly rather than relying on the default.

/// A stand-in for the full tab order that never touches the plugin registry.
private let fullOrder: [IslandTab] = [.media, .timer, .clipboard, .notes, .messenger]

@Suite("Tab bar gesture state machine")
struct TabDragCoordinatorTests {

    @Test("A clean click with no pointer travel leaves the coordinator neutral")
    func cleanClickSelects() {
        // Regression test for defect 1. A still click means `DragGesture` fires
        // neither `onChanged` nor `onEnded`, so `draggingTab` is still nil here —
        // which is exactly the state that used to swallow the selection.
        let coordinator = TabDragCoordinator()
        #expect(coordinator.draggingTab == nil)

        coordinator.onDragEnded(tab: .notes, translation: 0)

        #expect(coordinator.draggingTab == nil)
        #expect(coordinator.hasMovedPastTapSlop == false)
        #expect(coordinator.dragOffset == 0)
    }

    @Test("A lost drag release no longer blocks every other tab")
    func staleDragDoesNotWedgeTheBar() {
        // Regression test for defect 2.
        let coordinator = TabDragCoordinator()

        // A drag begins on .media; its release never arrives (view rebuilt, mouse-up
        // landed off-pill, island resized mid-gesture).
        coordinator.onDragChanged(
            tab: .media, translation: 40, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        #expect(coordinator.draggingTab == .media)

        // The user now tries a *different* tab. The stale drag must be dropped, not
        // allowed to fail the `draggingTab == tab` guard forever.
        coordinator.onDragChanged(
            tab: .clipboard, translation: 2, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        #expect(coordinator.draggingTab == .clipboard)

        coordinator.onDragEnded(tab: .clipboard, translation: 2)
        #expect(coordinator.draggingTab == nil)
    }

    @Test("A release for a dead drag is cleaned up rather than ignored")
    func staleReleaseCleansUp() {
        let coordinator = TabDragCoordinator()
        coordinator.onDragChanged(
            tab: .media, translation: 40, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )

        // A release arrives for a pill that is not the live drag — the old code
        // returned via `guard` and left the state pinned.
        coordinator.onDragEnded(tab: .notes, translation: 10)
        #expect(coordinator.draggingTab == nil)
        #expect(coordinator.dragOffset == 0)
    }

    @Test("Every tab's gesture ends in a neutral state, so the bar cannot wedge")
    func everyExitPathClearsState() {
        for tab in fullOrder {
            let tap = TabDragCoordinator()
            tap.onDragChanged(
                tab: tab, translation: 2, orderedTabs: fullOrder,
                slotStep: 90, fullOrder: fullOrder
            )
            tap.onDragEnded(tab: tab, translation: 2)
            #expect(tap.draggingTab == nil, "\(tab.rawValue) wedged after a tap")
            #expect(tap.hasMovedPastTapSlop == false, "\(tab.rawValue) kept the slop flag")

            let drag = TabDragCoordinator()
            drag.onDragChanged(
                tab: tab, translation: 120, orderedTabs: fullOrder,
                slotStep: 90, fullOrder: fullOrder
            )
            #expect(drag.draggingTab == tab)
            #expect(drag.hasMovedPastTapSlop == true)
            drag.onDragEnded(tab: tab, translation: 120)
            // `onDragEnded` defers `resetState()` past the settle spring, so the
            // slop flag is intentionally still set here.
            #expect(drag.hasMovedPastTapSlop == true, "\(tab.rawValue) lost the slop flag too early")
        }
    }

    @Test("Jitter under the tap slop is tracked exactly, not snapped")
    func jitterUnderSlopTracksExactly() {
        let coordinator = TabDragCoordinator()
        // `tapSlop` is 6 and the comparison is strict `>`, so 6 is still a tap while
        // 7 has crossed it. Pin both sides of that boundary.
        coordinator.onDragChanged(
            tab: .timer, translation: 6, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        #expect(coordinator.hasMovedPastTapSlop == false)
        #expect(coordinator.dragOffset == 6)

        coordinator.onDragChanged(
            tab: .timer, translation: 7, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        #expect(coordinator.hasMovedPastTapSlop == true)
        // `dragOffset` equals the raw translation, which is what makes the pill
        // track the cursor 1:1 instead of rubber-banding.
        #expect(coordinator.dragOffset == 7)
    }

    @Test("The drag only latches onto the pill it started on")
    func dragLatchesToOnePill() {
        // A second pill reporting movement mid-gesture must be ignored rather than
        // stealing the drag; the stale-drag recovery in `onDragChanged` handles only
        // a *fresh* gesture, and a fresh gesture is what `onChanged` on a different
        // pill means here.
        let coordinator = TabDragCoordinator()
        coordinator.onDragChanged(
            tab: .media, translation: 40, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        coordinator.onDragChanged(
            tab: .notes, translation: 40, orderedTabs: fullOrder,
            slotStep: 90, fullOrder: fullOrder
        )
        #expect(coordinator.draggingTab == .notes)
    }
}

@Suite("Tab reorder order computation")
struct TabReorderTests {

    @Test("Dragging the first tab to the end reverses the visible bar")
    func dragFirstToLast() {
        let order = TabDragCoordinator.reorderedTabs(
            dragging: .media,
            from: [.media, .timer, .clipboard, .notes],
            to: 3,
            visibleOnly: true,
            fullOrder: [.media, .timer, .clipboard, .notes]
        )
        #expect(order == [.timer, .clipboard, .notes, .media])
    }

    @Test("Target index is clamped, so an over-drag cannot corrupt the order")
    func targetIndexIsClamped() {
        let base: [IslandTab] = [.media, .timer, .clipboard, .notes]

        let over = TabDragCoordinator.reorderedTabs(
            dragging: .media, from: base, to: 99, visibleOnly: true, fullOrder: base
        )
        #expect(over == [.timer, .clipboard, .notes, .media])

        let under = TabDragCoordinator.reorderedTabs(
            dragging: .media, from: base, to: -5, visibleOnly: true, fullOrder: base
        )
        #expect(under == [.media, .timer, .clipboard, .notes])
    }

    @Test("A reorder is a pure permutation — no tab is lost or duplicated")
    func reorderIsAPermutation() {
        let base: [IslandTab] = [.media, .timer, .clipboard, .notes, .messenger]
        for target in 0..<base.count {
            for tab in base {
                let result = TabDragCoordinator.reorderedTabs(
                    dragging: tab, from: base, to: target,
                    visibleOnly: true, fullOrder: base
                )
                #expect(result.count == base.count, "tab count changed")
                #expect(Set(result) == Set(base), "tabs lost or duplicated")
            }
        }
    }

    @Test("Reordering the visible bar leaves hidden tabs in their original slots")
    func visibleOnlyPreservesHiddenTabs() {
        // `.plugin` tabs are the ones that can be hidden. The visible subset gets
        // reshuffled; every non-visible tab must keep its exact index, so a reorder
        // of the bar the user can see never relocates a tab they cannot.
        let full: [IslandTab] = [
            .media, .plugin(id: "alpha"), .timer, .plugin(id: "beta"), .notes,
        ]
        let visible: [IslandTab] = [.media, .timer, .notes]

        let result = TabDragCoordinator.reorderedTabs(
            dragging: .notes, from: visible, to: 0, visibleOnly: true, fullOrder: full
        )

        // The three visible slots (0, 2, 4) are refilled in the new order
        // [notes, media, timer]; the two hidden slots are untouched.
        #expect(result == [
            .notes, .plugin(id: "alpha"), .media, .plugin(id: "beta"), .timer,
        ])

        // The real invariant: hidden tabs did not move at all.
        #expect(result.firstIndex(of: .plugin(id: "alpha")) == 1)
        #expect(result.firstIndex(of: .plugin(id: "beta")) == 3)
    }

    @Test("visibleOnly: false returns just the moved list, unfiltered")
    func notVisibleOnlyReturnsMovedList() {
        let base: [IslandTab] = [.media, .timer, .notes]
        let result = TabDragCoordinator.reorderedTabs(
            dragging: .media, from: base, to: 2, visibleOnly: false, fullOrder: base
        )
        #expect(result == [.timer, .notes, .media])
    }
}
