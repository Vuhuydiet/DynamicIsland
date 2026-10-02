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

    private var hasHours: Bool {
        if isIdle {
            return inputHours > 0
        }
        return timer.remainingSeconds >= 3600
    }

    private var displayedRemainingTime: String {
        if isIdle {
            let total = inputHours * 3600 + inputMinutes * 60 + inputSeconds
            let m = (total % 3600) / 60
            let s = total % 60
            let h = total / 3600
            if h > 0 {
                return String(format: "%d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        }
        return timer.formattedRemainingTime
    }

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
                    Text(displayedRemainingTime)
                        .font(hasHours ? .system(size: 15, weight: .bold, design: .monospaced) : IslandFont.heroNumeric)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: 72)
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

// MARK: - Time Unit Stepper (up/down arrows + scroll wheel + drag)
private struct TimeUnitStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 1) {
            // Up arrow
            Button { step(by: 1) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 30, height: 10)
            }
            .buttonStyle(.plain)

            // Value + label with Scroll Wheel & Drag Capture
            VStack(spacing: 0) {
                Text(String(format: "%02d", value))
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(width: 30)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                ScrollWheelCapture { delta in
                    step(by: delta)
                }
            )

            // Down arrow
            Button { step(by: -1) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 30, height: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private func step(by delta: Int) {
        let count = range.upperBound - range.lowerBound + 1
        var offset = (value - range.lowerBound + delta) % count
        if offset < 0 {
            offset += count
        }
        value = range.lowerBound + offset
    }
}

// MARK: - Scroll Wheel & Drag Capture (NSViewRepresentable)
/// An interactive NSView that captures scroll wheel (mouse wheel & trackpad swipes)
/// and vertical mouse dragging to scroll numbers naturally.
private struct ScrollWheelCapture: NSViewRepresentable {
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> _ScrollWheelView {
        let v = _ScrollWheelView()
        v.onStep = onStep
        return v
    }

    func updateNSView(_ nsView: _ScrollWheelView, context: Context) {
        nsView.onStep = onStep
    }
}

final class _ScrollWheelView: NSView {
    var onStep: ((Int) -> Void)?
    private var accumulatedDelta: CGFloat = 0.0
    private var dragStartY: CGFloat = 0.0
    private var accumulatedDrag: CGFloat = 0.0

    override var isOpaque: Bool { false }

    override func scrollWheel(with event: NSEvent) {
        // Ignore inertia/momentum coasting so values don't spin uncontrollably when lifting fingers
        guard event.momentumPhase.isEmpty else { return }

        // Reset accumulation at gesture boundaries
        if event.phase == .began || event.phase == .ended || event.phase == .cancelled {
            accumulatedDelta = 0.0
        }

        let dy = event.scrollingDeltaY
        let inverted = event.isDirectionInvertedFromDevice
        // Natural scrolling has inverted deltas; flip so positive always means upward gesture
        let effectiveDy = inverted ? -dy : dy

        if event.hasPreciseScrollingDeltas {
            accumulatedDelta += effectiveDy
            // Calm, controllable trackpad swipe threshold (24pt swipe = 1 unit change)
            let threshold: CGFloat = 24.0
            if abs(accumulatedDelta) >= threshold {
                let steps = Int(accumulatedDelta / threshold)
                accumulatedDelta -= CGFloat(steps) * threshold
                DispatchQueue.main.async { [weak self] in
                    self?.onStep?(steps)
                }
            }
        } else {
            // Traditional stepped mouse wheel (1 notch = 1 step)
            accumulatedDelta += effectiveDy
            if abs(accumulatedDelta) >= 1.0 {
                let steps = accumulatedDelta > 0 ? 1 : -1
                accumulatedDelta = 0.0
                DispatchQueue.main.async { [weak self] in
                    self?.onStep?(steps)
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = event.locationInWindow.y
        accumulatedDrag = 0.0
    }

    override func mouseDragged(with event: NSEvent) {
        let currentY = event.locationInWindow.y
        let dy = currentY - dragStartY
        dragStartY = currentY
        accumulatedDrag += dy

        // Dragging upward in window coordinates increases value (22pt drag = 1 step)
        let threshold: CGFloat = 22.0
        if abs(accumulatedDrag) >= threshold {
            let steps = Int(accumulatedDrag / threshold)
            accumulatedDrag -= CGFloat(steps) * threshold
            DispatchQueue.main.async { [weak self] in
                self?.onStep?(steps)
            }
        }
    }
}

// MARK: - Stopwatch
private struct StopwatchView: View {
    @ObservedObject var timer = TimerManager.shared

    private var isRunning: Bool { timer.isStopwatchRunning }
    private var isIdle: Bool { !timer.isStopwatchRunning && timer.stopwatchElapsed == 0.0 }
    private var isPaused: Bool { !timer.isStopwatchRunning && timer.stopwatchElapsed > 0.0 }

    private var timeComponents: (main: String, hundredths: String) {
        let total = Int(timer.stopwatchElapsed)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        let hundredths = Int((timer.stopwatchElapsed.truncatingRemainder(dividingBy: 1.0)) * 100)
        let mainStr = hours > 0
            ? String(format: "%d:%02d:%02d", hours, mins, secs)
            : String(format: "%02d:%02d", mins, secs)
        return (mainStr, String(format: ".%02d", hundredths))
    }

    private var fastestLapIndex: Int? {
        guard timer.laps.count >= 2 else { return nil }
        var bestIdx = 0
        var bestDuration = Double.greatestFiniteMagnitude
        for idx in 0..<timer.laps.count {
            let prev = idx + 1 < timer.laps.count ? timer.laps[idx + 1] : 0.0
            let split = timer.laps[idx] - prev
            if split < bestDuration {
                bestDuration = split
                bestIdx = idx
            }
        }
        return bestIdx
    }

    private var slowestLapIndex: Int? {
        guard timer.laps.count >= 2 else { return nil }
        var worstIdx = 0
        var worstDuration = -1.0
        for idx in 0..<timer.laps.count {
            let prev = idx + 1 < timer.laps.count ? timer.laps[idx + 1] : 0.0
            let split = timer.laps[idx] - prev
            if split > worstDuration {
                worstDuration = split
                worstIdx = idx
            }
        }
        return worstIdx != fastestLapIndex ? worstIdx : nil
    }

    private var fastestLapDuration: Double {
        guard let idx = fastestLapIndex else { return 0.0 }
        let prev = idx + 1 < timer.laps.count ? timer.laps[idx + 1] : 0.0
        return timer.laps[idx] - prev
    }

    private var currentLapSplit: Double {
        let prev = timer.laps.first ?? 0.0
        return max(0.0, timer.stopwatchElapsed - prev)
    }

    var body: some View {
        Group {
            if timer.laps.isEmpty {
                spaciousSingleColumnView
            } else {
                fullTwoColumnView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(IslandSpring.tabSlide, value: timer.laps.isEmpty)
    }

    // MARK: - State 1: Spacious Hero View (No Laps)
    private var spaciousSingleColumnView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            // Status chip
            HStack(spacing: 5) {
                Circle()
                    .fill(isRunning ? Color.green : (isPaused ? Color.yellow : Color.white.opacity(0.3)))
                    .frame(width: 6, height: 6)
                Text(isRunning ? "RUNNING" : (isPaused ? "PAUSED" : "STOPWATCH"))
                    .font(IslandFont.micro)
                    .foregroundColor(isRunning ? .green : (isPaused ? .yellow : .white.opacity(0.45)))
                    .tracking(1.0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())

            // Hero Digital Readout
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(timeComponents.main)
                    .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                Text(timeComponents.hundredths)
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white.opacity(0.60))
            }

            // Buttons
            HStack(spacing: 12) {
                if isRunning {
                    // Lap Button
                    Button {
                        withAnimation(IslandSpring.bouncy) {
                            timer.addLap()
                        }
                    } label: {
                        Label("Lap", systemImage: "flag.fill")
                            .font(IslandFont.caption)
                            .foregroundColor(.white)
                            .frame(width: 95, height: 28)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                    // Pause Button
                    Button {
                        timer.pauseStopwatch()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .font(IslandFont.caption)
                            .foregroundColor(.black)
                            .frame(width: 95, height: 28)
                            .background(Color.yellow)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                } else if isPaused {
                    // Reset Button
                    Button {
                        withAnimation(IslandSpring.bouncy) {
                            timer.resetStopwatch()
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 95, height: 28)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                    // Resume Button
                    Button {
                        timer.startStopwatch()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(IslandFont.caption)
                            .foregroundColor(.black)
                            .frame(width: 95, height: 28)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                } else {
                    // Start Button
                    Button {
                        timer.startStopwatch()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(IslandFont.caption)
                            .foregroundColor(.black)
                            .frame(width: 130, height: 30)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14)
    }

    // MARK: - State 2: Full Two-Column View (With Laps)
    private var fullTwoColumnView: some View {
        HStack(spacing: 16) {
            // ── Left Column: Time & Controls ──────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)

                // Status chip
                HStack(spacing: 4) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.yellow)
                        .frame(width: 5, height: 5)
                    Text(isRunning ? "RUNNING" : "PAUSED")
                        .font(IslandFont.micro)
                        .foregroundColor(isRunning ? .green : .yellow)
                        .tracking(0.8)
                }

                // Current Total Time
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(timeComponents.main)
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                    Text(timeComponents.hundredths)
                        .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white.opacity(0.60))
                }

                // In-progress Lap Split
                HStack(spacing: 4) {
                    Text("Lap \(timer.laps.count + 1):")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.40))
                    Text(formatTime(currentLapSplit))
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .monospacedDigit()
                }

                // Action Buttons
                HStack(spacing: 8) {
                    if isRunning {
                        Button {
                            withAnimation(IslandSpring.bouncy) {
                                timer.addLap()
                            }
                        } label: {
                            Label("Lap", systemImage: "flag.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.white)
                                .frame(width: 82, height: 28)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                        Button {
                            timer.pauseStopwatch()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .frame(width: 82, height: 28)
                                .background(Color.yellow)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    } else {
                        Button {
                            withAnimation(IslandSpring.bouncy) {
                                timer.resetStopwatch()
                            }
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(IslandFont.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 82, height: 28)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))

                        Button {
                            timer.startStopwatch()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(IslandFont.caption)
                                .foregroundColor(.black)
                                .frame(width: 82, height: 28)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(width: 185)

            // ── Glass Divider ─────────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 0.5, height: 110)

            // ── Right Column: Full Laps Table ─────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                // Table Header
                HStack {
                    Text("LAP")
                        .frame(width: 55, alignment: .leading)
                    Spacer()
                    Text("SPLIT")
                        .frame(width: 80, alignment: .trailing)
                    Spacer()
                    Text("TOTAL")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(IslandFont.micro)
                .foregroundColor(.white.opacity(0.40))
                .padding(.horizontal, 6)
                .padding(.bottom, 2)

                // Scrollable Lap Rows (Uses entire available height)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(timer.laps.enumerated()), id: \.offset) { idx, cumulative in
                            let lapNum = timer.laps.count - idx
                            let prev = idx + 1 < timer.laps.count ? timer.laps[idx + 1] : 0.0
                            let split = cumulative - prev
                            let isFastest = (idx == fastestLapIndex)
                            let isSlowest = (idx == slowestLapIndex)
                            let color: Color = isFastest ? .green : (isSlowest ? .red : .white.opacity(0.88))

                            HStack {
                                HStack(spacing: 3) {
                                    Text("Lap \(lapNum)")
                                        .foregroundColor(color)
                                    if isFastest {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 7))
                                            .foregroundColor(.green)
                                    } else if isSlowest {
                                        Image(systemName: "tortoise.fill")
                                            .font(.system(size: 7))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                }
                                .frame(width: 55, alignment: .leading)

                                Spacer()

                                Text(formatTime(split))
                                    .foregroundColor(color)
                                    .monospacedDigit()
                                    .frame(width: 80, alignment: .trailing)

                                Spacer()

                                Text(formatTime(cumulative))
                                    .foregroundColor(.white.opacity(0.60))
                                    .monospacedDigit()
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(IslandFont.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isFastest ? Color.green.opacity(0.10) : (isSlowest ? Color.red.opacity(0.08) : Color.white.opacity(0.03)))
                            )
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .frame(maxHeight: 88)

                // Footer Summary
                HStack {
                    Text("\(timer.laps.count) \(timer.laps.count == 1 ? "lap" : "laps")")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.35))

                    Spacer()

                    if fastestLapIndex != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7))
                            Text("Best: \(formatTime(fastestLapDuration))")
                        }
                        .font(IslandFont.micro)
                        .foregroundColor(.green.opacity(0.85))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
    }

    private func formatTime(_ t: Double) -> String {
        let total = Int(t)
        let hours = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        let ms = Int((t.truncatingRemainder(dividingBy: 1.0)) * 100)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, m, s, ms)
        } else {
            return String(format: "%02d:%02d.%02d", m, s, ms)
        }
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
