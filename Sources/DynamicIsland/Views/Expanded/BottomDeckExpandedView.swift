import SwiftUI

public struct BottomDeckExpandedView: View {
    @ObservedObject var appState  = AppState.shared
    @ObservedObject var detector  = NotchDetector.shared
    @ObservedObject var settings  = SettingsManager.shared
    @StateObject private var dragCoordinator = TabDragCoordinator()
    @Namespace private var dockNamespace

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

    private var expandedWidth: CGFloat { appState.expandedWidth }

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
                    .padding(.leading, 38)
                    .frame(width: earWidth, alignment: .leading)

                    // Physical notch cutout
                    Color.clear
                        .frame(width: notchWidth, height: notchRowHeight)
                        .contentShape(Rectangle())

                    // Right Ear: Stats + Pin
                    HStack(spacing: 5) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 36)
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
                    .padding(.leading, 24)

                    Spacer()

                    HStack(spacing: 5) {
                        CondensedSystemHUDView()
                        pinButton
                    }
                    .padding(.trailing, 22)
                }
                .frame(height: 32)
                .padding(.top, 4)
            }

            // ── Divider ──────────────────────────────────────────────────
            glassRuler
                .padding(.horizontal, 36)
                .padding(.top, 4)
                .padding(.bottom, 6)

            // ── Tab Content (Positioned First) ────────────────────────────
            IslandTabContentView()
                .frame(height: appState.currentContentHeight, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.bottom, 6)

            // ── Divider before Bottom Dock ────────────────────────────────
            glassRuler
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

            // ── Bottom Dock Navigation Bar ────────────────────────────────
            let visibleTabs = IslandTab.allCases.filter { settings.isTabVisible($0) }
            let totalBarWidth = expandedWidth - 76
            let spacing: CGFloat = 6
            let count = max(1, visibleTabs.count)
            let pillWidth = (totalBarWidth - CGFloat(count - 1) * spacing) / CGFloat(count)
            let slotStep = pillWidth + spacing

            HStack(spacing: spacing) {
                ForEach(visibleTabs) { tab in
                    dockPill(tab, visibleTabs: visibleTabs, slotStep: slotStep)
                }
            }
            .animation(IslandSpring.tabSlide, value: visibleTabs)
            .padding(.horizontal, 38)
            .padding(.bottom, 12)
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
                .font(IslandFont.iconRegular)
                .foregroundColor(appState.isPinned ? .orange : .white.opacity(0.7))
                .rotationEffect(appState.isPinned ? .degrees(0) : .degrees(-15))
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
    private func dockPill(_ tab: IslandTab, visibleTabs: [IslandTab], slotStep: CGFloat) -> some View {
        let isActive = appState.activeTab == tab
        let isDragging = dragCoordinator.draggingTab == tab

        HStack(spacing: 5) {
            tab.iconView(size: isActive ? 12 : 11)
                .scaleEffect(isActive ? 1.08 : 1.0)
            if isActive {
                Text(tab.rawValue)
                    .font(IslandFont.caption)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .foregroundColor(isActive ? .white : .white.opacity(0.50))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background {
            ZStack {
                if isActive {
                    Capsule()
                        .fill(Color.white.opacity(isDragging ? 0.26 : 0.20))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isDragging ? 0.60 : 0.28), lineWidth: isDragging ? 1.0 : 0.5)
                        )
                        .shadow(color: isDragging ? .white.opacity(0.35) : .white.opacity(0.08), radius: isDragging ? 8 : 5, x: 0, y: isDragging ? 2 : -1)
                        .matchedGeometryEffect(id: "bottomDeckActiveTabIndicator", in: dockNamespace)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(isDragging ? 0.14 : 0.04))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isDragging ? 0.45 : 0.06), lineWidth: isDragging ? 1.0 : 0.5)
                        )
                        .shadow(color: isDragging ? .white.opacity(0.25) : .clear, radius: isDragging ? 6 : 0, x: 0, y: 1)
                }
            }
        }
        .contentShape(Rectangle())
        .help("Click to open · Drag to reorder")
        .islandTabReorderDrag(
            tab: tab,
            orderedTabs: visibleTabs,
            slotStep: slotStep,
            coordinator: dragCoordinator
        ) { selectedTab in
            SoundManager.shared.play(.click)
            withAnimation(IslandSpring.tabSlide) {
                appState.activeTab = selectedTab
            }
        }
        .animation(IslandSpring.tabSlide, value: isActive)
    }
}
