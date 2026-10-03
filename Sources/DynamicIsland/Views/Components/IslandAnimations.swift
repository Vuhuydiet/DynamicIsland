import SwiftUI

/// Expansion animation styles for Dynamic Island
public enum ExpansionAnimationStyle: String, CaseIterable, Identifiable, Codable {
    case fluidApple     = "Fluid Apple"
    case holographicHUD = "Holographic HUD"
    
    public var id: String { rawValue }
    
    public var displayName: String { rawValue }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "Fluid Apple", "Fluid Balloon", "Apple Spring", "Default":
            self = .fluidApple
        case "Holographic HUD", "Drawer Slide", "Snappy & Crisp", "Quantum Portal", "Pop & Bloom", "Bouncy Elastic", "Liquid Jelly", "Fluid Morph", "Origami Crease", "3D Flip Down", "Wings Unfold", "Cosmic Stardust", "Cinematic Flow", "Waterfall Curtain", "Curtain Drop", "Gentle Smooth":
            self = .holographicHUD
        default:
            return nil
        }
    }
    
    public var icon: String {
        switch self {
        case .fluidApple:     return "apple.logo"
        case .holographicHUD: return "viewfinder"
        }
    }
    
    public var badge: String {
        switch self {
        case .fluidApple:     return "Apple Classic"
        case .holographicHUD: return "Stark Laser"
        }
    }
    
    public var description: String {
        switch self {
        case .fluidApple:
            return "Authentic Cupertino minimalism: symmetrical organic fluid ballooning with continuous bezier flares."
        case .holographicHUD:
            return "Iron Man Stark Tech: cyan laser scan line sweeps down from the camera notch accompanied by HUD corner targeting reticles."
        }
    }
    
    public var animationMechanicSummary: String {
        switch self {
        case .fluidApple:     return "Simultaneous fluid stretch"
        case .holographicHUD: return "Laser sweep + HUD reticles"
        }
    }
    
    public func widthAnimation(isExpanded: Bool, speedMultiplier: Double = 1.0) -> Animation {
        let speed = max(0.5, min(2.0, speedMultiplier))
        switch self {
        case .fluidApple:
            return .spring(response: 0.38 / speed, dampingFraction: 0.75)
        case .holographicHUD:
            return .spring(response: 0.28 / speed, dampingFraction: 0.82)
        }
    }
    
    public func heightAnimation(isExpanded: Bool, speedMultiplier: Double = 1.0) -> Animation {
        let speed = max(0.5, min(2.0, speedMultiplier))
        switch self {
        case .fluidApple:
            return .spring(response: 0.38 / speed, dampingFraction: 0.75)
        case .holographicHUD:
            return .spring(response: 0.30 / speed, dampingFraction: 0.80)
        }
    }
    
    public func expandAnimation(speedMultiplier: Double = 1.0) -> Animation {
        let speed = max(0.5, min(2.0, speedMultiplier))
        switch self {
        case .fluidApple:
            return .spring(response: 0.38 / speed, dampingFraction: 0.75)
        case .holographicHUD:
            return .spring(response: 0.30 / speed, dampingFraction: 0.80)
        }
    }
    
    public func collapseAnimation(speedMultiplier: Double = 1.0) -> Animation {
        let speed = max(0.5, min(2.0, speedMultiplier))
        switch self {
        case .fluidApple:
            return .spring(response: 0.30 / speed, dampingFraction: 0.84)
        case .holographicHUD:
            return .spring(response: 0.24 / speed, dampingFraction: 0.88)
        }
    }
    
    public func expandedContentTransition(speedMultiplier: Double = 1.0) -> AnyTransition {
        let speed = max(0.5, min(2.0, speedMultiplier))
        let anim = expandAnimation(speedMultiplier: speed)
        
        switch self {
        case .fluidApple:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).animation(anim.delay(0.04 / speed)),
                removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)).animation(.easeOut(duration: 0.12 / speed))
            )
        case .holographicHUD:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).animation(anim.delay(0.02 / speed)),
                removal: .opacity.animation(.easeOut(duration: 0.08 / speed))
            )
        }
    }
    
    public func compactContentTransition(speedMultiplier: Double = 1.0) -> AnyTransition {
        let speed = max(0.5, min(2.0, speedMultiplier))
        let anim = collapseAnimation(speedMultiplier: speed)
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.88, anchor: .top)).animation(anim.delay(0.05 / speed)),
            removal: .opacity.combined(with: .scale(scale: 0.82, anchor: .top)).animation(.easeOut(duration: 0.10 / speed))
        )
    }
}

/// Standardized spring physics and tactile animations matching Apple Dynamic Island
public enum IslandSpring {
    public static var expand: Animation {
        SettingsManager.shared.expansionAnimation.expandAnimation(
            speedMultiplier: SettingsManager.shared.animationSpeedMultiplier
        )
    }
    
    public static var collapse: Animation {
        SettingsManager.shared.expansionAnimation.collapseAnimation(
            speedMultiplier: SettingsManager.shared.animationSpeedMultiplier
        )
    }
    
    public static let tabSlide = Animation.spring(response: 0.32, dampingFraction: 0.76, blendDuration: 0)
    public static let bouncy = Animation.spring(response: 0.22, dampingFraction: 0.65, blendDuration: 0)
    public static let visualizer = Animation.spring(response: 0.18, dampingFraction: 0.65, blendDuration: 0.04)
    public static let hover = Animation.spring(response: 0.25, dampingFraction: 0.75)
}

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

public struct PillButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(IslandSpring.bouncy, value: configuration.isPressed)
    }
}
