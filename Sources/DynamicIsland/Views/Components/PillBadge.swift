import SwiftUI

public struct PillBadge: View {
    public var icon: String?
    public var text: String
    public var color: Color
    
    public init(icon: String? = nil, text: String, color: Color = .blue) {
        self.icon = icon
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(IslandFont.iconMicro)
            }
            Text(text)
                .font(IslandFont.metricNumeric)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}
