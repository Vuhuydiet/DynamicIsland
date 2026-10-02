import AppKit
import SwiftUI

public class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    public var window: NSWindow?
    
    private override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.showSettings"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.show()
        }
    }
    
    public func show() {
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let width: CGFloat = 680
        let height: CGFloat = 780
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Dynamic Island Settings"
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
