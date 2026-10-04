import SwiftUI

// MARK: - Pane 5: Geometry & notch

// MARK: - Tab 5: Geometry Settings Tab

public struct GeometrySettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var detector = NotchDetector.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Geometry & Calibration")
                    .font(.system(size: 17, weight: .bold))
                Text("Hardware notch detection readouts and fine-tuning calibration offsets.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Hardware Detection Card
            SettingsCard(
                title: "Hardware Notch Telemetry",
                icon: "display",
                iconColor: .orange,
                subtitle: "Real-time measurements detected from NSScreen and CoreGraphics."
            ) {
                VStack(spacing: 8) {
                    SettingsRow(title: "Hardware Camera Notch:") {
                        Text(detector.currentNotch.hasPhysicalNotch ? "Detected (MacBook Pro)" : "None (Floating Mode)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(detector.currentNotch.hasPhysicalNotch ? .green : .blue)
                    }
                    Divider()
                    SettingsRow(title: "Measured Notch Width:") {
                        Text(String(format: "%.1f pt", detector.currentNotch.notchWidth))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Divider()
                    SettingsRow(title: "Measured Notch Height:") {
                        Text(String(format: "%.1f pt", detector.currentNotch.notchHeight))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Divider()
                    SettingsRow(title: "Screen Resolution:") {
                        Text("\(Int(detector.currentNotch.screenFrame.width)) × \(Int(detector.currentNotch.screenFrame.height)) pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Sliders for Fine-Tuning
            SettingsCard(
                title: "Position Fine-Tuning",
                icon: "slider.horizontal.3",
                iconColor: .teal,
                subtitle: "Adjust horizontal width offset and vertical placement margins."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Width Offset:")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            Text(String(format: "%+.0f pt", settings.customWidthOffset))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        Slider(value: $settings.customWidthOffset, in: -50...100, step: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Y-Axis Vertical Offset:")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            Text(String(format: "%+.0f pt", settings.customYOffset))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        Slider(value: $settings.customYOffset, in: -10...30, step: 1)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            settings.customWidthOffset = 0.0
                            settings.customYOffset = 0.0
                        }
                        .font(.system(size: 11))
                    }
                }
            }
        }
    }
}

