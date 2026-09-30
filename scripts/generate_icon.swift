import AppKit
import Foundation

func generateAppIcon() {
    let size: CGFloat = 1024
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    
    let image = NSImage(size: rect.size)
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return
    }
    
    // Background: Dark Sleek Gradient
    let bgColors = [
        NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        let roundedRect = CGPath(roundedRect: rect.insetBy(dx: 40, dy: 40), cornerWidth: 220, cornerHeight: 220, transform: nil)
        ctx.addPath(roundedRect)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 984), end: CGPoint(x: 512, y: 40), options: [])
    }
    
    // Outer subtle glowing squircle border
    ctx.resetClip()
    let borderPath = CGPath(roundedRect: rect.insetBy(dx: 40, dy: 40), cornerWidth: 220, cornerHeight: 220, transform: nil)
    ctx.addPath(borderPath)
    ctx.setLineWidth(4)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.15).cgColor)
    ctx.strokePath()
    
    // Vibrant Neon Accent Arc / Glow around center
    let glowColors = [
        NSColor(red: 0.95, green: 0.3, blue: 0.6, alpha: 0.4).cgColor,
        NSColor(red: 0.4, green: 0.4, blue: 0.95, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.saveGState()
        let glowCenter = CGPoint(x: 512, y: 560)
        ctx.drawRadialGradient(glowGrad, startCenter: glowCenter, startRadius: 40, endCenter: glowCenter, endRadius: 360, options: [])
        ctx.restoreGState()
    }
    
    // Dynamic Island Pill in center
    let pillRect = CGRect(x: 182, y: 442, width: 660, height: 160)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 80, cornerHeight: 80, transform: nil)
    
    // Shadow for pill
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.8).cgColor)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.addPath(pillPath)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Pill outline
    ctx.addPath(pillPath)
    ctx.setLineWidth(3)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.22).cgColor)
    ctx.strokePath()
    
    // Camera dot on the left of pill
    let cameraRect = CGRect(x: 230, y: 502, width: 40, height: 40)
    ctx.setFillColor(NSColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0).cgColor)
    ctx.fillEllipse(in: cameraRect)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 0.6).cgColor)
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: cameraRect)
    
    // Animated equalizer bars on the right
    let barHeights: [CGFloat] = [30, 60, 95, 45, 80, 50, 25]
    let startX: CGFloat = 630
    for (i, h) in barHeights.enumerated() {
        let barRect = CGRect(x: startX + CGFloat(i * 18), y: 522 - (h / 2), width: 10, height: h)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        
        ctx.setFillColor(NSColor(red: 0.15, green: 0.85, blue: 0.45, alpha: 1.0).cgColor)
        ctx.addPath(barPath)
        ctx.fillPath()
    }
    
    // Music note icon in center-left
    let font = NSFont.systemFont(ofSize: 42, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 1.0, green: 0.35, blue: 0.65, alpha: 1.0)
    ]
    let noteStr = "♫" as NSString
    noteStr.draw(at: NSPoint(x: 320, y: 494), withAttributes: attrs)
    
    image.unlockFocus()
    
    // Save to PNG
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    
    let outputURL = URL(fileURLWithPath: "scripts/icon_1024.png")
    try? pngData.write(to: outputURL)
    print("Generated 1024x1024 PNG at \(outputURL.path)")
}

generateAppIcon()
