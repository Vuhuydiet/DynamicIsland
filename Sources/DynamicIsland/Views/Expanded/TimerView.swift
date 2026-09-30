import SwiftUI

// MARK: - TimerView
public struct TimerView: View {
    @ObservedObject var timer = TimerManager.shared

    public var body: some View {
        VStack(spacing: 8) {
            // Mode Picker
            HStack(spacing: 6) {
                Spacer()
                ForEach(TimerMode.allCases) { m in
                    Button { timer.mode = m } label: {
                        Text(m.rawValue)
                            .font(IslandFont.subtitle)
                            .foregroundColor(timer.mode == m ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(timer.mode == m ? Color.orange.opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)

            if timer.mode == .timer {
                CountdownView()
            } else {
                StopwatchView()
            }
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Countdown Timer
private struct CountdownView: View {
    @ObservedObject var timer = TimerManager.shared
    @State private var inputHours   = 0
    @State private var inputMinutes = 5
    @State private var inputSeconds = 0
    @State private var isEditing    = false

    private var isIdle: Bool { !timer.isTimerRunning && !timer.isTimerPaused }

    public var body: some View {
        HStack(spacing: 24) {
            Spacer(minLength: 0)

            // ── Circular progress dial ────────────────────────────────
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(timer.progress))
                    .stroke(
                        LinearGradient(colors: [.orange, .yellow],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timer.progress)

                VStack(spacing: 1) {
                    Text(timer.formattedRemainingTime)
                        .font(IslandFont.heroNumeric)
                        .foregroundColor(.white)
                    Text(timer.isTimerRunning ? "RUNNING" : (timer.isTimerPaused ? "PAUSED" : "READY"))
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 84, height: 84)

            // ── Right panel ───────────────────────────────────────────
            VStack(alignment: .leading, spacing: 7) {

                // Custom time input (shown when idle or editing)
                if isIdle || isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SET TIME")
                            .font(IslandFont.micro)
                            .foregroundColor(.white.opacity(0.35))

                        HStack(spacing: 4) {
                            TimeUnitStepper(label: "h", value: $inputHours,   range: 0...23)
                            Text(":").foregroundColor(.white.opacity(0.3)).font(IslandFont.subtitle)
                            TimeUnitStepper(label: "m", value: $inputMinutes, range: 0...59)
                            Text(":").foregroundColor(.white.opacity(0.3)).font(IslandFont.subtitle)
                            TimeUnitStepper(label: "s", value: $inputSeconds, range: 0...59)
                        }
                    }
                } else {
                    // Quick presets while running/paused
                    HStack(spacing: 5) {
                        PresetButton(label: "1m",    seconds: 60)
                        PresetButton(label: "5m",    seconds: 300)
                        PresetButton(label: "15m",   seconds: 900)
                        PresetButton(label: "🍅25m", seconds: 1500)
                    }
                }

                // Control buttons
                HStack(spacing: 6) {
                    if isIdle {
                        Button {
                            let total = inputHours * 3600 + inputMinutes * 60 + inputSeconds
                            guard total > 0 else { return }
                            isEditing = false
                            timer.startTimer(seconds: total)
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if timer.isTimerRunning {
                        Button { timer.pauseTimer() } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.yellow)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Paused state
                        Button { timer.startTimer() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !isIdle {
                        Button {
                            timer.resetTimer()
                            isEditing = false
                        } label: {
                            Text("Reset")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
    }
}

// MARK: - Time Unit Stepper (up/down arrows + value)
private struct TimeUnitStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 1) {
            // Up arrow
            Button { value = min(range.upperBound, value + 1) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 10)
            }
            .buttonStyle(.plain)

            // Value + label
            VStack(spacing: 0) {
                Text(String(format: "%02d", value))
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(width: 28)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            // Down arrow
            Button { value = max(range.lowerBound, value - 1) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 10)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Stopwatch
private struct StopwatchView: View {
    @ObservedObject var timer = TimerManager.shared

    var body: some View {
        HStack(spacing: 20) {
            Spacer(minLength: 0)

            // ── Left: time + controls centered together ───────────────
            VStack(alignment: .center, spacing: 8) {
                Text(timer.formattedStopwatchTime)
                    .font(IslandFont.heroNumeric)
                    .foregroundColor(.white)
                    .monospacedDigit()

                HStack(spacing: 6) {
                    // Start / Pause
                    Button {
                        timer.isStopwatchRunning ? timer.pauseStopwatch() : timer.startStopwatch()
                    } label: {
                        Label(
                            timer.isStopwatchRunning ? "Pause" : "Start",
                            systemImage: timer.isStopwatchRunning ? "pause.fill" : "play.fill"
                        )
                        .font(IslandFont.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(timer.isStopwatchRunning ? Color.yellow : Color.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Lap (only while running)
                    if timer.isStopwatchRunning {
                        Button { timer.addLap() } label: {
                            Text("Lap")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.13))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Reset
                    Button { timer.resetStopwatch() } label: {
                        Text("Reset")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Right: laps list ──────────────────────────────────────
            if !timer.laps.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.12))
                    .frame(height: 60)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 3) {
                        ForEach(Array(timer.laps.enumerated()), id: \.offset) { idx, lap in
                            HStack(spacing: 6) {
                                Text("Lap \(timer.laps.count - idx)")
                                    .foregroundColor(.white.opacity(0.38))
                                Text(formatLap(lap))
                                    .foregroundColor(.white.opacity(0.85))
                                    .monospacedDigit()
                            }
                            .font(IslandFont.timeNumeric)
                        }
                    }
                }
                .frame(width: 110, height: 68)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
    }

    private func formatLap(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t.truncatingRemainder(dividingBy: 1.0)) * 100)
        return m > 0
            ? String(format: "%d:%02d.%02d", m, s, ms)
            : String(format: "%02d.%02d", s, ms)
    }
}

// MARK: - Preset Button
public struct PresetButton: View {
    public let label: String
    public let seconds: Int
    @ObservedObject var timer = TimerManager.shared

    public var body: some View {
        Button { timer.startTimer(seconds: seconds) } label: {
            Text(label)
                .font(IslandFont.caption)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
