import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var notifManager = PluginNotificationManager.shared

    // Drives the bell wobble on the compact notch
    @State private var bellWobble = false

    private var isNotchMode: Bool {
        switch settings.notchStyle {
        case .auto: return detector.currentNotch.hasPhysicalNotch
        case .notch: return true
        case .floating: return false
        }
    }

    private var notchWidth: CGFloat {
        max(170.0, detector.currentNotch.notchWidth)
    }

    private var notchHeight: CGFloat {
        max(32.0, detector.currentNotch.notchHeight)
    }

    private var earWidth: CGFloat {
        appState.compactEarWidth
    }

    public var body: some View {
        Group {
            if isNotchMode {
                HStack(spacing: 0) {
                    // MARK: - Left Outer Flare Spacer (under the left curve)
                    Color.clear
                        .frame(width: NotchIslandShape.compactFlareWidth)

                    // MARK: - Left Ear (To the left of the physical camera notch)
                    if earWidth > 0 {
                        leftEarContent
                            .padding(.leading, 4)
                            .padding(.trailing, 6)
                            .frame(width: earWidth, alignment: .trailing)
                            .clipped()
                    }

                    // MARK: - Center Notch Cutout (Hardware Camera Notch)
                    Color.clear
                        .frame(width: notchWidth, height: notchHeight)

                    // MARK: - Right Ear (To the right of the physical camera notch)
                    if earWidth > 0 {
                        rightEarContent
                            .padding(.leading, 6)
                            .padding(.trailing, 4)
                            .frame(width: earWidth, alignment: .leading)
                            .clipped()
                    }

                    // MARK: - Right Outer Flare Spacer (under the right curve)
                    Color.clear
                        .frame(width: NotchIslandShape.compactFlareWidth)
                }
            } else {
                HStack(spacing: 8) {
                    leftEarContent
                    Spacer(minLength: 16)
                    rightEarContent
                }
                .padding(.horizontal, 14)
            }
        }
        .frame(height: notchHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            SoundManager.shared.play(.click)
            if let notif = notifManager.activeNotification {
                notifManager.dismissActive()
                appState.expand(tab: notif.tab)
                return
            }
            if settings.isTabVisible(.timer) && timerManager.isTimerFinished {
                timerManager.mode = .timer
                appState.expand(tab: .timer)
            } else if settings.isTabVisible(.timer) && (timerManager.isStopwatchRunning || timerManager.stopwatchElapsed > 0) {
                timerManager.mode = .stopwatch
                appState.expand(tab: .timer)
            } else if settings.isTabVisible(.timer) && timerManager.isTimerRunning {
                timerManager.mode = .timer
                appState.expand(tab: .timer)
            } else {
                appState.toggleExpand()
            }
        }
        .onChange(of: timerManager.isTimerFinished) { _, finished in
            guard finished else { bellWobble = false; return }
            // Continuous bell wobble while finished
            withAnimation(
                .easeInOut(duration: 0.35)
                .repeatForever(autoreverses: true)
            ) { bellWobble = true }
        }
    }

    // MARK: - Left Ear Content
    @ViewBuilder
    private var leftEarContent: some View {
        switch settings.closedNotchStyle {
        case .defaultStyle:
            ClassicCompactLeftEarView(bellWobble: bellWobble)
        }
    }

    // MARK: - Right Ear Content
    @ViewBuilder
    private var rightEarContent: some View {
        switch settings.closedNotchStyle {
        case .defaultStyle:
            ClassicCompactRightEarView(bellWobble: bellWobble)
        }
    }
}
