import SwiftUI

/// Creative visual effects and laser scan HUD rendered during island expansion
public struct IslandVFXOverlayView: View {
    public let style: ExpansionAnimationStyle
    public let isExpanded: Bool
    public let width: CGFloat
    public let height: CGFloat
    
    @State private var scanLineProgress: CGFloat = 0.0
    @State private var laserOpacity: Double = 0.0
    
    public init(style: ExpansionAnimationStyle, isExpanded: Bool, width: CGFloat, height: CGFloat) {
        self.style = style
        self.isExpanded = isExpanded
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            switch style {
            case .holographicHUD:
                holographicHUDLayer
            case .fluidApple:
                EmptyView()
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .allowsHitTesting(false)
        .onChange(of: isExpanded) { _, expanded in
            triggerVFX(expanded: expanded)
        }
        .onAppear {
            if isExpanded {
                triggerVFX(expanded: true)
            }
        }
    }
    
    private func triggerVFX(expanded: Bool) {
        if expanded && style == .holographicHUD {
            scanLineProgress = 0.0
            laserOpacity = 1.0
            withAnimation(.easeOut(duration: 0.48)) {
                scanLineProgress = 1.0
            }
            withAnimation(.easeIn(duration: 0.20).delay(0.38)) {
                laserOpacity = 0.0
            }
        } else {
            laserOpacity = 0.0
        }
    }
    
    // MARK: - Holographic HUD (Stark Tech)
    
    private var holographicHUDLayer: some View {
        ZStack(alignment: .top) {
            // Sweeping Cyan Laser Beam
            if laserOpacity > 0.01 {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: max(0, scanLineProgress * (height - 8)))
                    
                    ZStack {
                        // Laser glow
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.cyan.opacity(0.4), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 18)
                        
                        // Sharp cutting core line
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color(red: 0.4, green: 0.95, blue: 1.0), Color.white, Color(red: 0.4, green: 0.95, blue: 1.0), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1.5)
                            .shadow(color: .cyan, radius: 4)
                    }
                    
                    Spacer()
                }
                .opacity(laserOpacity)
            }
            
            // HUD Targeting Corner Reticles [ ]
            if isExpanded {
                ZStack {
                    // Top-Left Reticle
                    targetingBracket(edge: .topLeading)
                        .position(x: 18, y: 18)
                    
                    // Top-Right Reticle
                    targetingBracket(edge: .topTrailing)
                        .position(x: width - 18, y: 18)
                    
                    // Bottom-Left Reticle
                    targetingBracket(edge: .bottomLeading)
                        .position(x: 18, y: height - 18)
                    
                    // Bottom-Right Reticle
                    targetingBracket(edge: .bottomTrailing)
                        .position(x: width - 18, y: height - 18)
                    
                    // Center Targeting Crosshair
                    HStack(spacing: 4) {
                        Circle()
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                            .frame(width: 6, height: 6)
                        Rectangle()
                            .fill(Color.cyan.opacity(0.5))
                            .frame(width: 8, height: 1)
                    }
                    .position(x: width / 2.0, y: height - 14)
                }
                .transition(.opacity.animation(.easeOut(duration: 0.25)))
            }
        }
    }
    
    private func targetingBracket(edge: Alignment) -> some View {
        Path { path in
            let size: CGFloat = 8
            switch edge {
            case .topLeading:
                path.move(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case .topTrailing:
                path.move(to: CGPoint(x: -size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case .bottomLeading:
                path.move(to: CGPoint(x: 0, y: -size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case .bottomTrailing:
                path.move(to: CGPoint(x: -size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -size))
            default:
                break
            }
        }
        .stroke(Color.cyan.opacity(isExpanded ? 0.75 : 0.0), lineWidth: 1.5)
        .shadow(color: .cyan.opacity(0.6), radius: 3)
        .frame(width: 8, height: 8)
    }
}
