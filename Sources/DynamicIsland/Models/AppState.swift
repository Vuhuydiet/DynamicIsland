import Foundation
import SwiftUI
import Combine

public enum IslandTab: Hashable, Identifiable, Sendable, CaseIterable {
    case media
    case timer
    case clipboard
    case notes
    case messenger
    case plugin(id: String)
    
    public var id: String {
        switch self {
        case .media: return "Media"
        case .timer: return "Timer"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .messenger: return "Messenger"
        case .plugin(let id): return id
        }
    }
    
    public var rawValue: String { id }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "Media": self = .media
        case "Timer": self = .timer
        case "Clipboard": self = .clipboard
        case "Notes": self = .notes
        case "Messenger": self = .messenger
        default:
            self = .plugin(id: rawValue)
        }
    }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .messenger: return MessengerPlugin.shared.icon
        case .plugin(let id):
            return PluginManager.shared.plugin(for: id)?.icon ?? "puzzlepiece.extension"
        }
    }
    
    public func iconView(size: CGFloat = 11) -> AnyView {
        PluginIconManager.shared.iconView(for: self, size: size)
    }
        
    public static var builtInTabs: [IslandTab] {
        [.media, .timer, .clipboard, .notes, .messenger]
    }
    
    public static var defaultTabs: [IslandTab] {
        var tabs: [IslandTab] = [.media, .timer, .clipboard, .notes]
        if MessengerPlugin.shared.isEnabled {
            tabs.append(.messenger)
        }
        for plugin in PluginManager.shared.activePlugins where plugin.id != MessengerPlugin.pluginID {
            tabs.append(.plugin(id: plugin.id))
        }
        return tabs
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
    private func plugin(for tab: IslandTab) -> (any IslandPlugin)? {
        switch tab {
        case .messenger:
            return MessengerPlugin.shared
        case .plugin(let id):
            return PluginManager.shared.plugin(for: id)
        default:
            return nil
        }
    }
    
    private var hoverWorkItem: DispatchWorkItem?
    private var unhoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    
    private var lastCollapseTime: Date = .distantPast
    private let collapseCooldown: TimeInterval = 0.15
    
    private init() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.toggleExpand"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleExpand()
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.expandPinned"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isPinned = true
            self?.expand()
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.unpinCollapse"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isPinned = false
            self?.collapse()
        }
    }
    
    public static let expandedWidth: CGFloat = 560.0
    
    public var expandedWidth: CGFloat {
        // Single opened shell: the base width is constant. Integrated app plugins
        // still widen the island to their declared `preferredIslandWidth`.
        let baseWidth = AppState.expandedWidth
        
        switch activeTab {
        case .messenger:
            return MessengerPlugin.shared.preferredIslandWidth ?? 740.0
        case .plugin(let id):
            if let plugin = PluginManager.shared.plugin(for: id) {
                return plugin.preferredIslandWidth ?? 740.0
            }
            return baseWidth
        default:
            return baseWidth
        }
    }
    
    public var compactEarWidth: CGFloat {
        let base: CGFloat
        let settings = SettingsManager.shared
        
        if PluginNotificationManager.shared.activeNotification != nil {
            base = 135.0 // Expands both ears to show app icon + sender and message preview
        } else {
            switch settings.closedNotchStyle {
            case .defaultStyle:
                let timerVisible = settings.isTabVisible(.timer)
                let mediaVisible = settings.isTabVisible(.media)
                
                if timerVisible && TimerManager.shared.isTimerFinished {
                    base = 65.0
                } else if timerVisible && TimerManager.shared.isTimerRunning {
                    base = TimerManager.shared.remainingSeconds >= 3600 ? 78.0 : 65.0
                } else if timerVisible && (TimerManager.shared.isStopwatchRunning || TimerManager.shared.stopwatchElapsed > 0) {
                    base = TimerManager.shared.stopwatchElapsed >= 3600 ? 82.0 : 70.0
                } else if mediaVisible && (MediaManager.shared.currentTrack.isPlaying || (MediaManager.shared.currentTrack.source != .none && MediaManager.shared.currentTrack.title != "No Media Playing")) {
                    base = 50.0 // Media: icon only left, visualizer/pause right
                } else if !DropShelfManager.shared.items.isEmpty {
                    base = 50.0
                } else {
                    base = 56.0 // Idle: Apple logo left, battery % right
                }
            }
        }
        return base + CGFloat(settings.customWidthOffset) / 2.0
    }
    
    public var compactIslandWidth: CGFloat {
        let detector = NotchDetector.shared
        let settings = SettingsManager.shared
        let isNotchMode: Bool
        switch settings.notchStyle {
        case .auto: isNotchMode = detector.currentNotch.hasPhysicalNotch
        case .notch: isNotchMode = true
        case .floating: isNotchMode = false
        }
        
        if isNotchMode {
            let notchW = max(170.0, detector.currentNotch.notchWidth)
            return notchW + (compactEarWidth * 2.0) + (NotchIslandShape.compactFlareWidth * 2.0)
        } else {
            if PluginNotificationManager.shared.activeNotification != nil {
                return 440.0 + CGFloat(settings.customWidthOffset)
            }
            let isStopwatchActive = TimerManager.shared.isStopwatchRunning || TimerManager.shared.stopwatchElapsed > 0
            let mediaActive = settings.isTabVisible(.media) && MediaManager.shared.currentTrack.isPlaying
            let timerActive = settings.isTabVisible(.timer) && (TimerManager.shared.isTimerRunning || isStopwatchActive)
            let base: CGFloat = (mediaActive || timerActive) ? 260.0 : 180.0
            return base + CGFloat(settings.customWidthOffset)
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
    
    public var currentContentHeight: CGFloat {
        switch activeTab {
        case .messenger:
            return MessengerPlugin.shared.preferredContentHeight
        case .plugin(let id):
            return PluginManager.shared.plugin(for: id)?.preferredContentHeight ?? 400.0
        default:
            return 170.0
        }
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
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        if let tab = tab {
            self.activeTab = tab
        }
        if !isExpanded {
            withAnimation(IslandSpring.expand) {
                isExpanded = true
            }
            SoundManager.shared.play(.expand)
        }
    }
    
    public func collapse(force: Bool = false) {
        if isPinned && !force { return }
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        unhoverWorkItem?.cancel()
        unhoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        if force {
            isHovering = false
        }
        if isExpanded {
            withAnimation(IslandSpring.collapse) {
                isExpanded = false
            }
            lastCollapseTime = Date()
            SoundManager.shared.play(.collapse)
        }
    }
    
    public func handleMouseEnter() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard !isExpanded else { return }
        
        // Strict boundary check: cursor must physically be inside the notch / compact pill
        if let screen = NSScreen.main {
            let mouse = NSEvent.mouseLocation
            let detector = NotchDetector.shared
            let settings = SettingsManager.shared
            let isNotchMode: Bool
            switch settings.notchStyle {
            case .auto: isNotchMode = detector.currentNotch.hasPhysicalNotch
            case .notch: isNotchMode = true
            case .floating: isNotchMode = false
            }
            
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
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
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
