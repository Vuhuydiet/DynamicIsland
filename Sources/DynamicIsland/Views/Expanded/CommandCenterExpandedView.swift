import SwiftUI

public struct CommandCenterExpandedView: View {
    @ObservedObject var appState         = AppState.shared
    @ObservedObject var detector         = NotchDetector.shared
    @ObservedObject var settings         = SettingsManager.shared
    @ObservedObject var mediaManager     = MediaManager.shared
    @ObservedObject var dropManager      = DropShelfManager.shared
    @ObservedObject var timerManager     = TimerManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var notesManager     = NotesManager.shared
    @Namespace private var cmdNamespace

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
                    // Left Ear: Title + Status Dot
                    Button {
                        SoundManager.shared.play(.click)
                        SettingsWindowController.shared.show()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isAnyActivityRunning ? Color.green : Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .shadow(color: isAnyActivityRunning ? Color.green.opacity(0.8) : Color.clear, radius: 3)
                            Text("Dynamic Hub")
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
                                .fill(isAnyActivityRunning ? Color.green : Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .shadow(color: isAnyActivityRunning ? Color.green.opacity(0.8) : Color.clear, radius: 3)
                            Text("Dynamic Hub")
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

            // ── Live Contextual Badged Tab Bar ────────────────────────────
            let visibleTabs = IslandTab.allCases.filter { settings.isTabVisible($0) }
            HStack(spacing: 4) {
                ForEach(visibleTabs) { tab in
                    commandTabPill(tab)
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 6)
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

            // ── Divider before Content ────────────────────────────────────
            glassRuler
                .padding(.horizontal, 36)
                .padding(.bottom, 6)

            // ── Tab Content Viewport ──────────────────────────────────────
            IslandTabContentView()
                .frame(height: 170, alignment: .top)
                .padding(.horizontal, 32)
                .padding(.bottom, 6)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private var isAnyActivityRunning: Bool {
        mediaManager.currentTrack.isPlaying ||
        timerManager.isTimerRunning ||
        timerManager.isStopwatchRunning ||
        !dropManager.items.isEmpty
    }

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
    private func commandTabPill(_ tab: IslandTab) -> some View {
        let isActive = appState.activeTab == tab
        Button {
            SoundManager.shared.play(.click)
            withAnimation(IslandSpring.tabSlide) {
                appState.activeTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(IslandFont.iconSmall)

                Text(tab.rawValue)
                    .font(IslandFont.caption)
                    .lineLimit(1)

                // Contextual Live Badge
                badgeForTab(tab)
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.50))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.26), lineWidth: 0.5)
                            )
                            .shadow(color: .white.opacity(0.08), radius: 4, x: 0, y: -1)
                            .matchedGeometryEffect(id: "commandCenterActiveTabIndicator", in: cmdNamespace)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .buttonStyle(PillButtonStyle())
        .animation(IslandSpring.tabSlide, value: isActive)
    }

    @ViewBuilder
    private func badgeForTab(_ tab: IslandTab) -> some View {
        switch tab {
        case .media:
            if mediaManager.currentTrack.isPlaying {
                Image(systemName: "waveform")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
            }

        case .timer:
            if timerManager.isTimerRunning {
                let m = timerManager.remainingSeconds / 60
                let s = timerManager.remainingSeconds % 60
                Text(String(format: "%02d:%02d", m, s))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
            } else if timerManager.isStopwatchRunning {
                let m = Int(timerManager.stopwatchElapsed) / 60
                let s = Int(timerManager.stopwatchElapsed) % 60
                Text(String(format: "%02d:%02d", m, s))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
            }

        case .clipboard:
            if !clipboardManager.history.isEmpty {
                Text("\(clipboardManager.history.count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.purple.opacity(0.2)))
            }

        case .notes:
            if !notesManager.noteText.isEmpty {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 4, height: 4)
            }
        }
    }
}
