import SwiftUI

// MARK: - Interactive Tab Drag & Drop Coordinator
//
// Split out of `IslandComponents.swift`, which held the island design system and the
// tab drag state machine in one file. The two have nothing in common except that both
// mention tabs: one is the shared visual vocabulary every pane reuses, the other is a
// gesture coordinator with the most heavily-commented invariants in the repo (see the
// commit citations below). Keeping them together meant the design system was twice the
// size of any one concern and the drag logic could not be reviewed on its own.
//
// This type stays in `Views/Components/` rather than moving to the Expanded views
// because it is a view modifier plus a coordinator, and the tests reach it through
// the module either way.

// MARK: - Interactive Tab Drag & Drop Coordinator

/// Live-reorders island tabs by mapping finger/cursor travel onto a frozen snapshot
/// of the list taken at drag start. Hidden tabs keep their slots when only the
/// visible bar is being rearranged.
public class TabDragCoordinator: ObservableObject {
    @Published public var draggingTab: IslandTab? = nil
    @Published public var dragOffset: CGFloat = 0
    /// True once the gesture has crossed the tap slop — distinguishes a real drag
    /// from a stationary click. Views should use this to gate lift/hide effects so
    /// that a tap doesn't briefly animate into drag styling before snapping back.
    @Published public var hasMovedPastTapSlop: Bool = false

    private var initialIndex: Int = 0
    private var currentTargetIndex: Int = 0
    private var initialOrderedTabs: [IslandTab] = []
    private var initialFullOrder: [IslandTab] = []
    private var visibleOnly: Bool = true
    private var didPushCursor: Bool = false
    private let tapSlop: CGFloat = 6
    /// The `slotStep` the gesture was measured with, kept so the release settle
    /// can convert the accumulated index shift back into points.
    private var currentSlotStep: CGFloat = 0
    /// True between the release commit and the end of the settle spring. During
    /// this window the pill is animating into its final slot, so it is exempt
    /// from the "no animation while dragging" rule.
    @Published public private(set) var isSettling: Bool = false
    
    public init() {}
    
    public func onDragChanged(
        tab: IslandTab,
        translation: CGFloat,
        orderedTabs: [IslandTab],
        slotStep: CGFloat,
        visibleOnly: Bool = true,
        fullOrder: @autoclosure () -> [IslandTab] = IslandTab.allCases
    ) {
        // ── Stale-drag recovery ──────────────────────────────────────────
        // A live drag on a *different* pill means the previous gesture's release
        // never reached `onDragEnded` (the view was rebuilt, the island resized,
        // or the mouse-up landed outside the pill). Without this, `draggingTab`
        // stayed pinned to the dead pill forever and — because both `onDragChanged`
        // and `onDragEnded` are guarded by `draggingTab == tab` — every other pill
        // silently failed to select. Drop the abandoned drag and start fresh.
        if let live = draggingTab, live != tab {
            popDragCursor()
            resetState()
        }

        if draggingTab == nil {
            draggingTab = tab
            self.visibleOnly = visibleOnly
            initialOrderedTabs = orderedTabs
            // `@autoclosure` so the snapshot is resolved only when a drag actually
            // starts, and only once. `IslandTab.allCases` is not free: it resolves
            // through `PluginManager` and `MessengerPlugin` (a `WKWebView`), so it
            // must stay off the hot path of every `onChanged` frame. Tests pass an
            // explicit value to stay off the window server entirely.
            initialFullOrder = fullOrder()
            initialIndex = orderedTabs.firstIndex(of: tab) ?? 0
            currentTargetIndex = initialIndex
            hasMovedPastTapSlop = false
            isSettling = false
            NSCursor.closedHand.push()
            didPushCursor = true
        }

        guard draggingTab == tab else { return }

        if abs(translation) > tapSlop && !hasMovedPastTapSlop {
            hasMovedPastTapSlop = true
        }

        let safeSlotStep = max(24, slotStep)
        currentSlotStep = safeSlotStep
        let slotShift = Int((translation / safeSlotStep).rounded())
        let lastIndex = max(0, initialOrderedTabs.count - 1)
        let targetIndex = max(0, min(lastIndex, initialIndex + slotShift))

        if targetIndex != currentTargetIndex {
            currentTargetIndex = targetIndex
            SoundManager.shared.play(.click)
        }

        // ── Why nothing is reordered here ───────────────────────────────────
        // Earlier revisions committed `customTabOrder` on every crossing. That made
        // the dragged pill's screen position the sum of two independently-changing
        // terms — its layout slot and `dragOffset` — which are only correct if they
        // cancel to the pixel, every frame. They never quite did, and the mismatch
        // presented as a flicker/rubber-band on each crossing.
        //
        // The order is now committed exactly once, on release. During the drag the
        // shared layout is frozen, so `dragOffset` is the pill's ONLY displacement
        // and it equals the raw gesture translation. Cursor tracking is therefore
        // exact by construction rather than by two terms happening to agree.
        dragOffset = translation
    }

