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

/// Resolves the user's docking preference against the detected hardware into a
/// single boolean.
///
/// ## Why this is one function
///
/// The answer decides island geometry, the *drawn* silhouette, and the *clickable*
/// region — and the click region is a hand-written open-top rectangle that this
/// project learned the hard way (`docs/ARCHITECTURE.md` §2). Keeping two copies in
/// step was previously left to discipline: the `switch` over `NotchStyle` was
/// duplicated at seven call sites, two of which sized the hit test and two of which
/// drew the matching shape. A one-line change to any single copy would silently
/// desynchronise what the island *looks* like from what it *responds* to, and the
/// symptom is a dead or floating clickable area — not a build error.
///
/// So the policy lives here, once. The pure function is both the definition and the
/// unit test surface; `NotchDetector.isNotchMode` is the only way production code
/// asks the question, which means a new call site cannot bypass the rule
/// (AGENTS.md §1.1, levels 1 and 3).
public enum DockingMode {
    /// Whether the island attaches to the hardware notch for the given inputs.
    ///
    /// - Parameters:
    ///   - style: The user's persisted docking preference.
    ///   - hasPhysicalNotch: Whether the current screen actually has a notch.
    /// - Returns: `true` for notch-mode presentation, `false` for a floating pill.
    public static func isNotchMode(style: NotchStyle, hasPhysicalNotch: Bool) -> Bool {
        switch style {
        case .auto:     return hasPhysicalNotch
        case .notch:    return true
        case .floating: return false
        }
    }
}

public class NotchDetector: ObservableObject {
    public static let shared = NotchDetector()

    @Published public private(set) var currentNotch: NotchInfo = .default

    /// Whether the island is currently presented in notch mode.
    ///
    /// The single production entry point for "is this a notch island or a floating
    /// pill". Every geometry, hit-test, and layout decision must read this rather
    /// than re-deriving it from `SettingsManager.shared.notchStyle`, so the drawn
    /// silhouette and the clickable region can never disagree.
    public var isNotchMode: Bool {
        DockingMode.isNotchMode(
            style: SettingsManager.shared.notchStyle,
            hasPhysicalNotch: currentNotch.hasPhysicalNotch
        )
    }

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
