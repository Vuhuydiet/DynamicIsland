import SwiftUI

// MARK: - Pane 7: About

// MARK: - Tab 7: About Settings Tab

public struct AboutSettingsTab: View {
    public var body: some View {
        VStack(alignment: .center, spacing: 18) {
            Spacer(minLength: 10)
            
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.15), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 22)
                    .shadow(color: .pink.opacity(0.5), radius: 6)
            }
            
            VStack(spacing: 4) {
                Text("Dynamic Island")
                    .font(.system(size: 20, weight: .bold))
                Text("Version 1.0.0 (Build 2026.10)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text("Engineered natively in Swift & SwiftUI for MacBook Pro & MacBook Air with real-time fluid spring physics and hardware notch integration.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 380)
            
            // Tech badges
            HStack(spacing: 6) {
                ForEach(["AppKit", "SwiftUI", "CoreAudio", "IOKit", "MediaRemote"], id: \.self) { tech in
                    Text(tech)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(NSColor.controlColor)))
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .frame(width: 320)
            
            HStack(spacing: 12) {
                Button("Quit Dynamic Island") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

