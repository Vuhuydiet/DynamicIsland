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
    
    private init() {}
    
    public func toggleExpand() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    public func expand(tab: IslandTab? = nil) {
        collapseWorkItem?.cancel()
        if let tab = tab {
            self.activeTab = tab
        }
        if !isExpanded {
            isExpanded = true
            SoundManager.shared.play(.expand)
        }
    }
    
    public func collapse(force: Bool = false) {
        if isPinned && !force { return }
        hoverWorkItem?.cancel()
        collapseWorkItem?.cancel()
        if isExpanded {
            isExpanded = false
            SoundManager.shared.play(.collapse)
        }
    }
    
    public func handleMouseEnter() {
        isHovering = true
        collapseWorkItem?.cancel()
        
        guard SettingsManager.shared.expandTrigger == .hoverAndClick else { return }
        guard !isExpanded else { return }
        
        hoverWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovering else { return }
            self.expand()
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + SettingsManager.shared.hoverDelay, execute: work)
    }
    
    public func handleMouseLeave() {
        isHovering = false
        hoverWorkItem?.cancel()
        collapseWorkItem?.cancel()
        
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
