import SwiftUI

/// A custom shape that matches the hardware MacBook notch and Dynamic Island geometry:
/// - Smooth concave fillets at the top corners flaring into the screen bezel
/// - Straight vertical left and right side edges
/// - Smooth convex rounded corners at the bottom
/// - Flat horizontal bottom edge enclosing the notch
public struct NotchIslandShape: Shape {
    public static let compactFlareWidth: CGFloat = 12.0
    public static let compactFlareHeight: CGFloat = 10.0
    public static let expandedFlareWidth: CGFloat = 22.0
    public static let expandedFlareHeight: CGFloat = 18.0
    
    public static let defaultFlareWidth: CGFloat = 12.0
    public static let defaultFlareHeight: CGFloat = 10.0
    public static let defaultBottomRadius: CGFloat = 14.0
    
    public var flareWidth: CGFloat
    public var flareHeight: CGFloat
    public var rBottom: CGFloat
    public var isExpanded: Bool
    
    public init(
        flareWidth: CGFloat = NotchIslandShape.defaultFlareWidth,
        flareHeight: CGFloat = NotchIslandShape.defaultFlareHeight,
        rBottom: CGFloat = NotchIslandShape.defaultBottomRadius,
        isExpanded: Bool = false
    ) {
        self.flareWidth = flareWidth
        self.flareHeight = flareHeight
        self.rBottom = rBottom
        self.isExpanded = isExpanded
    }
    
    public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(flareWidth, AnimatablePair(flareHeight, rBottom))
        }
        set {
            flareWidth = newValue.first
            flareHeight = newValue.second.first
            rBottom = newValue.second.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let fw = min(max(0, flareWidth), w / 4)
        let fh = min(max(0, flareHeight), h / 2)
        let rb = min(max(0, rBottom), max(0, h - fh - 2))
        
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 1. Top-left concave fillet:
        // Curves from horizontal tangent at (0, 0) to vertical tangent at (fw, fh)
        path.addCurve(
            to: CGPoint(x: fw, y: fh),
            control1: CGPoint(x: fw * 0.55, y: 0),
            control2: CGPoint(x: fw, y: fh * 0.45)
        )
        
        // 2. Straight vertical left edge: from (fw, fh) down to (fw, h - rb)
        path.addLine(to: CGPoint(x: fw, y: h - rb))
        
        // 3. Bottom-left convex corner: from (fw, h - rb) curving to horizontal tangent at (fw + rb, h)
        path.addArc(
            tangent1End: CGPoint(x: fw, y: h),
            tangent2End: CGPoint(x: fw + rb, y: h),
            radius: rb
        )
        
        // 4. Straight horizontal bottom edge: across to (w - fw - rb, h)
        path.addLine(to: CGPoint(x: w - fw - rb, y: h))
        
        // 5. Bottom-right convex corner: from (w - fw - rb, h) curving to vertical tangent at (w - fw, h - rb)
        path.addArc(
            tangent1End: CGPoint(x: w - fw, y: h),
            tangent2End: CGPoint(x: w - fw, y: h - rb),
            radius: rb
        )
        
        // 6. Straight vertical right edge: from (w - fw, h - rb) up to (w - fw, fh)
        path.addLine(to: CGPoint(x: w - fw, y: fh))
        
        // 7. Top-right concave fillet:
        // Curves from vertical tangent at (w - fw, fh) to horizontal tangent at (w, 0)
        path.addCurve(
            to: CGPoint(x: w, y: 0),
            control1: CGPoint(x: w - fw, y: fh * 0.45),
            control2: CGPoint(x: w - fw * 0.55, y: 0)
        )
        
        // 8. Straight horizontal top edge: back to (0, 0)
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
    }
}

/// Adaptive container shape for the island supporting both Notch and Floating modes
public struct IslandContainerShape: Shape {
    public var isNotchMode: Bool
    public var cornerRadius: CGFloat
    public var flareWidth: CGFloat
    public var flareHeight: CGFloat
    
    public init(
        isNotchMode: Bool,
        cornerRadius: CGFloat = 16.0,
        flareWidth: CGFloat = NotchIslandShape.defaultFlareWidth,
        flareHeight: CGFloat = NotchIslandShape.defaultFlareHeight
    ) {
        self.isNotchMode = isNotchMode
        self.cornerRadius = cornerRadius
        self.flareWidth = flareWidth
        self.flareHeight = flareHeight
    }
    
    public init(
        isNotchMode: Bool,
        isExpanded: Bool,
        cornerRadius: CGFloat = 16.0
    ) {
        self.isNotchMode = isNotchMode
        self.cornerRadius = cornerRadius
        self.flareWidth = isExpanded ? NotchIslandShape.expandedFlareWidth : NotchIslandShape.compactFlareWidth
        self.flareHeight = isExpanded ? NotchIslandShape.expandedFlareHeight : NotchIslandShape.compactFlareHeight
    }
    
    public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(cornerRadius, AnimatablePair(flareWidth, flareHeight))
        }
        set {
            cornerRadius = newValue.first
            flareWidth = newValue.second.first
            flareHeight = newValue.second.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        if isNotchMode {
            let shape = NotchIslandShape(
                flareWidth: flareWidth,
                flareHeight: flareHeight,
                rBottom: cornerRadius
            )
            return shape.path(in: rect)
        } else {
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        }
    }
}

