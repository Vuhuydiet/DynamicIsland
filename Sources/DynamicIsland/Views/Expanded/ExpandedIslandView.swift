import SwiftUI
import AppKit

// MARK: - Liquid Glass background helper
struct LiquidGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 16
    var topCornerRadius: CGFloat? = nil  // nil = same as cornerRadius

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material      = .hudWindow
        v.blendingMode  = .behindWindow
        v.state         = .active
        v.isEmphasized  = true
        v.wantsLayer    = true
        applyCorners(to: v)
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        applyCorners(to: nsView)
    }

    private func applyCorners(to v: NSVisualEffectView) {
        let topR = topCornerRadius ?? cornerRadius
        if topR == cornerRadius {
            // All four corners the same — simple path
            v.layer?.cornerRadius   = cornerRadius
            v.layer?.maskedCorners  = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                       .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            v.layer?.masksToBounds  = true
        } else {
            // In notch mode, containerShape handles the continuous curved contours with top flares
            v.layer?.cornerRadius   = 0
            v.layer?.masksToBounds  = false
        }
    }
}

// MARK: - ExpandedIslandView
/// Hosts the opened island shell.
///
/// There is currently exactly one opened-island shell (`FullHubExpandedView`).
/// `OpenedIslandStyle` is retained as a single-case enum so that the persisted
/// `openedIslandStyle` preference and its accessor stay valid; if another shell is
/// added later, extend the enum and this router together.
public struct ExpandedIslandView: View {
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        Group {
            switch settings.openedIslandStyle {
            case .defaultStyle:
                FullHubExpandedView()
            }
        }
    }
}
