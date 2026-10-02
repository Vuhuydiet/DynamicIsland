import SwiftUI

public struct CompactHUDExpandedView: View {
    @ObservedObject var appState  = AppState.shared
    @ObservedObject var detector  = NotchDetector.shared
    @ObservedObject var settings  = SettingsManager.shared
    @Namespace private var segmentNamespace

    private var isNotchMode: Bool {
        switch settings.notchStyle {
        case .auto:     return detector.currentNotch.hasPhysicalNotch
        case .notch:    return true
        case .floating: return false
        }
    }

    private var notchRowHeight: CGFloat {
        isNotchMode ? max(32.0, detector.currentNotch.notchHeight) : 8.0
    }

    private var notchWidth: CGFloat {
        max(170.0, detector.currentNotch.notchWidth)
    }

    private var expandedWidth: CGFloat { appState.expandedWidth }

    private var earWidth: CGFloat {
        max(0, (expandedWidth - notchWidth) / 2.0)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Row 1: Header ────────────────────────────────────────────
            if isNotchMode {
                HStack(spacing: 0) {
                    // Left Ear: Compact Title
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Dynamic")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open Preferences (⌘,)")
                    .padding(.leading, 26)
                    .frame(width: earWidth, alignment: .leading)

                    // Notch cutout
                    Color.clear
                        .frame(width: notchWidth, height: notchRowHeight)
                        .contentShape(Rectangle())

                    // Right Ear: Stats + Pin
                    HStack(spacing: 4) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 24)
                    .frame(width: earWidth, alignment: .trailing)
                }
                .frame(width: expandedWidth, height: notchRowHeight)

            } else {
                HStack {
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Dynamic")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open Preferences (⌘,)")
                    .padding(.leading, 18)

                    Spacer()

                    HStack(spacing: 4) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 18)
                }
                .frame(height: 30)
                .padding(.top, 4)
            }

            // ── Divider ──────────────────────────────────────────────────
            glassRuler
                .padding(.horizontal, 26)
                .padding(.top, 3)
                .padding(.bottom, 5)

            // ── Segmented Control Tab Bar ─────────────────────────────────
            let visibleTabs = IslandTab.allCases.filter { settings.isTabVisible($0) }
            HStack(spacing: 2) {
                ForEach(visibleTabs) { tab in
                    segmentedTabItem(tab)
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 5)
            .onAppear {
                if !settings.isTabVisible(appState.activeTab),
                   let first = visibleTabs.first {
                    appState.activeTab = first
                }
            }
            .onChange(of: settings.hiddenTabs) { _, _ in
                if !settings.isTabVisible(appState.activeTab),
                   let first = visibleTabs.first {
                    withAnimation(IslandSpring.tabSlide) { appState.activeTab = first }
                }
            }

            // ── Content Divider ──────────────────────────────────────────
            glassRuler
                .padding(.horizontal, 26)
                .padding(.bottom, 5)

            // ── Tab Content ───────────────────────────────────────────────
            IslandTabContentView()
                .frame(height: 165, alignment: .top)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private var pinButton: some View {
        Button {
            SoundManager.shared.play(.click)
            withAnimation(IslandSpring.bouncy) {
                appState.isPinned.toggle()
            }
        } label: {
            Image(systemName: appState.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(appState.isPinned ? .orange : .white.opacity(0.7))
                .rotationEffect(appState.isPinned ? .degrees(0) : .degrees(-15))
                .padding(4)
                .background(
                    appState.isPinned
                        ? Color.orange.opacity(0.18)
                        : Color.white.opacity(0.09)
                )
                .clipShape(Circle())
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
        .help(appState.isPinned ? "Unpin Island" : "Pin Island Open")
    }

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

    @ViewBuilder
    private func segmentedTabItem(_ tab: IslandTab) -> some View {
        let isActive = appState.activeTab == tab
        Button {
            SoundManager.shared.play(.click)
            withAnimation(IslandSpring.tabSlide) {
                appState.activeTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                if isActive {
                    Text(tab.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.50))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background {
                if isActive {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: .white.opacity(0.08), radius: 3)
                        .matchedGeometryEffect(id: "compactHUDActiveTabIndicator", in: segmentNamespace)
                }
            }
        }
        .buttonStyle(PillButtonStyle())
        .animation(IslandSpring.tabSlide, value: isActive)
    }
}
