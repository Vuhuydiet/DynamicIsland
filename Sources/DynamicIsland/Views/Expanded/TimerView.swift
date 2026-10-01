import SwiftUI
import AppKit

// MARK: - TimerView
public struct TimerView: View {
    @ObservedObject var timer = TimerManager.shared
    @Namespace private var modeNamespace

    public var body: some View {
        VStack(spacing: 8) {
            // Mode Picker with sliding highlight
            HStack(spacing: 6) {
                Spacer()
                ForEach(TimerMode.allCases) { m in
                    let isSelected = timer.mode == m
                    Button {
                        SoundManager.shared.play(.click)
                        withAnimation(IslandSpring.tabSlide) {
                            timer.mode = m
                        }
                    } label: {
                        Text(m.rawValue)
                            .font(IslandFont.subtitle)
                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background {
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(Color.orange.opacity(0.3))
                                            .overlay(Capsule().stroke(Color.orange.opacity(0.5), lineWidth: 0.5))
                                            .matchedGeometryEffect(id: "timerModePill", in: modeNamespace)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                    }
                                }
                            }
                    }
                    .buttonStyle(PillButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)

            Group {
                if timer.mode == .timer {
                    CountdownView()
                } else {
                    StopwatchView()
                }
            }
            .id(timer.mode)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
        }
        .animation(IslandSpring.tabSlide, value: timer.mode)
        .padding(.bottom, 6)
    }
}

// MARK: - Countdown Timer
private struct CountdownView: View {
    @ObservedObject var timer = TimerManager.shared
    @State private var inputHours   = 0
    @State private var inputMinutes = 5
    @State private var inputSeconds = 0
    @State private var pulseFinish  = false

    private var isIdle: Bool { !timer.isTimerRunning && !timer.isTimerPaused && !timer.isTimerFinished }

    public var body: some View {
        Group {
            if timer.isTimerFinished {
                finishedView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            } else {
                mainContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            }
        }
        .animation(IslandSpring.bouncy, value: timer.isTimerFinished)
        .onChange(of: timer.isTimerFinished) { _, finished in
            if finished {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseFinish = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseFinish = false
                }
            }
        }
    }

    // MARK: - Finished view (full replacement)
    private var finishedView: some View {
        HStack(spacing: 24) {
            Spacer(minLength: 0)

            // Pulsing bell
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(pulseFinish ? 0.22 : 0.12))
                    .scaleEffect(pulseFinish ? 1.08 : 1.0)
                Circle()
                    .stroke(Color.orange.opacity(pulseFinish ? 0.7 : 0.35), lineWidth: 1.5)
                Image(systemName: "bell.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.orange)
                    .scaleEffect(pulseFinish ? 1.05 : 1.0)
                    .rotationEffect(.degrees(pulseFinish ? 12 : -12))
            }
            .frame(width: 84, height: 84)

            // Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Timer Complete!")
                    .font(IslandFont.subtitle)
                    .foregroundColor(.white)

                Text("Your \(formatDuration(timer.totalSeconds)) timer ended.")
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 6) {
                    Button {
                        timer.startTimer(seconds: timer.totalSeconds)
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                            .font(IslandFont.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                    Button {
                        timer.resetTimer()
                    } label: {
                        Text("Dismiss")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    // MARK: - Normal content
    private var mainContent: some View {
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
                if isIdle {
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
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
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
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    } else {
                        // Paused state
                        Button { timer.resumeTimer() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    }

                    if !isIdle {
                        Button {
                            timer.resetTimer()
                        } label: {
                            Text("Reset")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
    }
}

// MARK: - Time Unit Stepper (up/down arrows + scroll wheel)
private struct TimeUnitStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 1) {
            // Up arrow
            Button { increment() } label: {
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
            Button { decrement() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 10)
            }
            .buttonStyle(.plain)
        }
        // Attach scroll monitor to the whole stepper area
        .overlay(
            ScrollWheelCapture { delta in
                if delta < 0 { increment() } else { decrement() }
            }
            .allowsHitTesting(false) // let clicks fall through to buttons
        )
    }

    private func increment() {
        value = value < range.upperBound ? value + 1 : range.lowerBound
    }
    private func decrement() {
        value = value > range.lowerBound ? value - 1 : range.upperBound
    }
}

// MARK: - Scroll Wheel Capture (NSViewRepresentable)
/// Transparent overlay that installs an NSEvent local monitor while the mouse
/// hovers over it. Local monitors fire on scroll regardless of hit-test order.
private struct ScrollWheelCapture: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> _ScrollWheelView {
        let v = _ScrollWheelView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: _ScrollWheelView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class _ScrollWheelView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var monitor: Any?

    // Tracking area fires mouseEntered/Exited even for non-hit-test views
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] ev in
            guard let self else { return ev }
            // Only act when the cursor is actually inside our bounds
            if let win = self.window {
                let loc = self.convert(ev.locationInWindow, from: nil)
                if self.bounds.contains(loc) {
                    let dy = ev.scrollingDeltaY
                    if abs(dy) > 0.3 {
                        DispatchQueue.main.async { self.onScroll?(dy) }
                    }
                }
            }
            return ev // don't consume — let the panel scroll if needed
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil, let m = monitor {
            NSEvent.removeMonitor(m); monitor = nil
        }
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
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
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                    // Lap (only while running)
                    if timer.isStopwatchRunning {
                        Button {
                            withAnimation(IslandSpring.bouncy) {
                                timer.addLap()
                            }
                        } label: {
                            Text("Lap")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.13))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    }

                    // Reset
                    Button {
                        withAnimation(IslandSpring.bouncy) {
                            timer.resetStopwatch()
                        }
                    } label: {
                        Text("Reset")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
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
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .frame(width: 110, height: 68)
                .animation(IslandSpring.bouncy, value: timer.laps.count)
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
        Button {
            withAnimation(IslandSpring.bouncy) {
                timer.startTimer(seconds: seconds)
            }
        } label: {
            Text(label)
                .font(IslandFont.caption)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
    }
}
