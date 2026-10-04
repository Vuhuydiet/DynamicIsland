import SwiftUI
import AppKit

// MARK: - Standard Button Styles & Variants

public enum IslandButtonVariant {
    case primary(Color = .blue)
    case secondary
    case ghost
    case tinted(Color)
    case danger
}

public enum IslandButtonSize {
    case small
    case regular
    case large
    
    public var height: CGFloat {
        switch self {
        case .small: return 24
        case .regular: return 28
        case .large: return 34
        }
    }
    
    public var horizontalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .regular: return 12
        case .large: return 16
        }
    }
    
    public var font: Font {
        switch self {
        case .small: return IslandFont.micro
        case .regular: return IslandFont.caption
        case .large: return IslandFont.subtitle
        }
    }
    
    public var iconFont: Font {
        switch self {
        case .small: return IslandFont.iconMicro
        case .regular: return IslandFont.iconSmall
        case .large: return IslandFont.iconRegular
        }
    }
}

/// Standardized tactile button for tabs, tools, and plugins.
public struct IslandButton: View {
    public var title: String?
    public var icon: String?
    public var variant: IslandButtonVariant
    public var size: IslandButtonSize
    public var action: () -> Void
    
    public init(
        _ title: String? = nil,
        icon: String? = nil,
        variant: IslandButtonVariant = .secondary,
        size: IslandButtonSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            SoundManager.shared.play(.click)
            action()
        }) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                if let title = title {
                    Text(title)
                        .font(size.font)
                        .lineLimit(1)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay(strokeOverlay)
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary(let color):
            return color == .white ? .black : .white
        case .secondary:
            return .white.opacity(0.85)
        case .ghost:
            return .white.opacity(0.65)
        case .tinted(let color):
            return color
        case .danger:
            return .red
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary(let color):
            color
        case .secondary:
            Color.white.opacity(0.12)
        case .ghost:
            Color.white.opacity(0.04)
        case .tinted(let color):
            color.opacity(0.18)
        case .danger:
            Color.red.opacity(0.16)
        }
    }
    
    @ViewBuilder
    private var strokeOverlay: some View {
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        case .ghost:
            EmptyView()
        case .tinted(let color):
            Capsule().stroke(color.opacity(0.30), lineWidth: 0.5)
        case .danger:
            Capsule().stroke(Color.red.opacity(0.30), lineWidth: 0.5)
        }
    }
}

// MARK: - Standardized Header Component

/// A standardized header for all tool views and injected plugins.
public struct IslandHeaderView<Trailing: View>: View {
    public var icon: String?
    public var iconColor: Color
    public var iconView: AnyView?
    public var title: String
    public var subtitle: String?
    public var statusBadge: String?
    public var statusColor: Color
    public var trailing: Trailing
    
    public init(
        icon: String? = nil,
        iconColor: Color = .blue,
        iconView: AnyView? = nil,
        title: String,
        subtitle: String? = nil,
        statusBadge: String? = nil,
        statusColor: Color = .green,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconView = iconView
        self.title = title
        self.subtitle = subtitle
        self.statusBadge = statusBadge
        self.statusColor = statusColor
        self.trailing = trailing()
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Leading: Icon + Titles + Optional Badge
            HStack(spacing: 6) {
                if let iconView = iconView {
                    iconView
                        .frame(width: 18, height: 18)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(IslandFont.iconRegular)
                        .foregroundColor(iconColor)
                        .frame(width: 18, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(IslandFont.title)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let status = statusBadge {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 5, height: 5)
                                Text(status)
                                    .font(IslandFont.micro)
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(IslandFont.micro)
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Trailing actions
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }
}

public extension IslandHeaderView where Trailing == EmptyView {
    init(
        icon: String? = nil,
        iconColor: Color = .blue,
        title: String,
        subtitle: String? = nil,
        statusBadge: String? = nil,
        statusColor: Color = .green
    ) {
        self.init(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            statusBadge: statusBadge,
            statusColor: statusColor,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Standardized Card / Surface Container

/// Standard Liquid Glass card container for grouping content inside tabs.
public struct IslandCardView<Content: View>: View {
    public var cornerRadius: CGFloat
    public var content: Content
    
    public init(cornerRadius: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Standardized Translucent Divider

/// Subtle translucent separator line unifying the glass divider across tools.
public struct IslandDivider: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.20))
                .frame(height: 0.5)
                .offset(y: 0.5)
        }
    }
}

// MARK: - Standardized Search Field

/// Standard text input / search field with icon and clear button.
public struct IslandSearchField: View {
    @Binding public var text: String
    public var placeholder: String
    public var onCommit: (() -> Void)?
    
    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.40))
                .font(IslandFont.iconRegular)
            
            TextField(placeholder, text: $text, onCommit: {
                onCommit?()
            })
            .textFieldStyle(.plain)
            .font(IslandFont.body)
            .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation(IslandSpring.bouncy) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.45))
                        .font(IslandFont.iconRegular)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
    }
}

// MARK: - Standardized Empty State View

/// Clean empty state placeholder for tabs or plugins when offline/empty.
public struct IslandEmptyStateView: View {
    public var icon: String
    public var title: String
    public var subtitle: String?
    public var actionTitle: String?
    public var action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.35))
            
            Text(title)
                .font(IslandFont.subtitle)
                .foregroundColor(.white.opacity(0.70))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if let actionTitle = actionTitle, let action = action {
                IslandButton(actionTitle, variant: .secondary, size: .small, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
        visibleOnly: Bool = true
    ) {
        if draggingTab == nil {
            draggingTab = tab
            self.visibleOnly = visibleOnly
            initialOrderedTabs = orderedTabs
            initialFullOrder = IslandTab.allCases
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

    public func onDragEnded(tab: IslandTab, translation: CGFloat, onSelect: (IslandTab) -> Void) {
        guard draggingTab == tab else { return }

        if !hasMovedPastTapSlop {
            onSelect(tab)
            if didPushCursor {
                NSCursor.pop()
                didPushCursor = false
            }
            resetState()
            return
        }

        SoundManager.shared.play(.click)

        if didPushCursor {
            NSCursor.pop()
            didPushCursor = false
        }

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

        var moved = initialOrderedTabs.filter { $0 != tab }
        let insertAt = max(0, min(currentTargetIndex, moved.count))
        moved.insert(tab, at: insertAt)

        let newOrder: [IslandTab]
        if visibleOnly {
            let movingIDs = Set(initialOrderedTabs.map(\.id))
            var iterator = moved.makeIterator()
            newOrder = initialFullOrder.map { existing in
                if movingIDs.contains(existing.id) {
                    return iterator.next() ?? existing
                }
                return existing
            }
        } else {
            newOrder = moved
        }

        SettingsManager.shared.customTabOrder = newOrder.map(\.rawValue)
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
                            visibleOnly: visibleOnly
                        )
                    }
                    .onEnded { value in
                        let translation = axis == .horizontal ? value.translation.width : value.translation.height
                        coordinator.onDragEnded(tab: tab, translation: translation, onSelect: onSelect)
                    }
            )
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