    public func onDragEnded(tab: IslandTab, translation: CGFloat) {
        // Same stale-drag recovery as `onDragChanged`: if the release belongs to a
        // gesture that is no longer live, just clean up. Never early-return silently
        // while leaving `draggingTab` set.
        if draggingTab != tab {
            if draggingTab != nil {
                popDragCursor()
                resetState()
            }
            return
        }

        // A tap (never crossed the slop) is handled by the pill's `onTapGesture`.
        // Selection deliberately does NOT live here: `DragGesture` only calls
        // `onChanged` after `minimumDistance` is exceeded, so on a still click this
        // method runs with `draggingTab == nil` and the old `guard draggingTab ==
        // tab` bailed out — the tab was simply never selected. Selection now has its
        // own recognizer, so it fires on every click regardless of drag state.
        if !hasMovedPastTapSlop {
            popDragCursor()
            resetState()
            return
        }

        SoundManager.shared.play(.click)

        popDragCursor()

        // Commit the new order with animations disabled, and in the SAME instant
        // move the offset to the exact value that cancels the layout shift. The
        // pill does not move on screen at this moment; the remaining distance is
        // then sprung into its final slot.
        let slotDelta = CGFloat(currentTargetIndex - initialIndex) * currentSlotStep
        let settleStart = translation - slotDelta

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyTargetOrder()
            isSettling = true
            dragOffset = settleStart
        }

        withAnimation(IslandSpring.tabSlide) {
            dragOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.resetState()
        }
    }

    /// Pops the drag cursor exactly once, if one is currently pushed.
    ///
    /// Every exit path from a drag must go through this. Calling `NSCursor.pop()`
    /// without a matching push corrupts AppKit's cursor stack, which leaves the
    /// grabbing/closed-hand cursor stuck on screen for the rest of the session.
    private func popDragCursor() {
        guard didPushCursor else { return }
        NSCursor.pop()
        didPushCursor = false
    }

    private func resetState() {
        draggingTab = nil
        dragOffset = 0
        hasMovedPastTapSlop = false
        isSettling = false
        initialOrderedTabs = []
        initialFullOrder = []
    }
    
    /// Persists the new order. Called ONLY on release, from `onDragEnded`, which
    /// already wraps it in an animation-disabling transaction so the dragged
    /// pill's layout slot lands in the same instant that `dragOffset` is set to
    /// the value that cancels the shift. The two therefore cancel exactly and
    /// the pill appears not to move at the moment of commit.
    private func applyTargetOrder() {
        guard let tab = draggingTab else { return }
        let newOrder = Self.reorderedTabs(
            dragging: tab,
            from: initialOrderedTabs,
            to: currentTargetIndex,
            visibleOnly: visibleOnly,
            fullOrder: initialFullOrder
        )
        SettingsManager.shared.customTabOrder = newOrder.map(\.rawValue)
    }

    /// The pure order computation behind a reorder gesture.
    ///
    /// Extracted so the rule can be unit-tested without a running app, without
    /// `UserDefaults`, and without `SoundManager` (AGENTS.md §3). It is a `static`
    /// function on `Sendable` inputs, so it is the single place the "where does the
    /// dragged tab land" answer is defined — `applyTargetOrder` is now just a
    /// caller that persists the result.
    ///
    /// `fullOrder` is a **parameter**, not read from `IslandTab.allCases`, and that
    /// is deliberate. `allCases` is not a pure enumeration: it resolves through
    /// `SettingsManager` and `PluginManager`, and `defaultTabs` reads
    /// `MessengerPlugin.shared.isEnabled`, which touches a `WKWebView` and therefore
    /// requires a window server. Reading it from this function would make the whole
    /// reorder rule untestable and would trap in a headless test process. The
    /// caller passes the snapshot it already holds, so the value is captured once
    /// per gesture and cannot change mid-commit.
    ///
    /// - When `visibleOnly` is true, only the visible subset is reshuffled and the
    ///   result is woven back into `fullOrder`, leaving every hidden tab in its
    ///   original position. That keeps a reorder of the visible bar from silently
    ///   relocating tabs the user cannot see.
    static func reorderedTabs(
        dragging tab: IslandTab,
        from orderedTabs: [IslandTab],
        to targetIndex: Int,
        visibleOnly: Bool,
        fullOrder: [IslandTab]
    ) -> [IslandTab] {
        var moved = orderedTabs.filter { $0 != tab }
        let insertAt = max(0, min(targetIndex, moved.count))
        moved.insert(tab, at: insertAt)

        guard visibleOnly else { return moved }

        let movingIDs = Set(orderedTabs.map(\.id))
        var iterator = moved.makeIterator()
        return fullOrder.map { existing in
            if movingIDs.contains(existing.id) {
                return iterator.next() ?? existing
            }
            return existing
        }
    }
}

