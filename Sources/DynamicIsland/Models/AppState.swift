import Foundation
import SwiftUI
import Combine

public enum IslandTab: Hashable, Identifiable, Sendable, CaseIterable {
    case media
    case timer
    case clipboard
    case notes
    case plugin(id: String)

    /// The raw string form persisted in `customTabOrder` and `hiddenTabs`.
    public var id: String {
        switch self {
        case .media: return "Media"
        case .timer: return "Timer"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .plugin(let id): return id
        }
    }

    public var rawValue: String { id }

    public init?(rawValue: String) {
        let migrated = IslandTab.migrateLegacyTabID(rawValue)
        switch migrated {
        case "Media": self = .media
        case "Timer": self = .timer
        case "Clipboard": self = .clipboard
        case "Notes": self = .notes
        default:
            self = .plugin(id: migrated)
        }
    }

    /// Maps a tab id persisted by an earlier build onto today's ids.
    ///
    /// `"Messenger"` was a dedicated `IslandTab` case; web apps are now
    /// `.plugin(id:)` keyed by descriptor id. Both `customTabOrder` and
    /// `hiddenTabs` store the raw string, so without this an upgrading user's tab
    /// order silently loses its position and a tab they had hidden reappears.
    ///
    /// Idempotent, and a pure function of its input, so the same answer is produced
    /// on read, in a test, and in a migration script.
    public static func migrateLegacyTabID(_ raw: String) -> String {
        raw == "Messenger" ? WebAppLegacyID.messenger : raw
    }

    /// The label shown in the tab bar and the Behaviour list.
    ///
    /// Not `rawValue`: every web app is a `.plugin(id:)`, so the raw id is the
    /// normal case rather than the exception, and rendering it would put
    /// `com.dynamicisland.plugin.messenger` in front of the user. Resolved from the
    /// registry so the name is written in exactly one place.
    public var displayName: String {
        switch self {
        case .media: return "Media"
        case .timer: return "Timer"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .plugin(let id):
            return PluginManager.shared.plugin(for: id)?.name
                ?? WebAppStore.shared.descriptor(for: id)?.name
                // The id survives in `customTabOrder` after an app is removed, so
                // this branch is reachable. Showing a bare "Plugin" would be a
                // confident wrong answer for every removed app; the id is ugly but
                // true, and the tab is pruned before the user meets it in the bar.
                ?? id
        }
    }

    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .plugin(let id):
            return PluginManager.shared.plugin(for: id)?.icon ?? "puzzlepiece.extension"
        }
    }

    public func iconView(size: CGFloat = 11) -> AnyView {
        PluginIconManager.shared.iconView(for: self, size: size)
    }

    public static var builtInTabs: [IslandTab] {
        [.media, .timer, .clipboard, .notes]
    }

    public static var defaultTabs: [IslandTab] {
        [.media, .timer, .clipboard, .notes]
            + PluginManager.shared.activePlugins.map { IslandTab.plugin(id: $0.id) }
    }

    public static var allCases: [IslandTab] {
        SettingsManager.shared.orderedTabs(from: defaultTabs)
    }
}

