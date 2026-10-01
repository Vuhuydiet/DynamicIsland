import SwiftUI

/// Standardized spring physics and tactile animations matching Apple Dynamic Island
public enum IslandSpring {
    /// Elastic blooming spring when expanding the island (Apple-calibrated fluid stretch)
    public static let expand = Animation.spring(response: 0.38, dampingFraction: 0.75, blendDuration: 0)
    
    /// Snappy, crisp spring when returning to compact/notch
    public static let collapse = Animation.spring(response: 0.30, dampingFraction: 0.84, blendDuration: 0)
    
    /// Smooth sliding spring for tab switcher pill and segmented indicators
    public static let tabSlide = Animation.spring(response: 0.32, dampingFraction: 0.76, blendDuration: 0)
    
    /// Micro tactile response for buttons, icons, and hover feedback
    public static let bouncy = Animation.spring(response: 0.22, dampingFraction: 0.65, blendDuration: 0)
    
    /// Organic audio visualizer wave bounce
    public static let visualizer = Animation.spring(response: 0.18, dampingFraction: 0.65, blendDuration: 0.04)
    
    /// Subtle breathing hover
    public static let hover = Animation.spring(response: 0.25, dampingFraction: 0.75)
}

/// A tactile spring-based button style providing micro-scale physical feedback upon click
public struct BouncyButtonStyle: ButtonStyle {
    public var scaleAmount: CGFloat
    public var opacityAmount: Double
    
    public init(scaleAmount: CGFloat = 0.92, opacityAmount: Double = 0.85) {
        self.scaleAmount = scaleAmount
        self.opacityAmount = opacityAmount
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? opacityAmount : 1.0)
            .animation(IslandSpring.bouncy, value: configuration.isPressed)
    }
}

/// Subtle pill button style for tab items and segmented controls
public struct PillButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(IslandSpring.bouncy, value: configuration.isPressed)
    }
}
