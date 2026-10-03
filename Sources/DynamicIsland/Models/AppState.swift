import Foundation
import SwiftUI
import Combine

public enum IslandTab: String, CaseIterable, Identifiable, Sendable {
    case media = "Media"
    case timer = "Timer"
    case clipboard = "Clipboard"
    case notes = "Notes"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        }
    }
}

public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var isExpanded: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var activeTab: IslandTab = .media
    @Published public var isHovering: Bool = false
    @Published public var isDraggingOver: Bool = false
    @Published public var isFullScreen: Bool = false
    
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
        switch SettingsManager.shared.openedIslandStyle {
        case .defaultStyle:   return 560.0
        case .bottomDeck:     return 560.0
        case .compactHUD:     return 490.0
        case .floatingCards:  return 560.0
        case .commandCenter:  return 580.0
        }
    }
    
    public var compactEarWidth: CGFloat {
        let base: CGFloat
        let settings = SettingsManager.shared
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
    
    public func expandedHeight(isNotchMode: Bool, notchHeight: CGFloat) -> CGFloat {
        let notchTopInset: CGFloat = isNotchMode ? max(34.0, notchHeight) : 8.0
        switch SettingsManager.shared.openedIslandStyle {
        case .defaultStyle:
            let contentH: CGFloat = 170.0
            return notchTopInset + 38.0 + contentH + 16.0
        case .bottomDeck:
            let contentH: CGFloat = 170.0
            return notchTopInset + 38.0 + contentH + 46.0 + 16.0
        case .compactHUD:
            let contentH: CGFloat = 165.0
            return notchTopInset + 32.0 + contentH + 14.0
        case .floatingCards:
            let contentH: CGFloat = 170.0
            return notchTopInset + 42.0 + contentH + 20.0
        case .commandCenter:
            let contentH: CGFloat = 170.0
            return notchTopInset + 40.0 + contentH + 16.0
        }
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