public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var isExpanded: Bool = false
    @Published public var isPinned: Bool = false
    
    /// Active tab. All lifecycle dispatch and plugin audio is driven from `didSet`
    /// rather than from each assignment site, so a new shell, timer path, or deep
    /// link cannot forget to notify plugins or play their interaction cue.
    @Published public var activeTab: IslandTab = .media {
        didSet {
            guard activeTab != oldValue else { return }
            notifyTabLifecycleChange(from: oldValue, to: activeTab)
        }
    }
    
    @Published public var isHovering: Bool = false
    @Published public var isDraggingOver: Bool = false
    @Published public var isFullScreen: Bool = false

    private func notifyTabLifecycleChange(from oldTab: IslandTab, to newTab: IslandTab) {
        plugin(for: oldTab)?.onTabDeselected()
        let newPlugin = plugin(for: newTab)
        newPlugin?.onTabSelected()
        
        // Play the destination plugin's configured interaction cue. This is additive
        // to the global tab-switch click, so plugins are audible even if the user has
        // disabled the generic tab-switch sound.
        if let plugin = newPlugin {
            SoundManager.shared.playPluginCue(.interaction, pluginId: plugin.id)
        }
    }
    
    /// Resolves the plugin that owns a tab, if any.
    ///
    /// Single choke point for "what plugin, if any, owns this tab?": the
    /// `if case .plugin(let id) = tab, let plugin = PluginManager.shared...`
    /// pattern was repeated in `expandedWidth` and `currentContentHeight`
    /// and would reappear at the next site that wanted a tab's plugin, so
    /// the reach for the global `PluginManager.shared` happens here exactly
    /// once. `AppState` is the only call site that should ever need it.
    public func plugin(for tab: IslandTab) -> (any IslandPlugin)? {
        if case .plugin(let id) = tab {
            return PluginManager.shared.plugin(for: id)
        }
        return nil
    }
    
    private var hoverWorkItem: DispatchWorkItem?
    private var unhoverWorkItem: DispatchWorkItem?

    private var lastCollapseTime: Date = .distantPast
    private let collapseCooldown: TimeInterval = 0.15

    /// Opaque tokens returned by block-based `addObserver` registrations.
    ///
    /// The block-based API returns a token that **must** be handed back to
    /// `removeObserver` to unregister. Discarding it is only safe for as long as
    /// this type is a process-lifetime singleton — the notification centre keeps the
    /// block alive regardless, so the closure leaks the moment that assumption stops
    /// holding. Keeping the tokens makes the teardown a one-liner in `deinit` and
    /// keeps this type correct even if it is ever no longer a singleton.
    ///
    /// See `DistributedObservationTokens` for the shared registrar.
    private var observationTokens: [any NSObjectProtocol] = []

    private init() {
        observationTokens = DistributedObservationTokens.observe([
            "com.dynamicisland.toggleExpand": { [weak self] _ in
                self?.toggleExpand()
            },
            "com.dynamicisland.expandPinned": { [weak self] _ in
                self?.isPinned = true
                self?.expand()
            },
            "com.dynamicisland.unpinCollapse": { [weak self] _ in
                self?.isPinned = false
                self?.collapse()
            },
        ])
    }

    deinit {
        DistributedObservationTokens.remove(observationTokens)
    }
    
    public static let expandedWidth: CGFloat = 560.0

    /// Whether the user is currently dragging the island's resize grip.
    ///
    /// Read by `WindowController.checkMousePosition` to suspend the collapse rule
    /// for the duration of the drag. A resize drag *begins* on the island's bottom
    /// edge, which is exactly where the mouse-leave check collapses it, so
    /// without this the island collapses under the pointer mid-gesture.
    ///
    /// The alternative — widening the leave margin while dragging — would also stop
    /// the collapse, and would be worse: it buys correctness by *disagreeing less
    /// often* about where the island is, leaving the actual overlap in place for
    /// the next reader of that margin (AGENTS.md §2.2).
    @Published public var isResizing: Bool = false

    /// The size a resize drag started from.
    ///
    /// Captured once when the drag begins so every frame re-derives from the same
    /// origin. Reading the current size instead would make the result depend on the
    /// frame count — see `IslandSize.resized(start:translation:)`.
    private var resizeStartSize: IslandSize?

    /// The corner currently being dragged, or `nil` when no resize is live.
    ///
    /// Published because the *container* needs it, not the grip: pinning the dragged
    /// edge to the pointer shifts the whole island, and the shift is a pure function of
    /// this, the start width, and the current width. So it is derived where it is drawn
    /// rather than pushed down as a value from the grip — a value pushed down would be
    /// a second source of truth for "how far is the island shifted", free to disagree
    /// with the size it is supposed to follow.
    @Published public private(set) var activeResizeCorner: IslandGripCorner?

    /// The width the live drag started from, for `IslandGripCorner.horizontalOffset`.
    ///
    /// `nil` when no drag is live, which is also the signal to centre the island.
    public var resizeStartWidth: CGFloat? {
        activeResizeCorner == nil ? nil : resizeStartSize?.width
    }

    /// The active tab's island size: the user's stored override, or what the plugin
    /// declares.
    ///
    /// The single place a plugin's declared size is read. Every other reader — the
    /// drawn frame, the tab bar, the hit test, the mouse tracker — goes through
    /// `expandedWidth` / `currentContentHeight`, so a future caller that reached for
    /// `plugin.preferredIslandWidth` directly would bypass the override and the
    /// two could disagree about how big the island is.
    ///
    /// A stored size that is not usable is discarded in favour of the declaration,
    /// so a corrupt preference degrades to a working island rather than to a
    /// zero-sized or invisible one (`IslandSize.isUsable`).
    public func resolvedSize(for plugin: any IslandPlugin) -> IslandSize {
        let declared = IslandSize(
            width: plugin.preferredIslandWidth ?? 740.0,
            contentHeight: plugin.preferredContentHeight
        )
        guard let stored = SettingsManager.shared.islandSizeOverride(for: plugin.id),
              IslandSize.isUsable(stored) else { return declared }
        return IslandSize.clamp(stored)
    }

    public var expandedWidth: CGFloat {
        // Single opened shell: the base width is constant. Integrated app plugins
        // resolve to their declared width, or to the size the user dragged them to.
        if let plugin = plugin(for: activeTab) {
            return resolvedSize(for: plugin).width
        }
        return AppState.expandedWidth
    }

    /// Whether the active tab is an integrated app whose size the user can change.
    ///
    /// Tool tabs are excluded: their content is a fixed-format readout rather than
    /// a document, and stretching it buys nothing while multiplying layout branches.
    public var isResizable: Bool {
        plugin(for: activeTab) != nil
    }

    /// The active tab's resolved size, for a caller that has already established
    /// the active tab is resizable.
    ///
    /// Falls back to the standard integrated-app defaults on a tool tab rather than
    /// trapping, so a caller racing a tab switch gets a usable size instead of a
    /// crash. The grip is only ever shown when `isResizable`, so this fallback is
    /// unreachable in practice — it exists so the ordering of two unrelated
    /// conditions cannot become a crash.
    public func resolvedSizeForActiveTab() -> IslandSize {
        guard let plugin = plugin(for: activeTab) else {
            return IslandSize(width: AppState.expandedWidth, contentHeight: 170.0)
        }
        return resolvedSize(for: plugin)
    }

    /// Applies a resize drag to the active plugin tab.
    ///
    /// `translation` is the total movement since the drag began, so the caller must
    /// pass the gesture's running translation rather than a per-frame delta.
    /// `from` is the size the drag started at; the first frame of a drag passes
    /// the current size, and later frames reuse the value captured then.
    ///
    /// The corner is taken as a parameter rather than pre-applied by the caller
    /// because the *direction* of the width change depends on which corner is
    /// being dragged: pulling the leading corner outward moves the screen pointer
    /// left, while pulling the trailing corner outward moves it right, even though
    /// both produce an island that grows. Deriving the sign here, once, means no
    /// caller can hand this an already-inverted delta — and getting it wrong would
    /// not fail, it would mirror the pointer, which looks like a bad drag rather
    /// than a sign error.
    public func resizeActiveTab(
        by translation: CGSize,
        from start: IslandSize,
        at corner: IslandGripCorner
    ) {
        guard let plugin = plugin(for: activeTab) else { return }
        if !isResizing {
            isResizing = true
            resizeStartSize = start
            activeResizeCorner = corner
        }
        let origin = resizeStartSize ?? start
        SettingsManager.shared.setIslandSizeOverride(
            IslandSize.resized(
                start: origin,
                translation: CGSize(
                    width: corner.widthChange(for: translation),
                    height: corner.heightChange(for: translation)
                )
            ),
            for: plugin.id
        )
    }

    /// Ends a resize drag.
    ///
    /// Also called from `collapse()`, because a collapse can be triggered while a
    /// drag is live — and a flag left pinned would suspend the collapse rule
    /// forever, wedging the island open (docs/DESIGN.md §5).
    public func endResize() {
        isResizing = false
        activeResizeCorner = nil
        resizeStartSize = nil
        // The live drag values were deliberately not written to disk frame by frame;
        // this is the one that must land. See `SettingsManager.islandSizeOverrides`.
        SettingsManager.shared.flushIslandSizeOverride()
    }
    
    /// Fixed ear width for the closed notch, in points.
    ///
    /// The closed notch is a fixed-size window: its width is a property of the
    /// hardware notch plus this constant, never of the current activity. Sizing
    /// the ears per-state meant an incoming Messenger (or any plugin)
    /// notification ballooned the island to 135pt per ear, which read as the
    /// notch glitching and ballooning rather than as a notification arriving.
    ///
    /// Left/right ear content is expected to adapt to this width: the left ear
    /// scales and truncates its text, the right ear is graphical only, and live
    /// indicators rely on glyphs rather than on more room. See
    /// `RightEarPolicy` for the right-ear contract.
    public static let compactEarWidthFixed: CGFloat = 56.0

    public var compactEarWidth: CGFloat {
        AppState.compactEarWidthFixed + CGFloat(SettingsManager.shared.customWidthOffset) / 2.0
    }
    
    public var compactIslandWidth: CGFloat {
        let detector = NotchDetector.shared
        let settings = SettingsManager.shared
        let isNotchMode = detector.isNotchMode

        if isNotchMode {
            let notchW = max(170.0, detector.currentNotch.notchWidth)
            return notchW + (compactEarWidth * 2.0) + (NotchIslandShape.compactFlareWidth * 2.0)
        } else {
            // Floating pill: also a fixed size. Like the notch it must not resize
            // with the active activity, so the same constant is used for both
            // presentation modes and the closed island never changes footprint.
            return 2.0 * AppState.compactEarWidthFixed + NotchDetector.shared.currentNotch.notchWidth
                + CGFloat(settings.customWidthOffset)
        }
    }
    
    public var shelfRectangleHeight: CGFloat {
        guard !DropShelfManager.shared.items.isEmpty || isDraggingOver else { return 0 }
        switch SettingsManager.shared.dropShelfCardStyle {
        case .square:
            return 120.0
        case .compact:
            return 78.0
        }
    }

    /// The content region's height for the active tab.
    public var currentContentHeight: CGFloat {
        if let plugin = plugin(for: activeTab) {
            return resolvedSize(for: plugin).contentHeight
        }
        return 170.0
    }
    
    public func expandedHeight(isNotchMode: Bool, notchHeight: CGFloat) -> CGFloat {
        let notchTopInset: CGFloat = isNotchMode ? max(34.0, notchHeight) : 8.0
        let contentH = currentContentHeight
        return notchTopInset + 38.0 + contentH + 16.0
    }

    public func totalExpandedHeight(isNotchMode: Bool, notchHeight: CGFloat) -> CGFloat {
        let mainH = expandedHeight(isNotchMode: isNotchMode, notchHeight: notchHeight)
        if shelfRectangleHeight > 0 {
            return mainH + 12.0 + shelfRectangleHeight
        }
        return mainH
    }

    public func toggleExpand() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    public func expand(tab: IslandTab? = nil) {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        if let tab = tab {
            self.activeTab = tab
        }
        if !isExpanded {
            withAnimation(IslandSpring.expand) {
                isExpanded = true
            }
            SoundManager.shared.play(.expand)
        } else {
        }
    }

    public func collapse(force: Bool = false) {
        if isPinned && !force { return }
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        unhoverWorkItem?.cancel()
        unhoverWorkItem = nil
        // A collapse can be triggered from outside the drag — Esc, a notification,
        // a fullscreen transition — so the resize flag is dropped here rather than
        // only in `endResize()`. Left pinned, it would keep suspending the
        // mouse-leave collapse check and the island could never close again.
        endResize()
        if force {
            isHovering = false
        }
        if isExpanded {
            withAnimation(IslandSpring.collapse) {
                isExpanded = false
            }
            lastCollapseTime = Date()
            SoundManager.shared.play(.collapse)
            // Hand the keyboard back to the app the user was actually working in.
            // Without this the island keeps key status (and this app stays active)
            // after it has visually closed, so the user's next keystroke is lost.
            IslandFocusController.shared.resignFocusIfIdle()
        }
    }
    
    public func handleMouseEnter() {
        guard !isExpanded else { return }

        // Strict boundary check: cursor must physically be inside the notch / compact pill
        if let screen = NSScreen.main {
            let mouse = NSEvent.mouseLocation
            let detector = NotchDetector.shared
            let isNotchMode = detector.isNotchMode
            let notchH = detector.currentNotch.notchHeight > 0 ? detector.currentNotch.notchHeight : 32.0
            let compactW = compactIslandWidth
            let compactH = isNotchMode ? notchH : 34.0
            let topInset: CGFloat = isNotchMode ? 0.0 : 8.0

            let marginX: CGFloat = isFullScreen ? 24.0 : 0.0
            let marginY: CGFloat = isFullScreen ? 12.0 : 0.0

            let inX = mouse.x >= (screen.frame.midX - compactW / 2.0 - marginX)
                   && mouse.x <= (screen.frame.midX + compactW / 2.0 + marginX)
            let inY = mouse.y >= (screen.frame.maxY - topInset - compactH - marginY)

            guard inX && inY else {
                return
            }
        }
        
        unhoverWorkItem?.cancel()
        unhoverWorkItem = nil
        
        if !isHovering {
            withAnimation(IslandSpring.expand) {
                isHovering = true
            }
        }
        
        // In fullscreen mode, hovering the notch directly displays the whole opened island
        if isFullScreen {
            let timeSinceCollapse = Date().timeIntervalSince(lastCollapseTime)
            guard timeSinceCollapse >= collapseCooldown else { return }
            self.expand()
            return
        }
        
        // If clickOnly trigger is configured, hover unhides compact notch without auto-expanding
        if SettingsManager.shared.expandTrigger == .clickOnly {
            return
        }
        
        // If already hovering with a pending expand work item, don't restart/delay the timer
        if hoverWorkItem != nil {
            return
        }
        
        let timeSinceCollapse = Date().timeIntervalSince(lastCollapseTime)
        let cooldownRemaining = max(0, collapseCooldown - timeSinceCollapse)
        let totalDelay = max(SettingsManager.shared.hoverDelay, cooldownRemaining)
        
        if totalDelay <= 0.001 {
            self.expand()
            return
        }
        
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovering, !self.isExpanded else { return }
            self.expand()
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay, execute: work)
    }
    
    public func handleMouseLeaveCompact() {
        guard !isExpanded else { return }
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        
        unhoverWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isExpanded else { return }
            withAnimation(IslandSpring.collapse) {
                self.isHovering = false
            }
        }
        unhoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    
    public func handleMouseLeave() {
        unhoverWorkItem?.cancel()
        unhoverWorkItem = nil
        isHovering = false
        hoverWorkItem?.cancel()
        hoverWorkItem = nil

        guard !isPinned else { return }
        guard isExpanded else { return }

        collapse()
    }
    
    public func cancelHover() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        handleMouseLeaveCompact()
    }
    
    public func handleDragEntered() {
        isDraggingOver = true
        expand()
    }
    
    public func handleDragExited() {
        isDraggingOver = false
        if !isPinned {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, !self.isHovering, !self.isDraggingOver, !self.isPinned else { return }
                self.collapse()
            }
        }
    }
}
