import AppKit
import SwiftUI

public class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    public var window: NSWindow?

    /// Token for the block-based distributed-notification observer installed in
    /// `init`. Held so `deinit` can unregister it.
    private var observationToken: (any NSObjectProtocol)?

    private override init() {
        super.init()
        observationToken = DistributedObservationTokens.observe([
            "com.dynamicisland.showSettings": { [weak self] _ in
                self?.show()
            },
        ]).first
    }

    deinit {
        if let observationToken {
            DistributedObservationTokens.remove([observationToken])
        }
    }
    
    public func show() {
        let collapseAction = {
            if AppState.shared.isExpanded && !AppState.shared.isPinned {
                AppState.shared.collapse()
            }
        }
        
        if Thread.isMainThread {
            collapseAction()
        } else {
            DispatchQueue.main.async(execute: collapseAction)
        }
        
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let width: CGFloat = 780
        let height: CGFloat = 640
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Dynamic Island Settings"
        newWindow.minSize = NSSize(width: 720, height: 560)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        let hostingView = NSHostingView(rootView: SettingsWindowView())
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        newWindow.contentView = hostingView
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Window closed
    }
}
