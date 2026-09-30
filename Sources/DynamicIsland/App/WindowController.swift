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
    }
    
    // Allow panel to receive key events for text fields in notes/clipboard
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}

public class WindowController: ObservableObject {
    public static let shared = WindowController()
    
    public var panel: DynamicIslandPanel?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
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
        
        let panelWidth: CGFloat = 540.0
        let panelHeight: CGFloat = 340.0
        
        let screenRect = screen.frame
        let originX = screenRect.midX - (panelWidth / 2.0)
        let originY = screenRect.maxY - panelHeight
        
        let rect = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
        let newPanel = DynamicIslandPanel(contentRect: rect)
        
        let hostingView = NSHostingView(rootView: IslandContainerView())
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        newPanel.contentView = hostingView
        
        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }
    
    public func repositionPanel() {
        guard let screen = NSScreen.main, let panel = self.panel else { return }
        
        let panelWidth: CGFloat = 540.0
        let panelHeight: CGFloat = 340.0
        let screenRect = screen.frame
        let originX = screenRect.midX - (panelWidth / 2.0)
        let originY = screenRect.maxY - panelHeight
        
        panel.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
    }
    
    private func setupEventMonitors() {
        // Global monitor for Esc key or toggle hotkey
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc key collapses island
            if event.keyCode == 53 && AppState.shared.isExpanded {
                AppState.shared.collapse(force: true)
                return nil
            }
            return event
        }
        
        // Listen for Option + Command + I to toggle island
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .option]) && event.charactersIgnoringModifiers == "i" {
                DispatchQueue.main.async {
                    AppState.shared.toggleExpand()
                }
            }
        }
    }
    
    deinit {
        if let g = globalEventMonitor { NSEvent.removeMonitor(g) }
        if let l = localEventMonitor { NSEvent.removeMonitor(l) }
    }
}
