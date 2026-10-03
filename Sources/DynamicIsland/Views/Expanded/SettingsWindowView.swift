import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case animations = "Animations"
    case behavior = "Behavior & Tabs"
    case sound = "Sound Effects"
    case geometry = "Geometry & Notch"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .animations: return "waveform.path"
        case .behavior: return "slider.horizontal.2.square"
        case .sound: return "speaker.wave.2.fill"
        case .geometry: return "macbook.and.iphone"
        case .shortcuts: return "command"
        case .about: return "info.circle.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .general: return .blue
        case .animations: return .purple
        case .behavior: return .teal
        case .sound: return .pink
        case .geometry: return .orange
        case .shortcuts: return .indigo
        case .about: return .gray
        }
    }
}

// MARK: - Reusable Settings UI Elements

/// Modern card container matching macOS System Settings design language
public struct SettingsCard<Content: View>: View {
    public let title: String
    public var icon: String? = nil
    public var iconColor: Color? = nil
    public var subtitle: String? = nil
    public var trailing: AnyView? = nil
    @ViewBuilder public let content: () -> Content

    public init(
        title: String,
        icon: String? = nil,
        iconColor: Color? = nil,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor ?? .accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let trailing = trailing {
                    trailing
                }
            }
            .padding(.bottom, 2)

            // Card Body
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.75)
            )
        }
    }
}

/// A standard horizontal row inside a SettingsCard
public struct SettingsRow<Content: View>: View {
    public let title: String
    public var subtitle: String? = nil
    @ViewBuilder public let content: () -> Content

    public init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            content()
        }
        .padding(.vertical, 4)
    }
}

/// Authentic Apple-styled keyboard shortcut cap
public struct KeyCapView: View {
    public let text: String

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(text.split(separator: " ").map(String.init), id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(NSColor.controlColor))
                            .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - Main Settings Window View

public struct SettingsWindowView: View {
    @State private var activeTab: SettingsTab = .general
    @ObservedObject var settings = SettingsManager.shared
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Sidebar Navigation
            VStack(alignment: .leading, spacing: 4) {
                // Sidebar Header Branding
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black, Color(white: 0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .purple, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 20, height: 8)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dynamic Island")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Settings & Physics")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 14)
                
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                // Navigation Items
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(SettingsTab.allCases) { tab in
                            let isSelected = activeTab == tab
                            Button {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                    activeTab = tab
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    // Colored squircle icon
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(tab.accentColor)
                                            .frame(width: 24, height: 24)
                                        
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }

                                    Text(tab.rawValue)
                                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(isSelected ? .white : .primary)

                                    Spacer()
                                    
                                    if tab == .animations {
                                        Text(settings.expansionAnimation.badge)
                                            .font(.system(size: 8.5, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? Color.white.opacity(0.25) : tab.accentColor.opacity(0.15))
                                            )
                                            .foregroundColor(isSelected ? .white : tab.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color.accentColor : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                
                Spacer()

                // Sidebar Footer status
                VStack(spacing: 4) {
                    Divider()
                        .padding(.horizontal, 12)
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Dynamic Island Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 215)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
            
            Divider()
            
            // MARK: - Right Content Area
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch activeTab {
                        case .general:
                            GeneralSettingsTab()
                        case .animations:
                            AnimationsSettingsTab()
                        case .behavior:
                            BehaviorSettingsTab()
                        case .sound:
                            SoundSettingsTab()
                        case .geometry:
                            GeometrySettingsTab()
                        case .shortcuts:
                            ShortcutsSettingsTab()
                        case .about:
                            AboutSettingsTab()
                        }
                    }
                    .padding(22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 740, minHeight: 600)
    }
}

// MARK: - Tab 1: General Settings Tab

public struct GeneralSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("General Preferences")
                    .font(.system(size: 17, weight: .bold))
                Text("Customize the look, layout shells, and system launch behaviors of Dynamic Island.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Appearance Theme
            SettingsCard(
                title: "Appearance Theme",
                icon: "paintpalette.fill",
                iconColor: .blue,
                subtitle: "Select the surface glass material and dark/light tint style."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ForEach(IslandTheme.allCases) { theme in
                            ThemeCard(theme: theme, isSelected: settings.islandTheme == theme) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.islandTheme = theme
                                }
                            }
                        }
                    }

                    Text("Liquid Glass utilizes Apple's native HUD window blur. Dark provides deep solid contrast. Light renders a high-clarity frosted pearl surface.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 2. UI Styles (Versions)
            SettingsCard(
                title: "Island UI Versions",
                icon: "paintbrush.fill",
                iconColor: .purple,
                subtitle: "Choose independent layout shells for the Closed Notch and Opened Island workspace."
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Closed Notch Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Closed Notch UI")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("Idle & Live Activities")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        ForEach(ClosedNotchStyle.allCases) { style in
                            ClosedOptionPreviewCard(style: style, isSelected: settings.closedNotchStyle == style) {
                                withAnimation(IslandSpring.bouncy) {
                                    settings.closedNotchStyle = style
                                }
                            }
                        }
                    }

                    Divider()

                    // Opened Island Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opened Island UI")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("Expanded Shell Layout")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        ForEach(OpenedIslandStyle.allCases) { style in
                            OpenedOptionPreviewCard(style: style, isSelected: settings.openedIslandStyle == style) {
                                withAnimation(IslandSpring.bouncy) {
                                    settings.openedIslandStyle = style
                                }
                            }
                        }
                    }
                }
            }

            // 3. System Integration
            SettingsCard(
                title: "System Integration",
                icon: "macwindow",
                iconColor: .green,
                subtitle: "Configure macOS menu bar and startup launch settings."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(
                        title: "Launch at Login",
                        subtitle: "Automatically starts Dynamic Island when your Mac boots up."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                    }

                    Divider()

                    SettingsRow(
                        title: "Show Menu Bar Icon",
                        subtitle: "Display a persistent status bar capsule for quick preferences and controls."
                    ) {
                        Toggle("", isOn: $settings.showMenuBarIcon)
                            .labelsHidden()
                    }
                }
            }
        }
    }
}

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

