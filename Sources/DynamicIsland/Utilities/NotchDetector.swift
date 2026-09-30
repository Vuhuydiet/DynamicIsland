import Foundation
import AppKit

public struct NotchInfo: Equatable {
    public let hasPhysicalNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let screenFrame: NSRect
    public let topInset: CGFloat
    
    public static var `default`: NotchInfo {
        NotchInfo(
            hasPhysicalNotch: false,
            notchWidth: 180,
            notchHeight: 34,
            screenFrame: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
            topInset: 0
        )
    }
}

public class NotchDetector: ObservableObject {
    public static let shared = NotchDetector()
    
    @Published public private(set) var currentNotch: NotchInfo = .default
    
    private init() {
        updateNotchInfo()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersChanged() {
        DispatchQueue.main.async {
            self.updateNotchInfo()
        }
    }
    
    public func updateNotchInfo() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let safeArea = screen.safeAreaInsets
        
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           leftArea.width > 0, rightArea.width > 0 {
            let width = rightArea.minX - leftArea.maxX
            let height = safeArea.top > 0 ? safeArea.top : 34
            currentNotch = NotchInfo(
                hasPhysicalNotch: true,
                notchWidth: width,
                notchHeight: height,
                screenFrame: screenFrame,
                topInset: safeArea.top
            )
        } else {
            // Screen without physical notch (external monitor, MacBook Air M1, etc.)
            currentNotch = NotchInfo(
                hasPhysicalNotch: false,
                notchWidth: 170,
                notchHeight: 34,
                screenFrame: screenFrame,
                topInset: safeArea.top
            )
        }
    }
}
