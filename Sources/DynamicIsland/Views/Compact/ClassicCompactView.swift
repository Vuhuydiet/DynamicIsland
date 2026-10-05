import SwiftUI

/// The closed-notch left ear: a resident slot plus a scrolling alert strip.
///
/// The ear is a fixed 56pt surface (docs/DESIGN.md §1), so this never grows. Resident
/// items hold a stable position on the left and are never carried by the marquee —
/// a running countdown that drifted off the edge would expire unseen. Transients
/// enter at the left of the remaining space, travel right, and retire once clear.
public struct ClassicCompactLeftEarView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var notifManager = PluginNotificationManager.shared
    @ObservedObject var settings = SettingsManager.shared
    public var bellWobble: Bool

    /// Drives the marquee. Refreshed on a 30Hz timer so every item's position is
    /// recomputed from elapsed time rather than accumulated — a dropped frame or a
    /// backgrounded app cannot make the strip drift or wedge.
    @State private var now: TimeInterval = Date().timeIntervalSince1970

    /// Alert items currently worth drawing, oldest first.
    ///
    /// Taken from the notification list rather than from each plugin's
    /// `compactItems()`, because the manager is what knows an alert's arrival time —
    /// and arrival time is what the marquee is a function of.
    private var transients: [IslandNotification] {
        notifManager.activeNotifications
    }

    /// The single item that holds the fixed slot, in priority order.
    ///
    /// Only one item ever occupies the slot, and it never moves: a running countdown
    /// that scrolled away would expire unseen. The ear is 56pt total, so when the
    /// alert strip is present a countdown drops its digits and keeps its glyph —
    /// content degrades rather than the ear growing (docs/DESIGN.md §1).
    private var resident: AnyView? {
        if transients.isEmpty,
           settings.isTabVisible(.timer), timerManager.isTimerFinished {
            return AnyView(
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
            )
        }

        if settings.isTabVisible(.timer), timerManager.isTimerRunning {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.orange)
                    // Dropped to a glyph while the strip is scrolling: a number in a
                    // moving row is misread at a glance, and the glyph is the
                    // sanctioned way to say "still counting" in a space this narrow.
                    if showResidentText {
                        Text(timerManager.formattedRemainingTime)
                            .font(IslandFont.timeNumeric)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            )
        }

        if settings.isTabVisible(.timer),
           timerManager.isStopwatchRunning || timerManager.stopwatchElapsed > 0 {
            let tint = timerManager.isStopwatchRunning ? Color.green : Color.yellow
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(tint)
                    if showResidentText {
                        Text(timerManager.formattedCompactStopwatchTime)
                            .font(IslandFont.timeNumeric)
                            .foregroundColor(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            )
        }

        if settings.isTabVisible(.media), mediaManager.currentTrack.isPlaying {
            return AnyView(
                Image(systemName: mediaManager.currentTrack.source.iconName)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(mediaManager.currentTrack.source.accentColor)
            )
        }

        if settings.isTabVisible(.media), !mediaManager.currentTrack.isEmpty {
            return AnyView(
                Image(systemName: mediaManager.currentTrack.source.iconName)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(mediaManager.currentTrack.source.accentColor.opacity(0.85))
            )
        }

        if !dropShelfManager.items.isEmpty {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.blue)
                    Text("\(dropShelfManager.items.count)")
                        .font(IslandFont.metricNumeric)
                        .foregroundColor(.blue)
                }
            )
        }

        return nil
    }

    /// Whether the resident item may spend points on digits.
    ///
    /// False whenever the strip is scrolling. The decision is a pure function of the
    /// two conditions so it is stated once and tested, rather than re-derived in the
    /// view body.
    private var showResidentText: Bool {
        !CompactEarMarquee.prefersCompactResident(hasTransients: !transients.isEmpty, overflows: !transients.isEmpty)
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let resident {
                resident
                    .fixedSize()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else {
                Image(systemName: "apple.logo")
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.white.opacity(0.70))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            }

            if !transients.isEmpty {
                AlertMarqueeView(
                    notifications: transients,
                    now: now,
                    bellWobble: bellWobble
                )
            }
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { date in
            now = date.timeIntervalSince1970
        }
        .animation(IslandSpring.bouncy, value: timerManager.isTimerFinished)
        .animation(IslandSpring.bouncy, value: timerManager.isTimerRunning)
        .animation(IslandSpring.bouncy, value: timerManager.isStopwatchRunning)
        .animation(IslandSpring.bouncy, value: timerManager.stopwatchElapsed > 0)
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
        .animation(IslandSpring.bouncy, value: notifManager.activeNotifications.map(\.id))
    }
}

/// The scrolling strip of live alerts.
///
/// Every position comes from `CompactEarMarquee.positions`, which is a pure function
/// of the arrival times and the current time. This view owns only measurement and
/// presentation — the geometry rule and its tests are the same code.
struct AlertMarqueeView: View {
    let notifications: [IslandNotification]
    let now: TimeInterval
    let bellWobble: Bool

    private var positions: [CGFloat] {
        CompactEarMarquee.positions(
            enteredAt: notifications.map(\.timestamp.timeIntervalSince1970),
            now: now
        )
    }

    /// The strip fills whatever the resident item left behind.
    ///
    /// The ear is a fixed 56pt and the strip's items are already wider than that, so
    /// the strip is simply allowed to fill the remaining width and clip at its right
    /// edge. It never asks the ear to be wider than the hardware allows.
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                    if index < positions.count {
                        item(for: notification)
                            .fixedSize()
                            .offset(x: positions[index])
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .frame(height: 14)
    }

    private func item(for notification: IslandNotification) -> some View {
        HStack(spacing: 4) {
            icon(for: notification)
                .frame(width: 12, height: 12)
            // The closed notch is a fixed-width window, so the sender name scales
            // down and truncates to fit rather than being clipped mid-glyph.
            Text(notification.title)
                .font(IslandFont.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func icon(for notification: IslandNotification) -> some View {
        let pluginId = notification.pluginId
        if let image = PluginIconManager.shared.icon(for: pluginId) {
            return AnyView(
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            )
        }
        let symbol = PluginManager.shared.plugin(for: pluginId)?.icon ?? "bell.fill"
        return AnyView(
            Image(systemName: symbol)
                .font(IslandFont.iconMicro)
                .foregroundColor(.white.opacity(0.85))
        )
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

        if let notif = notifManager.activeNotification {
            // Notification alerts show the sender's icon only. The message body is
            // intentionally dropped here: text is not permitted in the right ear.
            let symbol = PluginManager.shared.plugin(for: notif.pluginId)?.icon ?? "bell.fill"
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
        .animation(IslandSpring.bouncy, value: notifManager.activeNotifications.map(\.id))
        .animation(IslandSpring.bouncy, value: timerManager.laps.count)
    }
}
