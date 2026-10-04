import SwiftUI

// MARK: - Pane 2: Animations & spring physics

// MARK: - Tab 2: Animations & Spring Physics Tab (NEW)

public struct AnimationsSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Expansion & Spring Physics")
                    .font(.system(size: 17, weight: .bold))
                Text("Calibrate the organic ballooning stretch, spring bounce, and fluid morphing physics of Dynamic Island.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Live Interactive Preview Playground
            SettingsCard(
                title: "Live Interactive Physics Playground",
                icon: "play.circle.fill",
                iconColor: .purple,
                subtitle: "Test how the selected spring curves stretch and settle in real time."
            ) {
                AnimationPlaygroundView()
            }

            // 2. Expansion Animation Presets
            SettingsCard(
                title: "Expansion Animation Styles",
                icon: "waveform.path",
                iconColor: .indigo,
                subtitle: "Select a curated physical spring profile tailored for different speeds and aesthetics."
            ) {
                VStack(spacing: 8) {
                    ForEach(ExpansionAnimationStyle.allCases) { animStyle in
                        let isSelected = settings.expansionAnimation == animStyle
                        AnimationCard(
                            animStyle: animStyle,
                            isSelected: isSelected,
                            onSelect: {
                                withAnimation(animStyle.expandAnimation(speedMultiplier: settings.animationSpeedMultiplier)) {
                                    settings.expansionAnimation = animStyle
                                }
                                SoundManager.shared.play(.click)
                            }
                        )
                    }
                }
            }

            // 3. Animation Speed Multiplier
            SettingsCard(
                title: "Animation Speed & Timing",
                icon: "speedometer",
                iconColor: .cyan,
                subtitle: "Scale the duration of the spring responses while preserving calibrated damping curves."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Speed:")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Text(speedLabel)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }

                    // Preset buttons
                    HStack(spacing: 8) {
                        ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { speed in
                            Button {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                    settings.animationSpeedMultiplier = speed
                                }
                            } label: {
                                Text(presetLabel(speed))
                                    .font(.system(size: 11, weight: abs(settings.animationSpeedMultiplier - speed) < 0.05 ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(abs(settings.animationSpeedMultiplier - speed) < 0.05 ? Color.accentColor : Color(NSColor.controlColor))
                                    )
                                    .foregroundColor(abs(settings.animationSpeedMultiplier - speed) < 0.05 ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Slider
                    HStack(spacing: 10) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $settings.animationSpeedMultiplier, in: 0.60...1.75, step: 0.05)
                        
                        Image(systemName: "hare.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Damping is locked to preserve elastic character. Speed adjusts spring duration.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        if abs(settings.animationSpeedMultiplier - 1.0) > 0.02 {
                            Button("Reset (1.0×)") {
                                withAnimation {
                                    settings.animationSpeedMultiplier = 1.0
                                }
                            }
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }

    private var speedLabel: String {
        let val = settings.animationSpeedMultiplier
        if abs(val - 1.0) < 0.02 {
            return "1.00× (Standard)"
        } else if val < 0.85 {
            return String(format: "%.2f× (Relaxed)", val)
        } else if val > 1.35 {
            return String(format: "%.2f× (Rapid)", val)
        } else {
            return String(format: "%.2f× (Snappy)", val)
        }
    }

    private func presetLabel(_ speed: Double) -> String {
        switch speed {
        case 0.75: return "0.75× Relaxed"
        case 1.0:  return "1.00× Normal"
        case 1.25: return "1.25× Snappy"
        case 1.5:  return "1.50× Rapid"
        default:   return String(format: "%.2f×", speed)
        }
    }
}

// MARK: - Animation Style Card

public struct AnimationCard: View {
    public let animStyle: ExpansionAnimationStyle
    public let isSelected: Bool
    public let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Radio indicator
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))

                // Icon pill
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlColor))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: animStyle.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .accentColor : .primary)
                }

                // Title & Description
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(animStyle.displayName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(animStyle.badge)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .foregroundColor(isSelected ? .white : .secondary)
                        
                        Spacer()

                        // Specs tag
                        Text(animStyle.animationMechanicSummary)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text(animStyle.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animation Playground View (Live Simulated Notch & Island)

public struct AnimationPlaygroundView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isTestExpanded = false
    @State private var autoLoop = false

    public var body: some View {
        VStack(spacing: 12) {
            // Simulated Bezel Canvas
            ZStack(alignment: .top) {
                // Bezel background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.08), Color(white: 0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                // The Simulated Animated Island
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        // Island Body
                        RoundedRectangle(cornerRadius: isTestExpanded ? 20 : 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.18), Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: isTestExpanded ? 20 : 10, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.6), radius: isTestExpanded ? 12 : 4, y: 3)

                        // Island Content
                        if isTestExpanded {
                            VStack(spacing: 8) {
                                // Simulated Header
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 8))
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("Dynamic Hub")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }

                                    Spacer()

                                    // Notch cutout indicator
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black)
                                        .frame(width: 44, height: 8)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text("CPU 8%")
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundColor(.green)
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 7))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.top, 6)

                                // Tab pill
                                HStack(spacing: 3) {
                                    ForEach(["Media", "Timer", "Clip", "Notes"], id: \.self) { t in
                                        Text(t)
                                            .font(.system(size: 7, weight: t == "Media" ? .bold : .regular))
                                            .foregroundColor(t == "Media" ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2.5)
                                            .frame(maxWidth: .infinity)
                                            .background(Capsule().fill(t == "Media" ? Color.white.opacity(0.2) : Color.clear))
                                    }
                                }
                                .padding(.horizontal, 10)

                                // Simulated tool content
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                        .overlay(Image(systemName: "music.note").font(.system(size: 9)).foregroundColor(.white))
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Starboy")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("The Weeknd")
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Image(systemName: "backward.fill").font(.system(size: 7)).foregroundColor(.white.opacity(0.8))
                                        Image(systemName: "play.circle.fill").font(.system(size: 14)).foregroundColor(.pink)
                                        Image(systemName: "forward.fill").font(.system(size: 7)).foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                        } else {
                            // Compact Closed Notch
                            HStack(spacing: 0) {
                                HStack(spacing: 3) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(width: 40, alignment: .trailing)
                                .padding(.trailing, 4)

                                // Center notch cutout
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 48, height: 20)

                                HStack(spacing: 3) {
                                    Text("98%")
                                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                    Image(systemName: "battery.100")
                                        .font(.system(size: 7.5))
                                        .foregroundColor(.green)
                                }
                                .frame(width: 40, alignment: .leading)
                                .padding(.leading, 4)
                            }
                            .frame(height: 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .top)))
                        }

                        // Creative VFX Overlay in simulated preview
                        IslandVFXOverlayView(
                            style: settings.expansionAnimation,
                            isExpanded: isTestExpanded,
                            width: isTestExpanded ? 340 : 150,
                            height: isTestExpanded ? 110 : 24
                        )
                    }
                    .frame(
                        width: isTestExpanded ? 340 : 150,
                        height: isTestExpanded ? 110 : 24,
                        alignment: .top
                    )
                    .animation(settings.expansionAnimation.widthAnimation(isExpanded: isTestExpanded, speedMultiplier: settings.animationSpeedMultiplier), value: isTestExpanded)
                    .animation(settings.expansionAnimation.heightAnimation(isExpanded: isTestExpanded, speedMultiplier: settings.animationSpeedMultiplier), value: isTestExpanded)
                    .animation(settings.expansionAnimation.expandAnimation(speedMultiplier: settings.animationSpeedMultiplier), value: isTestExpanded)
                }
                .padding(.top, 0)
            }

            // Controls below preview
            HStack(spacing: 12) {
                Button {
                    withAnimation {
                        isTestExpanded.toggle()
                    }
                    if isTestExpanded {
                        SoundManager.shared.play(.expand)
                    } else {
                        SoundManager.shared.play(.collapse)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isTestExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(isTestExpanded ? "Collapse Island" : "Trigger Expansion")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                // Real-time specs readout
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(settings.expansionAnimation.displayName)
                            .font(.system(size: 11, weight: .bold))
                        Text(settings.expansionAnimation.animationMechanicSummary)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

