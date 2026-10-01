import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared

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
            appState.toggleExpand()
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
        HStack(spacing: 6) {
            if timerManager.isTimerFinished {
                // Timer done — animated bell
                Image(systemName: "bell.fill")
                    .font(IslandFont.iconMicro)
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(bellWobble ? 18 : -18))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if timerManager.isTimerRunning {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.orange)
                    Text(timerManager.formattedRemainingTime)
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if mediaManager.currentTrack.isPlaying {
                HStack(spacing: 5) {
                    Image(systemName: mediaManager.currentTrack.source.iconName)
                        .font(IslandFont.iconMicro)
                        .foregroundColor(mediaManager.currentTrack.source.accentColor)
                    Text(mediaManager.currentTrack.title)
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if mediaManager.currentTrack.source != .none && mediaManager.currentTrack.title != "No Media Playing" {
                HStack(spacing: 5) {
                    Image(systemName: mediaManager.currentTrack.source.iconName)
                        .font(IslandFont.iconMicro)
                        .foregroundColor(mediaManager.currentTrack.source.accentColor.opacity(0.85))
                    Text(mediaManager.currentTrack.title)
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
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
                // Idle Brand Logo: compact Apple logo
                Image(systemName: "apple.logo")
                    .font(IslandFont.iconSmall)
                    .foregroundColor(.white.opacity(0.70))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            }
        }
        .animation(IslandSpring.bouncy, value: timerManager.isTimerFinished)
        .animation(IslandSpring.bouncy, value: timerManager.isTimerRunning)
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
    }

    // MARK: - Right Ear Content
    @ViewBuilder
    private var rightEarContent: some View {
        HStack(spacing: 6) {
            if timerManager.isTimerFinished {
                // "Done!" label with pulsing dot
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
            } else if timerManager.isTimerRunning {
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
            } else if mediaManager.currentTrack.isPlaying {
                HStack(spacing: 5) {
                    let artistText: String = {
                        if !mediaManager.currentTrack.artist.isEmpty &&
                            mediaManager.currentTrack.artist != "Unknown Artist" &&
                            mediaManager.currentTrack.artist != mediaManager.currentTrack.title {
                            return mediaManager.currentTrack.artist
                        }
                        if mediaManager.currentTrack.source != .none && mediaManager.currentTrack.source != .mediaRemote {
                            return mediaManager.currentTrack.source.rawValue
                        }
                        return ""
                    }()

                    if !artistText.isEmpty {
                        Text(artistText)
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 80, alignment: .trailing)
                    }
                    EqualizerVisualizerView(tint: mediaManager.currentTrack.source.accentColor, maxHeight: 11)
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if mediaManager.currentTrack.source != .none && mediaManager.currentTrack.title != "No Media Playing" {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Paused")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else if !dropShelfManager.items.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.blue.opacity(0.8))
                    Text("Shelf")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)), removal: .opacity))
            } else {
                // Idle: Battery indicator
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
        .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
        .animation(IslandSpring.bouncy, value: dropShelfManager.items.isEmpty)
    }
}
