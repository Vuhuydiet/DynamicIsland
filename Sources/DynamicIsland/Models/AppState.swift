import Foundation
import SwiftUI
import Combine

public enum IslandTab: String, CaseIterable, Identifiable {
    case media = "Music"
    case dropShelf = "Drop Shelf"
    case system = "System"
    case timer = "Timer"
    case clipboard = "Clipboard"
    case notes = "Notes"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .dropShelf: return "tray.and.arrow.down.fill"
        case .system: return "gauge.with.needle.fill"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .settings: return "gearshape.fill"
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
        
        guard !isPinned else { return }
        guard isExpanded else { return }
        
        collapseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isHovering, !self.isPinned else { return }
            self.collapse()
        }
        collapseWorkItem = work
        // Small grace period before collapsing so user doesn't accidentally dismiss it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
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
