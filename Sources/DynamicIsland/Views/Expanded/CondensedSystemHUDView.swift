import SwiftUI

public struct CondensedSystemHUDView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    
    private let badgeWidth: CGFloat = 38.0
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 3.5) {
            // 1. CPU Load
            InlineMetricBadge(
                icon: "cpu",
                value: String(format: "%.0f%%", monitor.stats.cpuUsage),
                tint: monitor.stats.cpuUsage > 80 ? .red : (monitor.stats.cpuUsage > 50 ? .orange : .cyan),
                helpText: String(format: "CPU Usage: %.1f%%", monitor.stats.cpuUsage),
                width: badgeWidth
            )
            
            // 2. RAM Memory
            InlineMetricBadge(
                icon: "memorychip",
                value: String(format: "%.1fG", monitor.stats.ramUsedGB),
                tint: .purple,
                helpText: String(format: "RAM: %.1f / %.1f GB", monitor.stats.ramUsedGB, monitor.stats.ramTotalGB),
                width: badgeWidth
            )
            
            // 3. Battery
            InlineMetricBadge(
                icon: monitor.stats.isCharging ? "bolt.fill" : (monitor.stats.batteryPercent < 20 ? "battery.25" : "battery.100"),
                value: "\(monitor.stats.batteryPercent)%",
                tint: monitor.stats.isCharging ? .green : (monitor.stats.batteryPercent < 20 ? .red : .yellow),
                helpText: "Battery: \(monitor.stats.batteryPercent)%\(monitor.stats.isCharging ? " (Charging)" : "")",
                width: badgeWidth
            )
            
            // 4. Disk Storage (used)
            InlineMetricBadge(
                icon: "internaldrive",
                value: String(format: "%.0fG", monitor.stats.diskUsedGB),
                tint: .blue,
                helpText: String(format: "Disk: %.0f / %.0f GB used", monitor.stats.diskUsedGB, monitor.stats.diskTotalGB),
                width: badgeWidth
            )
        }
    }
}

public struct InlineMetricBadge: View {
    public let icon: String
    public let value: String
    public let tint: Color
    public let helpText: String
    public let width: CGFloat
    
    public init(icon: String, value: String, tint: Color, helpText: String, width: CGFloat = 38.0) {
        self.icon = icon
        self.value = value
        self.tint = tint
        self.helpText = helpText
        self.width = width
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(tint)
            
            Text(value)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: width, height: 28)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(helpText)
    }
}
