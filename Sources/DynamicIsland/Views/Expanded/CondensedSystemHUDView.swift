import SwiftUI

public struct CondensedSystemHUDView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. CPU Load
            CondensedMetricPill(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.0f%%", monitor.stats.cpuUsage),
                progress: monitor.stats.cpuUsage / 100.0,
                tint: monitor.stats.cpuUsage > 80 ? .red : (monitor.stats.cpuUsage > 50 ? .orange : .cyan)
            )
            
            // 2. RAM Memory
            CondensedMetricPill(
                icon: "memorychip",
                label: "RAM",
                value: String(format: "%.1f GB", monitor.stats.ramUsedGB),
                progress: monitor.stats.ramTotalGB > 0 ? (monitor.stats.ramUsedGB / monitor.stats.ramTotalGB) : 0,
                tint: .purple
            )
            
            // 3. Battery
            CondensedMetricPill(
                icon: monitor.stats.isCharging ? "bolt.fill" : (monitor.stats.batteryPercent < 20 ? "battery.25" : "battery.100"),
                label: "BAT",
                value: "\(monitor.stats.batteryPercent)%",
                progress: Double(monitor.stats.batteryPercent) / 100.0,
                tint: monitor.stats.isCharging ? .green : (monitor.stats.batteryPercent < 20 ? .red : .yellow)
            )
            
            // 4. Disk Storage (used / total)
            CondensedMetricPill(
                icon: "internaldrive",
                label: "DISK",
                value: String(format: "%.0f/%.0f GB", monitor.stats.diskUsedGB, monitor.stats.diskTotalGB),
                progress: monitor.stats.diskTotalGB > 0 ? (monitor.stats.diskUsedGB / monitor.stats.diskTotalGB) : 0,
                tint: .blue
            )
        }
        .padding(.horizontal, 14)
    }
}

public struct CondensedMetricPill: View {
    public let icon: String
    public let label: String
    public let value: String
    public let progress: Double
    public let tint: Color
    
    public init(icon: String, label: String, value: String, progress: Double, tint: Color) {
        self.icon = icon
        self.label = label
        self.value = value
        self.progress = progress
        self.tint = tint
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Mini Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2.2)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(tint)
            }
            .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.45))
                
                Text(value)
                    .font(IslandFont.metricNumeric)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
