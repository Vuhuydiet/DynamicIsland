import SwiftUI

public struct FloatingCardsExpandedView: View {
    @ObservedObject var appState  = AppState.shared
    @ObservedObject var detector  = NotchDetector.shared
    @ObservedObject var settings  = SettingsManager.shared
    @StateObject private var dragCoordinator = TabDragCoordinator()
    @Namespace private var chipNamespace

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
                    // Left Ear: Title with ambient orb
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 7, height: 7)
                                .shadow(color: .cyan.opacity(0.5), radius: 3)
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

                    // Notch cutout
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
                HStack {
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 7, height: 7)
                                .shadow(color: .cyan.opacity(0.5), radius: 3)
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

            // ── Floating Tab Chips ────────────────────────────────────────
            let visibleTabs = IslandTab.allCases.filter { settings.isTabVisible($0) }
            let totalBarWidth = expandedWidth - 72
            let spacing: CGFloat = 6
            let count = max(1, visibleTabs.count)
            let pillWidth = (totalBarWidth - CGFloat(count - 1) * spacing) / CGFloat(count)
            let slotStep = pillWidth + spacing

            HStack(spacing: spacing) {
                ForEach(visibleTabs) { tab in
                    floatingTabChip(tab, visibleTabs: visibleTabs, slotStep: slotStep)
                }
            }
            .animation(IslandSpring.tabSlide, value: visibleTabs)
            .padding(.horizontal, 36)
            .padding(.top, 4)
            .padding(.bottom, 8)
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

            // ── Elevated Glass Content Card ───────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)

                IslandTabContentView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .frame(height: appState.currentContentHeight, alignment: .top)
            .padding(.horizontal, 30)
            .padding(.bottom, 8)
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

    @ViewBuilder
    private func floatingTabChip(_ tab: IslandTab, visibleTabs: [IslandTab], slotStep: CGFloat) -> some View {
        let isActive = appState.activeTab == tab
        let isDragging = dragCoordinator.draggingTab == tab

        HStack(spacing: 5) {
            tab.iconView(size: 11)
            if isActive {
                Text(tab.rawValue)
                    .font(IslandFont.caption)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .foregroundColor(isActive ? .white : .white.opacity(0.50))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isDragging ? 0.32 : 0.24), Color.white.opacity(isDragging ? 0.20 : 0.14)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(isDragging ? 0.55 : 0.35), Color.white.opacity(0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: isDragging ? 1.0 : 0.75
                                )
                        )
                        .shadow(color: isDragging ? .white.opacity(0.30) : Color.accentColor.opacity(0.25), radius: isDragging ? 8 : 6, x: 0, y: 2)
                        .matchedGeometryEffect(id: "floatingCardsActiveTabIndicator", in: chipNamespace)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(isDragging ? 0.14 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(isDragging ? 0.45 : 0.07), lineWidth: isDragging ? 1.0 : 0.5)
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
