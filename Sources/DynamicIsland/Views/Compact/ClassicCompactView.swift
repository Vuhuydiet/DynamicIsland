import SwiftUI

public struct ClassicCompactLeftEarView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var notifManager = PluginNotificationManager.shared
    @ObservedObject var settings = SettingsManager.shared
    public var bellWobble: Bool

    public var body: some View {
        HStack(spacing: 6) {
            if let notif = notifManager.activeNotification {
                HStack(spacing: 4) {
                    notif.tab.iconView(size: 12)
                    // The closed notch is a fixed-width window, so the sender name
                    // scales down and truncates to fit rather than being clipped
                    // mid-glyph by the ear's frame.
                    Text(notif.title)
                        .font(IslandFont.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.timer) && timerManager.isTimerFinished {
                HStack(spacing: 3) {
                    Image(systemName: "bell.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.orange)
                        .rotationEffect(.degrees(bellWobble ? 18 : -18))
                    Text("00:00")
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.timer) && timerManager.isTimerRunning {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.orange)
                    Text(timerManager.formattedRemainingTime)
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.timer) && (timerManager.isStopwatchRunning || timerManager.stopwatchElapsed > 0) {
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(timerManager.isStopwatchRunning ? .green : .yellow)
                    Text(timerManager.formattedCompactStopwatchTime)
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(timerManager.isStopwatchRunning ? .green : .yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.media) && mediaManager.currentTrack.isPlaying {
                Image(systemName: mediaManager.currentTrack.source.iconName)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(mediaManager.currentTrack.source.accentColor)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.media) && !mediaManager.currentTrack.isEmpty {
                Image(systemName: mediaManager.currentTrack.source.iconName)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(mediaManager.currentTrack.source.accentColor.opacity(0.85))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if !dropShelfManager.items.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.blue)
                    Text("\(dropShelfManager.items.count)")
                        .font(IslandFont.metricNumeric)
                        .foregroundColor(.blue)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if let pluginAccessory = MessengerPlugin.shared.makeCompactAccessory() {
                pluginAccessory
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else {
                Image(systemName: "apple.logo")
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.white.opacity(0.70))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            }
        }
        .animation(IslandSpring.bouncy, value: timerManager.isTimerFinished)
        .animation(IslandSpring.bouncy, value: timerManager.isTimerRunning)
        .animation(IslandSpring.bouncy, value: timerManager.isStopwatchRunning)
        .animation(IslandSpring.bouncy, value: timerManager.stopwatchElapsed > 0)
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
        .animation(IslandSpring.bouncy, value: notifManager.activeNotification?.id)
        .animation(IslandSpring.bouncy, value: MessengerPlugin.shared.webController.pageTitleUnreadCount)
    }
}

public struct ClassicCompactRightEarView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var notifManager = PluginNotificationManager.shared
    @ObservedObject var settings = SettingsManager.shared
    public var bellWobble: Bool

    /// Resolves the right-ear state, then hands it to `RightEarPolicy.token(for:)` so
    /// the "graphical only, battery excepted" contract is enforced at this single point.
    /// Every branch below returns a `RightEarToken`; none of them can carry text
    /// because no token case accepts an arbitrary string.
    private var token: RightEarToken {
        let resolved: RightEarToken?

        if notifManager.activeNotification != nil {
            // Notification alerts show the sender's icon only. The message body is
            // intentionally dropped here: text is not permitted in the right ear.
            let notif = notifManager.activeNotification
            let symbol = notif.flatMap { notification in
                let pluginSymbol: String?
                switch notification.tab {
                case .messenger: pluginSymbol = MessengerPlugin.shared.icon
                case .plugin(let id): pluginSymbol = PluginManager.shared.plugin(for: id)?.icon
                default: pluginSymbol = nil
                }
                return pluginSymbol ?? "bell.fill"
            } ?? "bell.fill"
            resolved = .notificationIcon(systemName: symbol)

        } else if settings.isTabVisible(.timer) && timerManager.isTimerFinished {
            resolved = .timerDonePulse

        } else if settings.isTabVisible(.timer) && timerManager.isTimerRunning {
            resolved = .timerProgressRing

        } else if settings.isTabVisible(.timer) && (timerManager.isStopwatchRunning || timerManager.stopwatchElapsed > 0) {
            resolved = timerManager.laps.isEmpty ? .stopwatchStateDot : .stopwatchLapFlag

        } else if settings.isTabVisible(.media) && mediaManager.currentTrack.isPlaying {
            resolved = .mediaVisualizer

        } else if settings.isTabVisible(.media) && !mediaManager.currentTrack.isEmpty {
            resolved = .mediaPauseGlyph

        } else if !dropShelfManager.items.isEmpty {
            resolved = .dropShelfGlyph

        } else if let pluginToken = activePluginStatusToken() {
            resolved = pluginToken

        } else {
            resolved = .battery
        }

        return RightEarPolicy.token(for: resolved)
    }

    /// Asks each enabled plugin for a text-free right-ear token. Plugins can only
    /// contribute `RightEarToken` values, so a plugin cannot inject text here.
    private func activePluginStatusToken() -> RightEarToken? {
        for plugin in PluginManager.shared.activePlugins {
            if let token = plugin.compactStatusToken() {
                return token
            }
        }
        return nil
    }

    public var body: some View {
        Group {
            switch token {
            case .battery:
                // The single allowlisted text-bearing item: the battery percentage.
                HStack(spacing: 3) {
                    Text("\(systemMonitor.stats.batteryPercent)%")
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)

                    Image(systemName: systemMonitor.stats.isCharging ? "bolt.fill" : "battery.75")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(systemMonitor.stats.isCharging ? .green : .white.opacity(0.80))
                }

            case .mediaVisualizer:
                EqualizerVisualizerView(
                    tint: mediaManager.currentTrack.source.accentColor,
                    maxHeight: 11
                )

            case .mediaPauseGlyph:
                Image(systemName: "pause.fill")
                    .font(IslandFont.iconMicro)
                    .foregroundColor(.white.opacity(0.65))

            case .timerProgressRing:
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(timerManager.progress))
                        .stroke(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: timerManager.progress)
                }
                .frame(width: 12, height: 12)

            case .timerDonePulse:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .scaleEffect(bellWobble ? 1.4 : 0.8)
                    .opacity(bellWobble ? 1.0 : 0.7)

            case .stopwatchLapFlag:
                // Glyph only — the lap *count* is text and therefore not rendered here.
                Image(systemName: "flag.fill")
                    .font(IslandFont.iconMicro)
                    .foregroundColor(.green.opacity(0.85))

            case .stopwatchStateDot:
                Circle()
                    .fill(timerManager.isStopwatchRunning ? Color.green : Color.yellow)
                    .frame(width: 5, height: 5)
                    .opacity(timerManager.isStopwatchRunning ? 1.0 : 0.6)

            case .dropShelfGlyph:
                Image(systemName: "folder.fill")
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.blue.opacity(0.85))

            case .pluginIcon(let systemName), .notificationIcon(let systemName):
                Image(systemName: systemName)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .animation(IslandSpring.bouncy, value: timerManager.isTimerFinished)
        .animation(IslandSpring.bouncy, value: timerManager.isTimerRunning)
        .animation(IslandSpring.bouncy, value: timerManager.isStopwatchRunning)
        .animation(IslandSpring.bouncy, value: timerManager.stopwatchElapsed > 0)
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
        .animation(IslandSpring.bouncy, value: notifManager.activeNotification?.id)
        .animation(IslandSpring.bouncy, value: timerManager.laps.count)
    }
}
