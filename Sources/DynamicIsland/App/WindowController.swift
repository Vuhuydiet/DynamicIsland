import AppKit
import SwiftUI

public class DynamicIslandPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
    }
    
    // Allow panel to receive key events for text fields in notes/clipboard
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}

public class DynamicIslandHostingView: NSHostingView<IslandContainerView> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let appState = AppState.shared
        let detector = NotchDetector.shared
        let settings = SettingsManager.shared
        
        let isNotchMode: Bool
        switch settings.notchStyle {
        case .auto: isNotchMode = detector.currentNotch.hasPhysicalNotch
        case .notch: isNotchMode = true
        case .floating: isNotchMode = false
        }
        
        let bounds = self.bounds
        let centerX = bounds.midX
        let topY = bounds.maxY
        
        if appState.isExpanded {
            let expandedW: CGFloat = appState.expandedWidth
            let expandedH = appState.totalExpandedHeight(isNotchMode: isNotchMode, notchHeight: detector.currentNotch.notchHeight)
            let margin: CGFloat = 14.0
            
            let inX = point.x >= (centerX - expandedW / 2.0 - margin)
                   && point.x <= (centerX + expandedW / 2.0 + margin)
            let inY = point.y >= (topY - expandedH - margin)
            
            if inX && inY {
                return super.hitTest(point)
            }
            return nil
        } else {
            // Compact mode: physical notch plus active ears
            let notchH = detector.currentNotch.notchHeight > 0 ? detector.currentNotch.notchHeight : 32.0
            let compactW = appState.compactIslandWidth
            let compactH = isNotchMode ? notchH : 34.0
            let topInset: CGFloat = isNotchMode ? 0.0 : 8.0
            
            let inX = point.x >= (centerX - compactW / 2.0)
                   && point.x <= (centerX + compactW / 2.0)
            let inY = point.y >= (topY - topInset - compactH)
            
            if inX && inY {
                return super.hitTest(point)
            }
            return nil
        }
    }
}

public class WindowController: ObservableObject {
    public static let shared = WindowController()
    
    public var panel: DynamicIslandPanel?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var globalMouseMonitor: Any?
    
    private init() {}
    
    public func setup() {
        createAndShowPanel()
        setupEventMonitors()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenDidChange() {
        DispatchQueue.main.async {
            self.repositionPanel()
        }
    }
    
    public func createAndShowPanel() {
        guard let screen = NSScreen.main else { return }
        
        let panelWidth: CGFloat = 640.0
        let panelHeight: CGFloat = 480.0
        
        let screenRect = screen.frame
        let originX = screenRect.midX - (panelWidth / 2.0)
        let originY = screenRect.maxY - panelHeight
        
        let rect = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
        let newPanel = DynamicIslandPanel(contentRect: rect)
        
        let hostingView = DynamicIslandHostingView(rootView: IslandContainerView())
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        newPanel.contentView = hostingView
        
        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }
    
    public func repositionPanel() {
        guard let screen = NSScreen.main, let panel = self.panel else { return }
        
        let panelWidth: CGFloat = 640.0
        let panelHeight: CGFloat = 480.0
        let screenRect = screen.frame
        let originX = screenRect.midX - (panelWidth / 2.0)
        let originY = screenRect.maxY - panelHeight
        
        panel.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
    }
    
    private func setupEventMonitors() {
        // Local monitor for Esc key, Command + Comma, etc.
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc key collapses island
            if event.keyCode == 53 && AppState.shared.isExpanded {
                AppState.shared.collapse(force: true)
                return nil
            }
            // Command + Comma opens preferences
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
                SettingsWindowController.shared.show()
                return nil
            }
            return event
        }
        
        // Listen for Option + Command + I to toggle island or Option + Command + Comma for settings
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .option]) {
                if event.charactersIgnoringModifiers == "i" {
                    DispatchQueue.main.async {
                        AppState.shared.toggleExpand()
                    }
                } else if event.charactersIgnoringModifiers == "," {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.show()
                    }
                }
            }
        }
        
        // Global mouse movement monitor: handles mouse-enter hover detection and collapses when cursor leaves bounds.
        // NOTE: We do NOT use NSRect.contains because it is exclusive of the max edge —
        // a point at exactly screen.frame.maxY (the screen top) would fail the check and
        // incorrectly trigger a collapse. Instead we use an open-top boundary: only
        // collapse when the mouse is BELOW the island or outside its horizontal range.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            let appState = AppState.shared
            guard let screen = self.panel?.screen ?? NSScreen.main else { return }

            let mouse = NSEvent.mouseLocation
            let detector = NotchDetector.shared
            let settings = SettingsManager.shared
            let isNotchMode: Bool
            switch settings.notchStyle {
            case .auto: isNotchMode = detector.currentNotch.hasPhysicalNotch
            case .notch: isNotchMode = true
            case .floating: isNotchMode = false
            }

            if appState.isExpanded {
                guard !appState.isPinned else { return }

                let islandW: CGFloat = appState.expandedWidth
                let expandedH = appState.totalExpandedHeight(isNotchMode: isNotchMode, notchHeight: detector.currentNotch.notchHeight)
                let islandBottom: CGFloat = screen.frame.maxY - expandedH
                let margin: CGFloat = 14.0

                let inX = mouse.x >= (screen.frame.midX - islandW / 2.0 - margin)
                       && mouse.x <= (screen.frame.midX + islandW / 2.0 + margin)
                // Open-top: only check that cursor is above the island's bottom edge.
                // No upper-Y check — the cursor physically cannot go above the screen top.
                let inY = mouse.y >= (islandBottom - margin)

                if !(inX && inY) {
                    DispatchQueue.main.async {
                        if appState.isExpanded && !appState.isPinned {
                            appState.handleMouseLeave()
                        }
                    }
                }
            } else {
                guard settings.expandTrigger == .hoverAndClick else { return }

                let notchH = detector.currentNotch.notchHeight > 0 ? detector.currentNotch.notchHeight : 32.0
                let compactW = appState.compactIslandWidth
                let compactH = isNotchMode ? notchH : 34.0
                let topInset: CGFloat = isNotchMode ? 0.0 : 8.0

                let inX = mouse.x >= (screen.frame.midX - compactW / 2.0)
                       && mouse.x <= (screen.frame.midX + compactW / 2.0)
                let compactBottom = screen.frame.maxY - topInset - compactH
                let inY = mouse.y >= compactBottom

                if inX && inY {
                    DispatchQueue.main.async {
                        if !appState.isExpanded {
                            appState.handleMouseEnter()
                        }
                    }
                } else if appState.isHovering && !appState.isExpanded {
                    DispatchQueue.main.async {
                        if !appState.isExpanded {
                            appState.cancelHover()
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        if let g = globalEventMonitor { NSEvent.removeMonitor(g) }
        if let l = localEventMonitor { NSEvent.removeMonitor(l) }
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
    }
}
