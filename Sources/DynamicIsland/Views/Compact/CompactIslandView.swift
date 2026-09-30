import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    @ObservedObject var dropShelfManager = DropShelfManager.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared
    
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
    
    private var leftEarWidth: CGFloat {
        (mediaManager.currentTrack.isPlaying || timerManager.isTimerRunning) ? 80.0 : 50.0
    }
    
    private var rightEarWidth: CGFloat {
        mediaManager.currentTrack.isPlaying ? 44.0 : 50.0
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Ear (Outside the Notch on the Left)
            HStack(spacing: 4) {
                if timerManager.isTimerRunning {
                    Image(systemName: "timer")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.orange)
                    Text(timerManager.formattedRemainingTime)
                        .font(IslandFont.timeNumeric)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                } else if !dropShelfManager.items.isEmpty {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.blue)
                    Text("\(dropShelfManager.items.count)")
                        .font(IslandFont.metricNumeric)
                        .foregroundColor(.blue)
                } else if mediaManager.currentTrack.isPlaying {
                    Image(systemName: "music.note")
                        .font(IslandFont.iconMicro)
                        .foregroundColor(.pink)
                    Text(mediaManager.currentTrack.title)
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 62, alignment: .leading)
                } else {
                    // Idle Brand Logo
                    Image(systemName: "apple.logo")
                        .font(IslandFont.iconSmall)
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.leading, 8)
            .frame(width: isNotchMode ? leftEarWidth : nil, alignment: .leading)
            .clipped()
            
            // MARK: - Center Notch Cutout (Reserved for the physical camera notch)
            if isNotchMode {
                Color.clear
                    .frame(width: notchWidth, height: notchHeight)
            } else {
                Spacer(minLength: 16)
            }
            
            // MARK: - Right Ear (Outside the Notch on the Right)
            HStack(spacing: 4) {
                if mediaManager.currentTrack.isPlaying {
                    EqualizerVisualizerView(tint: .green, maxHeight: 10)
                } else if timerManager.isTimerRunning {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 11, height: 11)
                } else {
                    // Battery indicator
                    HStack(spacing: 3) {
                        Text("\(systemMonitor.stats.batteryPercent)%")
                            .font(IslandFont.timeNumeric)
                            .foregroundColor(.white.opacity(0.65))
                        
                        Image(systemName: systemMonitor.stats.isCharging ? "bolt.fill" : "battery.75")
                            .font(IslandFont.iconMicro)
                            .foregroundColor(systemMonitor.stats.isCharging ? .green : .white.opacity(0.65))
                    }
                }
            }
            .padding(.trailing, 8)
            .frame(width: isNotchMode ? rightEarWidth : nil, alignment: .trailing)
            .clipped()
        }
        .frame(height: notchHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.toggleExpand()
        }
    }
}