// MARK: - Tab 3: Behavior & Tabs Settings Tab

public struct BehaviorSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Behavior & Workspace")
                    .font(.system(size: 17, weight: .bold))
                Text("Configure how Dynamic Island triggers, docks, and what tools are accessible.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Island Mode
            SettingsCard(
                title: "Island Docking Mode",
                icon: "macbook",
                iconColor: .teal,
                subtitle: "Specify how Dynamic Island binds to built-in screens and external displays."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $settings.notchStyle) {
                        ForEach(NotchStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Auto Detect anchors seamlessly to the hardware camera notch on MacBooks, and floats as an elegant pill on external monitors.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 2. Expansion Trigger & Delay
            SettingsCard(
                title: "Expansion Triggers & Hover Timing",
                icon: "cursorarrow.rays",
                iconColor: .blue,
                subtitle: "Control how cursor contact expands the island."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsRow(
                        title: "Trigger Mode:",
                        subtitle: "Hover & Click expands when hovering cursor over notch. Click Only expands on mouse click."
                    ) {
                        Picker("", selection: $settings.expandTrigger) {
                            ForEach(ExpandTrigger.allCases) { trig in
                                Text(trig.rawValue).tag(trig)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Hover Delay Sensitivity:")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            if settings.hoverDelay <= 0.005 {
                                Text("Instant (0 ms)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(String(format: "%.0f ms", settings.hoverDelay * 1000))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Slider(value: $settings.hoverDelay, in: 0.0...0.60, step: 0.01)
                    }
                }
            }

            // 3. Tab Visibility
            SettingsCard(
                title: "Visible Island Tabs",
                icon: "rectangle.3.group.fill",
                iconColor: .indigo,
                subtitle: "Enable or hide built-in tool tabs. At least one tab must remain active."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(IslandTab.allCases.enumerated()), id: \.element.id) { idx, tab in
                        if idx > 0 { Divider() }
                        SettingsRow(title: tab.rawValue) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)

                                Toggle("", isOn: Binding(
                                    get: { settings.isTabVisible(tab) },
                                    set: { visible in
                                        if visible {
                                            settings.hiddenTabs.remove(tab.rawValue)
                                        } else {
                                            let remaining = IslandTab.allCases.filter { settings.isTabVisible($0) }
                                            if remaining.count > 1 {
                                                settings.hiddenTabs.insert(tab.rawValue)
                                            }
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // 4. File Drop Shelf
            SettingsCard(
                title: "File Drop Shelf Layout",
                icon: "tray.and.arrow.down.fill",
                iconColor: .orange,
                subtitle: "Files parked at the notch appear in a dedicated secondary tray below the island."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(title: "Card Presentation:") {
                        Picker("", selection: $settings.dropShelfCardStyle) {
                            ForEach(DropShelfCardStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    Text("Drag any file, folder, or image directly towards the notch to expand the drop shelf and park items for rapid drag-out.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Tab 4: Sound Settings Tab

public struct SoundSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Sound Preferences")
                    .font(.system(size: 17, weight: .bold))
                Text("Configure tactile auditory feedback for island morphs, clicks, and timer completions.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Master Sound Toggle & Volume Card
            SettingsCard(
                title: "Master Audio Controls",
                icon: "speaker.wave.3.fill",
                iconColor: .pink,
                subtitle: "Enable auditory feedback and control global sound volume."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsRow(
                        title: "Enable Sound Effects",
                        subtitle: "Plays subtle tactile clicks and sweeps during interactions."
                    ) {
                        Toggle("", isOn: $settings.soundEffectsEnabled)
                            .labelsHidden()
                    }
                    
                    if settings.soundEffectsEnabled {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Effects Volume:")
                                    .font(.system(size: 12.5, weight: .medium))
                                Spacer()
                                Text(String(format: "%.0f%%", settings.soundVolume * 100))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                Slider(value: $settings.soundVolume, in: 0.05...1.0, step: 0.05)
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                        
                        Divider()
                        
                        SettingsRow(title: "Sound Theme Scheme:") {
                            Picker("", selection: $settings.soundScheme) {
                                ForEach(SoundScheme.allCases) { scheme in
                                    Text(scheme.rawValue).tag(scheme)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 250)
                        }
                    }
                }
            }
            
            // Per-Event Sounds & Audition Test Card
            if settings.soundEffectsEnabled {
                SettingsCard(
                    title: "Event Audio & Audition",
                    icon: "music.note.list",
                    iconColor: .purple,
                    subtitle: "Toggle audio cues per individual gesture and audition sound files."
                ) {
                    VStack(spacing: 6) {
                        SoundEventRow(
                            title: "Expand Dynamic Island",
                            isOn: $settings.soundOnExpand,
                            onTest: { SoundManager.shared.play(.expand) }
                        )
                        Divider()
                        SoundEventRow(
                            title: "Collapse Dynamic Island",
                            isOn: $settings.soundOnCollapse,
                            onTest: { SoundManager.shared.play(.collapse) }
                        )
                        Divider()
                        SoundEventRow(
                            title: "Switch Tabs & Button Clicks",
                            isOn: $settings.soundOnTabSwitch,
                            onTest: { SoundManager.shared.play(.click) }
                        )
                        Divider()
                        SoundEventRow(
                            title: "Drop File to Shelf",
                            isOn: $settings.soundOnDrop,
                            onTest: { SoundManager.shared.play(.drop) }
                        )
                        Divider()
                        SoundEventRow(
                            title: "Timer Completed Alert",
                            isOn: $settings.soundOnTimer,
                            onTest: { SoundManager.shared.playTimerAlertPulse() }
                        )
                        Divider()
                        SettingsRow(
                            title: "Timer Alert Frequency:",
                            subtitle: "Adjust the repetition cadence and pulse rate when the timer finishes."
                        ) {
                            Picker("", selection: $settings.timerAlertCadence) {
                                ForEach(TimerAlertCadence.allCases) { cadence in
                                    Text(cadence.rawValue).tag(cadence)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 250)
                        }
                    }
                }
            }
        }
    }
}

public struct SoundEventRow: View {
    public let title: String
    @Binding public var isOn: Bool
    public let onTest: () -> Void
    
    public var body: some View {
        HStack {
            Toggle(title, isOn: $isOn)
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            Button(action: onTest) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text("Test")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(NSColor.controlColor))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }
}

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

// MARK: - Tab 6: Shortcuts Settings Tab

public struct ShortcutsSettingsTab: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Gestures & Shortcuts")
                    .font(.system(size: 17, weight: .bold))
                Text("Quick reference for keyboard key bindings and notch mouse gestures.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            SettingsCard(
                title: "Keyboard Shortcuts",
                icon: "command",
                iconColor: .indigo,
                subtitle: "Global keyboard triggers available system-wide."
            ) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Toggle Dynamic Island", shortcut: "⌥ ⌘ I")
                    Divider()
                    ShortcutRow(title: "Collapse Island", shortcut: "⎋ Esc")
                    Divider()
                    ShortcutRow(title: "Lock Screen", shortcut: "⌃ ⌘ Q")
                }
            }
            
            SettingsCard(
                title: "Mouse & Drag Gestures",
                icon: "cursorarrow.rays",
                iconColor: .blue,
                subtitle: "Notch hover zones and file parking shortcuts."
            ) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Hover over Notch", shortcut: "Peek & Expand")
                    Divider()
                    ShortcutRow(title: "Click Compact Island", shortcut: "Open / Expand")
                    Divider()
                    ShortcutRow(title: "Drag Any File to Notch", shortcut: "Open Drop Shelf")
                    Divider()
                    ShortcutRow(title: "Click Pin Icon", shortcut: "Lock Island Open")
                }
            }
        }
    }
}

public struct ShortcutRow: View {
    public let title: String
    public let shortcut: String
    
    public var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            KeyCapView(text: shortcut)
        }
        .padding(.vertical, 2)
    }
}

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

// MARK: - Theme Card (visual tile for theme selection)

public struct ThemeCard: View {
    public let theme: IslandTheme
    public let isSelected: Bool
    public let onSelect: () -> Void

    private var previewGradient: LinearGradient {
        switch theme {
        case .liquidGlass:
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.12)],
                startPoint: .top, endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: [Color(white: 0.07), Color.black],
                startPoint: .top, endPoint: .bottom
            )
        case .light:
            return LinearGradient(
                colors: [Color(white: 0.96), Color(white: 0.88)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var previewAccent: Color {
        switch theme {
        case .liquidGlass: return Color.white.opacity(0.35)
        case .dark:        return Color.white.opacity(0.15)
        case .light:       return Color.black.opacity(0.20)
        }
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Mini island preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(previewGradient)
                        .frame(width: 88, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(previewAccent, lineWidth: 1)
                        )
                    // Mini "notch bar" indicator
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(previewAccent)
                        .frame(width: 40, height: 6)
                        .offset(y: -12)
                }

                Text(theme.rawValue)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color(NSColor.controlColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Closed Option Preview Card (Example Display)

public struct ClosedOptionPreviewCard: View {
    public let style: ClosedNotchStyle
    public let isSelected: Bool
    public let onSelect: () -> Void
    @State private var previewState: Int = 0 // 0: Idle, 1: Media, 2: Timer

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.system(size: 13))
                    
                    Text(style.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // State switcher to preview different live activity examples
                HStack(spacing: 2) {
                    ForEach([("Idle ", 0), ("Music ♫", 1), ("Timer ⏱", 2)], id: \.1) { label, idx in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                previewState = idx
                            }
                        } label: {
                            Text(label)
                                .font(.system(size: 9, weight: previewState == idx ? .bold : .medium))
                                .foregroundColor(previewState == idx ? .white : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(previewState == idx ? Color.accentColor : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color(NSColor.controlColor)))
            }

            Text("Apple-style balanced notch ears with battery, Apple logo, and dynamic live activities.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Visual Example Container
            ZStack(alignment: .top) {
                // Bezel / Screen edge
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.12))
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                // The Closed Notch & Ears
                HStack(spacing: 0) {
                    // Left Ear
                    Group {
                        if previewState == 0 {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.8))
                        } else if previewState == 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 9))
                                    .foregroundColor(.pink)
                            }
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                Text("14:59")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .frame(width: 58, height: 24, alignment: .trailing)
                    .padding(.trailing, 6)

                    // Hardware Notch Cutout
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 68, height: 24)
                        Circle()
                            .fill(Color(white: 0.22))
                            .frame(width: 6, height: 6)
                    }

                    // Right Ear
                    Group {
                        if previewState == 0 {
                            HStack(spacing: 3) {
                                Text("95%")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                Image(systemName: "battery.75")
                                    .font(.system(size: 8))
                                    .foregroundColor(.green)
                            }
                        } else if previewState == 1 {
                            HStack(spacing: 1.5) {
                                ForEach(0..<4) { i in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.pink)
                                        .frame(width: 2, height: CGFloat([9, 14, 7, 11][i]))
                                }
                            }
                        } else {
                            HStack(spacing: 3) {
                                Circle()
                                    .stroke(Color.orange, lineWidth: 1.5)
                                    .frame(width: 8, height: 8)
                                Text("Timer")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .frame(width: 58, height: 24, alignment: .leading)
                    .padding(.leading, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Opened Option Preview Card (Example Display)

public struct OpenedOptionPreviewCard: View {
    public let style: OpenedIslandStyle
    public let isSelected: Bool
    public let onSelect: () -> Void
    @State private var activePreviewTab: String = "Media"

    private var badgeText: String {
        switch style {
        case .defaultStyle:  return "Full Hub"
        case .bottomDeck:    return "Bottom Dock"
        case .compactHUD:    return "Compact Cockpit"
        case .floatingCards: return "Spatial Glass"
        case .commandCenter: return "Status Deck"
        }
    }

    private var styleDescription: String {
        switch style {
        case .defaultStyle:
            return "Full multi-tab workspace with persistent header HUD, fluid sliding tab bar, and tool views."
        case .bottomDeck:
            return "Inverted layout with floating dock pill navigation anchored at the bottom edge for intuitive downward mouse flow."
        case .compactHUD:
            return "Low-profile streamlined cockpit (~490pt) with unified segmented control, ideal for smaller displays."
        case .floatingCards:
            return "VisionOS-inspired spatial glass architecture with elevated floating tab chips and recessed content card."
        case .commandCenter:
            return "Information-dense layout with live contextual badges (timer countdowns, playback equalizer, item counts) on tabs."
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.system(size: 13))
                    
                    Text(style.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(badgeText)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
            }

            Text(styleDescription)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Visual Example Container
            previewBody
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch style {
        case .defaultStyle:
            fullHubPreview
        case .bottomDeck:
            bottomDeckPreview
        case .compactHUD:
            compactHUDPreview
        case .floatingCards:
            floatingCardsPreview
        case .commandCenter:
            commandCenterPreview
        }
    }

    // 1. Default (Full Hub) Preview
    private var fullHubPreview: some View {
        VStack(spacing: 5) {
            topHeaderPreview(title: "Dynamic Island", dotColor: nil)

            dividerPreview

            HStack(spacing: 3) {
                ForEach(["Media", "Shelf", "Timer", "Clip", "Notes"], id: \.self) { tabName in
                    let isActive = (activePreviewTab == tabName || (activePreviewTab == "Media" && tabName == "Media"))
                    Text(tabName)
                        .font(.system(size: 8, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.04)))
                        .onTapGesture { activePreviewTab = tabName }
                }
            }
            .padding(.horizontal, 10)

            dividerPreview

            miniContentPreview
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
    }

    // 3. Bottom Deck Preview
    private var bottomDeckPreview: some View {
        VStack(spacing: 5) {
            topHeaderPreview(title: "Dynamic Island", dotColor: nil)

            dividerPreview

            miniContentPreview
                .padding(.horizontal, 10)

            dividerPreview

            HStack(spacing: 3) {
                ForEach(["Media", "Shelf", "Timer", "Clip", "Notes"], id: \.self) { tabName in
                    let isActive = (activePreviewTab == tabName || (activePreviewTab == "Media" && tabName == "Media"))
                    Text(tabName)
                        .font(.system(size: 8, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.04)))
                        .onTapGesture { activePreviewTab = tabName }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // 4. Compact HUD Preview
    private var compactHUDPreview: some View {
        VStack(spacing: 4) {
            topHeaderPreview(title: "Dynamic", dotColor: nil)

            dividerPreview

            HStack(spacing: 1) {
                ForEach(["Media", "Shelf", "Timer", "Clip", "Notes"], id: \.self) { tabName in
                    let isActive = (activePreviewTab == tabName || (activePreviewTab == "Media" && tabName == "Media"))
                    Text(tabName)
                        .font(.system(size: 7, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity)
                        .background(isActive ? Capsule().fill(Color.white.opacity(0.25)) : nil)
                        .onTapGesture { activePreviewTab = tabName }
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 16)

            dividerPreview

            miniContentPreview
                .padding(.horizontal, 12)
                .padding(.bottom, 5)
        }
    }

    // 5. Floating Cards Preview
    private var floatingCardsPreview: some View {
        VStack(spacing: 5) {
            topHeaderPreview(title: "Dynamic Island", dotColor: .cyan)

            HStack(spacing: 4) {
                ForEach(["Media", "Shelf", "Timer", "Clip", "Notes"], id: \.self) { tabName in
                    let isActive = (activePreviewTab == tabName || (activePreviewTab == "Media" && tabName == "Media"))
                    Text(tabName)
                        .font(.system(size: 7, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                        .onTapGesture { activePreviewTab = tabName }
                }
            }
            .padding(.horizontal, 10)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )

                miniContentPreview
                    .padding(4)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    // 6. Command Center Preview
    private var commandCenterPreview: some View {
        VStack(spacing: 5) {
            topHeaderPreview(title: "Dynamic Hub", dotColor: .green)

            dividerPreview

            HStack(spacing: 3) {
                tabWithBadge(title: "Media", badge: "ılı", color: .green)
                tabWithBadge(title: "Shelf", badge: "2", color: .cyan)
                tabWithBadge(title: "Timer", badge: "04m", color: .orange)
                tabWithBadge(title: "Clip", badge: "5", color: .purple)
                tabWithBadge(title: "Notes", badge: "•", color: .yellow)
            }
            .padding(.horizontal, 8)

            dividerPreview

            miniContentPreview
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
    }

    private func tabWithBadge(title: String, badge: String, color: Color) -> some View {
        let isActive = (activePreviewTab == title || (activePreviewTab == "Media" && title == "Media"))
        return HStack(spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: isActive ? .bold : .regular))
            Text(badge)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .foregroundColor(isActive ? .white : .white.opacity(0.5))
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.04)))
        .onTapGesture { activePreviewTab = title }
    }

    private func topHeaderPreview(title: String, dotColor: Color?) -> some View {
        HStack {
            HStack(spacing: 3) {
                if let dotColor = dotColor {
                    Circle().fill(dotColor).frame(width: 4, height: 4)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.6))
                }
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black)
                .frame(width: 44, height: 9)
                .overlay(Circle().fill(Color(white: 0.25)).frame(width: 3.5, height: 3.5))

            Spacer()

            HStack(spacing: 4) {
                Text("CPU 12%")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.green)
                Text("RAM 8.4G")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.purple)
                Image(systemName: "pin.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var dividerPreview: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 10)
    }

    private var miniContentPreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(activePreviewTab == "Media" ? "Starboy" : activePreviewTab)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                Text(activePreviewTab == "Media" ? "The Weeknd • Daft Punk" : "Interactive Tool Viewport")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "backward.fill").font(.system(size: 7)).foregroundColor(.white.opacity(0.7))
                Image(systemName: "play.circle.fill").font(.system(size: 14)).foregroundColor(.pink)
                Image(systemName: "forward.fill").font(.system(size: 7)).foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
