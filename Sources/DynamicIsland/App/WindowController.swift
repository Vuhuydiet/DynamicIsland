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
        
        // When hidden in fullscreen, allow hit-test only if hovering, expanded, or dragging
        if appState.isFullScreen && !appState.isHovering && !appState.isExpanded && !appState.isDraggingOver {
            let pasteboard = NSPasteboard(name: .drag)
            let isDragging = (pasteboard.pasteboardItems?.count ?? 0) > 0
            if !isDragging {
                return nil
            }
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
    
    private var fullScreenTimer: Timer?
    private var lastFullScreenCheck: Date = .distantPast

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
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        startFullScreenMonitor()
        updateFullScreenState(immediate: true)
    }
    
    private var fullScreenConsecutiveHits: Int = 0
    private var nonFullScreenConsecutiveHits: Int = 0
    private let fullScreenThreshold: Int = 1

    private func startFullScreenMonitor() {
        fullScreenTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateFullScreenState()
        }
        RunLoop.main.add(timer, forMode: .common)
        fullScreenTimer = timer
    }
    
    @objc private func activeSpaceDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.updateFullScreenState(immediate: true)
        }
    }
    
    @objc private func appDidActivate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateFullScreenState(immediate: true)
        }
    }
    
    public func updateFullScreenState(immediate: Bool = false) {
        let isFS = checkIsFullScreen()
        if isFS {
            nonFullScreenConsecutiveHits = 0
            fullScreenConsecutiveHits += 1
            if (immediate || fullScreenConsecutiveHits >= fullScreenThreshold) && !AppState.shared.isFullScreen {
                DispatchQueue.main.async {
                    withAnimation(IslandSpring.collapse) {
                        AppState.shared.isFullScreen = true
                    }
                }
            }
        } else {
            fullScreenConsecutiveHits = 0
            nonFullScreenConsecutiveHits += 1
            if (immediate || nonFullScreenConsecutiveHits >= fullScreenThreshold) && AppState.shared.isFullScreen {
                DispatchQueue.main.async {
                    withAnimation(IslandSpring.collapse) {
                        AppState.shared.isFullScreen = false
                    }
                }
            }
        }
    }
    
    private typealias CGSConnectionID = Int32
    private typealias CGSMainConnectionIDFunc = @convention(c) () -> CGSConnectionID
    private typealias CGSCopyManagedDisplaySpacesFunc = @convention(c) (CGSConnectionID) -> CFArray
    private static let skylightHandle: UnsafeMutableRawPointer? = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private func isNativeFullScreenSpace(for screen: NSScreen) -> Bool {
        guard let handle = Self.skylightHandle,
              let mainConnSym = dlsym(handle, "CGSMainConnectionID"),
              let copySpacesSym = dlsym(handle, "CGSCopyManagedDisplaySpaces") else {
            return false
        }
        
        let mainConn = unsafeBitCast(mainConnSym, to: CGSMainConnectionIDFunc.self)
        let copySpaces = unsafeBitCast(copySpacesSym, to: CGSCopyManagedDisplaySpacesFunc.self)
        
        let cid = mainConn()
        guard let displays = copySpaces(cid) as? [[String: Any]], !displays.isEmpty else {
            return false
        }
        
        var targetUUID: String? = nil
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let unmanaged = CGDisplayCreateUUIDFromDisplayID(screenNumber) {
            let cfUUID = unmanaged.takeRetainedValue()
            targetUUID = CFUUIDCreateString(nil, cfUUID) as String
        }
        
        for display in displays {
            let displayID = display["Display Identifier"] as? String
            if targetUUID == nil || displayID == targetUUID {
                if let current = display["Current Space"] as? [String: Any] {
                    let type = current["type"] as? Int ?? 0
                    return type == 4 // 4 = Fullscreen Space, 0 = Desktop
                }
            }
        }
        return false
    }
    
    private func isBorderlessFullScreen(for screen: NSScreen) -> Bool {
        let screenRect = screen.frame
        let myPID = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for w in list {
            let pid = w[kCGWindowOwnerPID as String] as? pid_t ?? 0
            guard pid != myPID else { continue }
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            
            guard let bounds = w[kCGWindowBounds as String] as? [String: Any],
                  let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double,
                  let height = bounds["Height"] as? Double else { continue }
            
            let atVeryTop = y <= 0
            let coversWidth = abs(width - Double(screenRect.width)) <= 6
            let coversFullHeight = abs(height - Double(screenRect.height)) <= 6
            
            if atVeryTop && coversWidth && coversFullHeight {
                return true
            }
        }
        return false
    }

    public func checkIsFullScreen() -> Bool {
        guard let screen = self.panel?.screen ?? NSScreen.main else { return false }
        
        // 1. Presentation options check:
        let presOpts = NSApplication.shared.currentSystemPresentationOptions
        if presOpts.contains(.fullScreen) {
            return true
        }
        
        // 2. Native macOS Fullscreen Space check via SkyLight (0 = Desktop, 4 = Fullscreen Space):
        if isNativeFullScreenSpace(for: screen) {
            return true
        }
        
        // 3. Custom / Borderless Window Fullscreen check (covers entire screen including top edge):
        if isBorderlessFullScreen(for: screen) {
            return true
        }
        
        return false
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

            // Periodically refresh fullscreen state on mouse motion
            if Date().timeIntervalSince(self.lastFullScreenCheck) >= 0.5 {
                self.lastFullScreenCheck = Date()
                self.updateFullScreenState()
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
                let notchH = detector.currentNotch.notchHeight > 0 ? detector.currentNotch.notchHeight : 32.0
                let compactW = appState.compactIslandWidth
                let compactH = isNotchMode ? notchH : 34.0
                let topInset: CGFloat = isNotchMode ? 0.0 : 8.0
                let marginX: CGFloat = appState.isFullScreen ? 24.0 : 0.0
                let marginY: CGFloat = appState.isFullScreen ? 12.0 : 0.0

                let inX = mouse.x >= (screen.frame.midX - compactW / 2.0 - marginX)
                       && mouse.x <= (screen.frame.midX + compactW / 2.0 + marginX)
                let compactBottom = screen.frame.maxY - topInset - compactH - marginY
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
                            appState.handleMouseLeaveCompact()
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        fullScreenTimer?.invalidate()
        if let g = globalEventMonitor { NSEvent.removeMonitor(g) }
        if let l = localEventMonitor { NSEvent.removeMonitor(l) }
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
    }
}
