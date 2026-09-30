import SwiftUI

public struct SystemHUDView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Resource Gauges Row
            HStack(spacing: 12) {
                // CPU Gauge
                MetricCard(
                    title: "CPU Load",
                    value: String(format: "%.1f%%", monitor.stats.cpuUsage),
                    icon: "cpu",
                    progress: monitor.stats.cpuUsage / 100.0,
                    tint: monitor.stats.cpuUsage > 75 ? .red : (monitor.stats.cpuUsage > 40 ? .orange : .cyan)
                )
                
                // RAM Gauge
                MetricCard(
                    title: "Memory",
                    value: String(format: "%.1f/%.0f GB", monitor.stats.ramUsedGB, monitor.stats.ramTotalGB),
                    icon: "memorychip",
                    progress: monitor.stats.ramTotalGB > 0 ? (monitor.stats.ramUsedGB / monitor.stats.ramTotalGB) : 0,
                    tint: .purple
                )
                
                // Battery Gauge
                MetricCard(
                    title: "Battery",
                    value: "\(monitor.stats.batteryPercent)%",
                    icon: monitor.stats.isCharging ? "bolt.fill" : "battery.100",
                    progress: Double(monitor.stats.batteryPercent) / 100.0,
                    tint: monitor.stats.isCharging ? .green : (monitor.stats.batteryPercent < 20 ? .red : .yellow)
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // MARK: - System Volume Slider
            VStack(spacing: 4) {
                CustomSlider(
                    value: Binding(
                        get: { monitor.stats.systemVolume },
                        set: { monitor.setSystemVolume($0) }
                    ),
                    icon: monitor.stats.isMuted ? "speaker.slash.fill" : (monitor.stats.systemVolume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"),
                    tint: .white.opacity(0.85)
                )
            }
            .padding(.horizontal, 14)
            
            // MARK: - Quick Action Buttons
            HStack(spacing: 10) {
                QuickActionButton(
                    icon: "lock.fill",
                    label: "Lock Screen",
                    color: .orange
                ) {
                    monitor.lockScreen()
                }
                
                QuickActionButton(
                    icon: "powersleep",
                    label: "Sleep",
                    color: .indigo
                ) {
                    monitor.sleepDisplay()
                }
                
                QuickActionButton(
                    icon: monitor.stats.isMuted ? "speaker.slash.fill" : "speaker.fill",
                    label: monitor.stats.isMuted ? "Unmute" : "Mute",
                    color: monitor.stats.isMuted ? .red : .gray
                ) {
                    monitor.toggleMute()
                }
                
                QuickActionButton(
                    icon: "trash.fill",
                    label: "Empty Trash",
                    color: .gray
                ) {
                    monitor.emptyTrash()
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }
}

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let icon: String
    public let progress: Double
    public let tint: Color
    
    public var body: some View {
        HStack(spacing: 8) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(IslandFont.iconSmall)
                    .foregroundColor(tint)
            }
            .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.45))
                
                Text(value)
                    .font(IslandFont.metricNumeric)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

public struct QuickActionButton: View {
    public let icon: String
    public let label: String
    public let color: Color
    public let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(IslandFont.iconSmall)
                Text(label)
                    .font(IslandFont.caption)
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
