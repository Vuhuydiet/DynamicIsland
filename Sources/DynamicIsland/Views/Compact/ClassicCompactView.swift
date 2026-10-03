import SwiftUI

public struct ClassicCompactLeftEarView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var settings = SettingsManager.shared
    public var bellWobble: Bool

    public var body: some View {
        HStack(spacing: 6) {
            if settings.isTabVisible(.timer) && timerManager.isTimerFinished {
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
            } else if settings.isTabVisible(.media) && mediaManager.currentTrack.source != .none && mediaManager.currentTrack.title != "No Media Playing" {
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
    }
}

public struct ClassicCompactRightEarView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var settings = SettingsManager.shared
    public var bellWobble: Bool

    public var body: some View {
        HStack(spacing: 6) {
            if settings.isTabVisible(.timer) && timerManager.isTimerFinished {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                        .scaleEffect(bellWobble ? 1.4 : 0.8)
                    Text("Done!")
                        .font(IslandFont.caption)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.timer) && timerManager.isTimerRunning {
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.25), value: timerManager.progress)
                    }
                    .frame(width: 12, height: 12)
                    Text("Timer")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.70))
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.timer) && (timerManager.isStopwatchRunning || timerManager.stopwatchElapsed > 0) {
                if !timerManager.laps.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                            .font(IslandFont.iconMicro)
                            .foregroundColor(.green.opacity(0.85))
                        Text("L\(timerManager.laps.count)")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .monospacedDigit()
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(timerManager.isStopwatchRunning ? Color.green : Color.yellow)
                            .frame(width: 5, height: 5)
                        Text(timerManager.isStopwatchRunning ? "Stopwatch" : "Paused")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.70))
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
                }
            } else if settings.isTabVisible(.media) && mediaManager.currentTrack.isPlaying {
                EqualizerVisualizerView(tint: mediaManager.currentTrack.source.accentColor, maxHeight: 11)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if settings.isTabVisible(.media) && mediaManager.currentTrack.source != .none && mediaManager.currentTrack.title != "No Media Playing" {
                Image(systemName: "pause.fill")
                    .font(IslandFont.iconMicro)
                    .foregroundColor(.white.opacity(0.65))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if !dropShelfManager.items.isEmpty {
                Image(systemName: "folder.fill")
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.blue.opacity(0.85))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else {
                HStack(spacing: 3) {
                    Text("\(systemMonitor.stats.batteryPercent)%")
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)

                    Image(systemName: systemMonitor.stats.isCharging ? "bolt.fill" : "battery.75")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(systemMonitor.stats.isCharging ? .green : .white.opacity(0.80))
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            }
        }
        .animation(IslandSpring.bouncy, value: timerManager.isTimerFinished)
        .animation(IslandSpring.bouncy, value: timerManager.isTimerRunning)
        .animation(IslandSpring.bouncy, value: timerManager.isStopwatchRunning)
        .animation(IslandSpring.bouncy, value: timerManager.stopwatchElapsed > 0)
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
    }
}
