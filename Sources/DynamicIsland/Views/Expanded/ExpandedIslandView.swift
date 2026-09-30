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
            // Flat top, rounded bottom
            // NSVisualEffectView doesn't support per-corner radii directly,
            // so we set bottom radius and mask only bottom corners.
            v.layer?.cornerRadius   = cornerRadius
            // On macOS, MinY = bottom edge (Cocoa coords), MaxY = top edge
            v.layer?.maskedCorners  = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            v.layer?.masksToBounds  = true
        }
    }
}

// MARK: - ExpandedIslandView
public struct ExpandedIslandView: View {
    @ObservedObject var appState  = AppState.shared
    @ObservedObject var detector  = NotchDetector.shared
    @ObservedObject var settings  = SettingsManager.shared

    private var isNotchMode: Bool {
        switch settings.notchStyle {
        case .auto:     return detector.currentNotch.hasPhysicalNotch
        case .notch:    return true
        case .floating: return false
        }
    }

    private var notchRowHeight: CGFloat {
        isNotchMode ? max(34.0, detector.currentNotch.notchHeight) : 8.0
    }

    private var notchWidth: CGFloat {
        max(170.0, detector.currentNotch.notchWidth)
    }

    private var expandedWidth: CGFloat { 600.0 }

    private var earWidth: CGFloat {
        max(0, (expandedWidth - notchWidth) / 2.0)
    }

    public var body: some View {
        VStack(spacing: 0) {

            // ── Row 1: Header ────────────────────────────────────────────
            if isNotchMode {
                HStack(spacing: 0) {
                    // Left Ear: Title
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "apple.logo")
                                .font(IslandFont.iconSmall)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Dynamic Island")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open Preferences (⌘,)")
                    .padding(.leading, 12)
                    .frame(width: earWidth, alignment: .leading)

                    // Physical notch cutout
                    Color.clear
                        .frame(width: notchWidth, height: notchRowHeight)

                    // Right Ear: Stats + Pin
                    HStack(spacing: 5) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 10)
                    .frame(width: earWidth, alignment: .trailing)
                }
                .frame(width: expandedWidth, height: notchRowHeight)

            } else {
                // Floating Mode header
                HStack {
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "apple.logo")
                                .font(IslandFont.iconSmall)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Dynamic Island")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open Preferences (⌘,)")
                    .padding(.leading, 14)

                    Spacer()

                    HStack(spacing: 5) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 12)
                }
                .frame(height: 32)
                .padding(.top, 4)
            }

            // ── Divider ──────────────────────────────────────────────────
            glassRuler
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 5)

            // ── Tab Bar — full width, equally spaced ─────────────────────
            HStack(spacing: 4) {
                ForEach(IslandTab.allCases) { tab in
                    tabPill(tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 5)

            // ── Thin divider before content ───────────────────────────────
            glassRuler
                .padding(.horizontal, 14)
                .padding(.bottom, 5)

            // ── Tab Content ───────────────────────────────────────────────
            ZStack(alignment: .top) {
                switch appState.activeTab {
                case .media:     MediaView()
                case .dropShelf: DropShelfView()
                case .timer:     TimerView()
                case .clipboard: ClipboardView()
                case .notes:     NotesView()
                }
            }
            .frame(height: 165, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            .padding(.bottom, 6)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private var pinButton: some View {
        Button {
            SoundManager.shared.play(.click)
            appState.isPinned.toggle()
        } label: {
            Image(systemName: appState.isPinned ? "pin.fill" : "pin")
                .font(IslandFont.iconRegular)
                .foregroundColor(appState.isPinned ? .orange : .white.opacity(0.7))
                .padding(5)
                .background(
                    appState.isPinned
                        ? Color.orange.opacity(0.18)
                        : Color.white.opacity(0.09)
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(
                    appState.isPinned
                        ? Color.orange.opacity(0.35)
                        : Color.white.opacity(0.12),
                    lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(appState.isPinned ? "Unpin Island" : "Pin Island Open")
    }

    /// A subtle translucent Liquid-Glass divider line
    private var glassRuler: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: 0.5)
                .offset(y: 0.5)
        }
    }

    /// Full-width Liquid Glass tab pill
    @ViewBuilder
    private func tabPill(_ tab: IslandTab) -> some View {
        let isActive = appState.activeTab == tab
        Button {
            SoundManager.shared.play(.click)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                appState.activeTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(IslandFont.iconSmall)
                if isActive {
                    Text(tab.rawValue)
                        .font(IslandFont.caption)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.50))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            // Liquid-Glass look
            .background {
                if isActive {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                        .shadow(color: .white.opacity(0.06), radius: 4, x: 0, y: -1)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isActive)
    }
}
