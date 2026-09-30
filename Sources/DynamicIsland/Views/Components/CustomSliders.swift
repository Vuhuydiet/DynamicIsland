import SwiftUI

public struct CustomSlider: View {
    @Binding public var value: Double
    public var icon: String
    public var tint: Color
    public var onEditingChanged: ((Bool) -> Void)? = nil
    
    public init(value: Binding<Double>, icon: String, tint: Color = .white, onEditingChanged: ((Bool) -> Void)? = nil) {
        self._value = value
        self.icon = icon
        self.tint = tint
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                
                // Filled progress
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))))
                
                // Icon on the left
                HStack {
                    Image(systemName: icon)
                        .font(IslandFont.iconRegular)
                        .foregroundColor(value > 0.15 ? .black.opacity(0.85) : .white.opacity(0.7))
                        .padding(.leading, 10)
                    Spacer()
                }
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = max(0.0, min(1.0, Double(gesture.location.x / geo.size.width)))
                        value = newValue
                        onEditingChanged?(true)
                    }
                    .onEnded { _ in
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 28)
    }
}
