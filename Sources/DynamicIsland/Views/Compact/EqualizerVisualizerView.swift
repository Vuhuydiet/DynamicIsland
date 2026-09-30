import SwiftUI

public struct EqualizerVisualizerView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    public var tint: Color
    public var maxHeight: CGFloat
    
    public init(tint: Color = .green, maxHeight: CGFloat = 14) {
        self.tint = tint
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        HStack(spacing: 2.2) {
            ForEach(0..<mediaManager.visualizerHeights.count, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tint)
                    .frame(
                        width: 2.5,
                        height: max(3, maxHeight * mediaManager.visualizerHeights[idx])
                    )
                    .animation(
                        .easeInOut(duration: 0.12),
                        value: mediaManager.visualizerHeights[idx]
                    )
            }
        }
        .frame(height: maxHeight)
    }
}
