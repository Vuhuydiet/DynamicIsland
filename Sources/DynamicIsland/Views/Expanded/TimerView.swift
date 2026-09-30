import SwiftUI

public struct TimerView: View {
    @ObservedObject var timer = TimerManager.shared
    
    public var body: some View {
        VStack(spacing: 12) {
            // Mode Picker
            HStack(spacing: 6) {
                ForEach(TimerMode.allCases) { m in
                    Button(action: {
                        timer.mode = m
                    }) {
                        Text(m.rawValue)
                            .font(IslandFont.subtitle)
                            .foregroundColor(timer.mode == m ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(timer.mode == m ? Color.orange.opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            if timer.mode == .timer {
                // MARK: - Countdown Timer UI
                HStack(spacing: 20) {
                    // Big Circular Dial
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timer.progress))
                            .stroke(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: timer.progress)
                        
                        VStack(spacing: 2) {
                            Text(timer.formattedRemainingTime)
                                .font(IslandFont.heroNumeric)
                                .foregroundColor(.white)
                            
                            Text(timer.isTimerRunning ? "RUNNING" : (timer.isTimerPaused ? "PAUSED" : "READY"))
                                .font(IslandFont.micro)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .frame(width: 86, height: 86)
                    
                    // Controls & Presets
                    VStack(alignment: .leading, spacing: 8) {
                        // Presets
                        HStack(spacing: 6) {
                            PresetButton(label: "1m", seconds: 60)
                            PresetButton(label: "5m", seconds: 300)
                            PresetButton(label: "15m", seconds: 900)
                            PresetButton(label: "25m 🍅", seconds: 1500)
                        }
                        
                        // Control buttons
                        HStack(spacing: 8) {
                            if !timer.isTimerRunning {
                                Button(action: {
                                    timer.startTimer()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                        Text(timer.isTimerPaused ? "Resume" : "Start")
                                    }
                                    .font(IslandFont.caption)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    timer.pauseTimer()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pause.fill")
                                        Text("Pause")
                                    }
                                    .font(IslandFont.caption)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: {
                                timer.resetTimer()
                            }) {
                                Text("Reset")
                                    .font(IslandFont.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
            } else {
                // MARK: - Stopwatch UI
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(timer.formattedStopwatchTime)
                            .font(IslandFont.heroNumeric)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                if timer.isStopwatchRunning {
                                    timer.pauseStopwatch()
                                } else {
                                    timer.startStopwatch()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: timer.isStopwatchRunning ? "pause.fill" : "play.fill")
                                    Text(timer.isStopwatchRunning ? "Pause" : "Start")
                                }
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(timer.isStopwatchRunning ? Color.yellow : Color.green)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            if timer.isStopwatchRunning {
                                Button(action: {
                                    timer.addLap()
                                }) {
                                    Text("Lap")
                                        .font(IslandFont.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: {
                                timer.resetStopwatch()
                            }) {
                                Text("Reset")
                                    .font(IslandFont.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    // Laps preview
                    if !timer.laps.isEmpty {
                        ScrollView {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(Array(timer.laps.enumerated()), id: \.offset) { idx, lap in
                                    HStack {
                                        Text("Lap \(timer.laps.count - idx)")
                                            .foregroundColor(.white.opacity(0.4))
                                        Text(String(format: "%.1fs", lap))
                                            .foregroundColor(.white)
                                    }
                                    .font(IslandFont.timeNumeric)
                                }
                            }
                        }
                        .frame(width: 100, height: 70)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 8)
    }
}

public struct PresetButton: View {
    public let label: String
    public let seconds: Int
    @ObservedObject var timer = TimerManager.shared
    
    public var body: some View {
        Button(action: {
            timer.startTimer(seconds: seconds)
        }) {
            Text(label)
                .font(IslandFont.caption)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