public struct IslandTabDragReorder: ViewModifier {
    public var tab: IslandTab
    public var orderedTabs: [IslandTab]
    public var slotStep: CGFloat
    @ObservedObject public var coordinator: TabDragCoordinator
    public var axis: Axis = .horizontal
    public var visibleOnly: Bool = true
    public var liftWhileDragging: Bool = true
    public var onSelect: (IslandTab) -> Void

    public func body(content: Content) -> some View {
        let isDragging = coordinator.draggingTab == tab
        let isActivelyDragging = isDragging && coordinator.hasMovedPastTapSlop
        // This pill's live slot. Siblings glide on this; the dragged pill must not.
        let myIndex = orderedTabs.firstIndex(of: tab) ?? 0
        content
            // The dragged pill stays fully VISIBLE and is carried by `dragOffset`,
            // which is recomputed to pin the pill exactly under the cursor. It is
            // deliberately NOT hidden: hiding it left only a moving gap plus a
            // shuffling row of siblings, which read as flicker.
            .offset(
                x: axis == .horizontal && isDragging ? coordinator.dragOffset : 0,
                y: axis == .vertical && isDragging ? coordinator.dragOffset : 0
            )
            .zIndex(isDragging ? 20 : 1)
            // Lift effect only after the gesture has actually moved past tap slop —
            // prevents a click from briefly growing the pill before it snaps back.
            .scaleEffect(liftWhileDragging && isActivelyDragging ? 1.06 : 1.0)
            // ── No animation of any kind while dragging ────────────────────────
            // Every animated channel that reaches this view (the bar's
            // `.animation(_:value: visibleTabs)`, the pill's `.animation(_:value:
            // isActive)`, the reorder commit itself) also animates the `offset`
            // above, because an animation attached to a view animates all of its
            // animatable modifiers. The pill therefore lagged the pointer and
            // rubber-banded backwards on every slot crossing.
            //
            // The rule is now absolute: while this pill is being dragged, NO
            // animation may apply to it. `dragOffset` alone determines its
            // position, so it tracks the cursor 1:1 and moves the instant the
            // cursor moves — no waiting for a spring to settle. The spring is
            // reserved for release, where the pill settles into its final slot.
            .transaction { transaction in
                if isDragging && !coordinator.isSettling { transaction.animation = nil }
            }
            // Siblings glide into the slot the dragged pill vacates. This is
            // suppressed for the dragged pill only, whose own `dragOffset` is the
            // single source of truth for its position.
            .animation(
                (isDragging && !coordinator.isSettling)
                    ? nil
                    : (axis == .horizontal ? IslandSpring.tabSlide : IslandSpring.bouncy),
                value: myIndex
            )
            // Instant lift while dragging; spring back into the slot on release.
            // Passing `nil` while active stops the bouncy spring from lagging the pointer.
            .animation(isActivelyDragging ? nil : IslandSpring.bouncy, value: isActivelyDragging)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let translation = axis == .horizontal ? value.translation.width : value.translation.height
                        coordinator.onDragChanged(
                            tab: tab,
                            translation: translation,
                            orderedTabs: orderedTabs,
                            slotStep: slotStep,
                            visibleOnly: visibleOnly,
                            // The bar already holds the authoritative full order in
                            // `orderedTabs` for the settings list, and for the main
                            // bar the visible list *is* the reorderable set. Either
                            // way this avoids re-resolving `IslandTab.allCases`
                            // (which reaches a `WKWebView`) on every frame.
                            fullOrder: visibleOnly ? IslandTab.allCases : orderedTabs
                        )
                    }
                    .onEnded { value in
                        let translation = axis == .horizontal ? value.translation.width : value.translation.height
                        coordinator.onDragEnded(tab: tab, translation: translation)
                    }
            )
            // ── Selection ───────────────────────────────────────────────────
            // Selection is owned by its own tap recognizer, NOT by `DragGesture`'s
            // `onEnded`. `DragGesture` only reports `onChanged`/`onEnded` after
            // `minimumDistance` (4pt) is exceeded, so on a perfectly still click it
            // never fires at all and the tab is never selected. The `gesture` above
            // also has higher precedence, so it wins on a real drag and correctly
            // suppresses this — giving clean separation: drag reorders, tap selects.
            .onTapGesture {
                guard !coordinator.hasMovedPastTapSlop else { return }
                onSelect(tab)
            }
    }
}

extension View {
    public func islandTabReorderDrag(
        tab: IslandTab,
        orderedTabs: [IslandTab],
        slotStep: CGFloat,
        coordinator: TabDragCoordinator,
        axis: Axis = .horizontal,
        visibleOnly: Bool = true,
        liftWhileDragging: Bool = true,
        onSelect: @escaping (IslandTab) -> Void
    ) -> some View {
        modifier(IslandTabDragReorder(
            tab: tab,
            orderedTabs: orderedTabs,
            slotStep: slotStep,
            coordinator: coordinator,
            axis: axis,
            visibleOnly: visibleOnly,
            liftWhileDragging: liftWhileDragging,
            onSelect: onSelect
        ))
    }
}
