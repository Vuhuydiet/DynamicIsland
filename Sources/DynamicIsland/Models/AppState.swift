import Foundation
import SwiftUI
import Combine

public enum IslandTab: String, CaseIterable, Identifiable, Sendable {
    case media = "Media"
    case dropShelf = "Drop Shelf"
    case timer = "Timer"
    case clipboard = "Clipboard"
    case notes = "Notes"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .dropShelf: return "tray.and.arrow.down.fill"
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
    
    private var hoverWorkItem: DispatchWorkItem?
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
    
    public var compactEarWidth: CGFloat {
        let base: CGFloat
        if TimerManager.shared.isTimerFinished {
            base = 60.0 // Timer done: bell left, "Done!" right
        } else if TimerManager.shared.isTimerRunning {
            base = 65.0
        } else if MediaManager.shared.currentTrack.isPlaying {
            base = 75.0
        } else if MediaManager.shared.currentTrack.source != .none && MediaManager.shared.currentTrack.title != "No Media Playing" {
            base = 50.0
        } else if !DropShelfManager.shared.items.isEmpty {
            base = 50.0
        } else {
            base = 56.0 // Idle ear: Apple logo left, battery % + icon right
        }
        return base + CGFloat(SettingsManager.shared.customWidthOffset) / 2.0
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
            let base: CGFloat = (MediaManager.shared.currentTrack.isPlaying || TimerManager.shared.isTimerRunning) ? 260.0 : 180.0
            return base + CGFloat(settings.customWidthOffset)
        }
    }
    
    public func expandedHeight(isNotchMode: Bool, notchHeight: CGFloat) -> CGFloat {
        let notchTopInset: CGFloat = isNotchMode ? max(34.0, notchHeight) : 8.0
        let contentH: CGFloat = 165.0
        return notchTopInset + 38.0 + contentH + 16.0
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
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
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
        
        guard SettingsManager.shared.expandTrigger == .hoverAndClick else {
            isHovering = true
            return
        }
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
            
            let inX = mouse.x >= (screen.frame.midX - compactW / 2.0)
                   && mouse.x <= (screen.frame.midX + compactW / 2.0)
            let inY = mouse.y >= (screen.frame.maxY - topInset - compactH)
            
            guard inX && inY else {
                return
            }
        }
        
        // If already hovering with a pending expand work item, don't restart/delay the timer
        if isHovering && hoverWorkItem != nil {
            return
        }
        isHovering = true
        
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
    
    public func handleMouseLeave() {
        isHovering = false
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard !isPinned else { return }
        guard isExpanded else { return }
        
        collapse()
    }
    
    /// Called by SwiftUI's .onHover when the cursor leaves the view bounds.
    /// Only updates the hover-glow and cancels any pending expand-on-hover timer.
    /// Does NOT collapse — the global mouse-movement monitor in WindowController
    /// is the sole authority for collapsing, and its rect intentionally covers the
    /// physical notch area above the island so moving into the notch never closes it.
    public func cancelHover() {
        isHovering = false
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }
    
    public func handleDragEntered() {
        isDraggingOver = true
        expand(tab: .dropShelf)
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
