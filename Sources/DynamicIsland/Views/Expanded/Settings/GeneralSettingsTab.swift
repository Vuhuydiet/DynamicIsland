import SwiftUI

// MARK: - Pane 1 continued: shared visual cards for theme + closed-notch selection
//
// `ThemeCard` and `ClosedOptionPreviewCard` are only rendered by
// `GeneralSettingsTab`, so they live with it rather than in a shared bucket.

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

import SwiftUI

// MARK: - Opened Option Preview Card (Example Display)

/// Preview card for an opened-island shell.
///
/// The style set is driven entirely by `OpenedIslandStyle.allCases`, so a shell
/// added later shows up here with no change to this view. Shell-specific artwork
/// is therefore expressed as a property on the style itself rather than as a
/// branch here, keeping this card incapable of forgetting a case.
public struct OpenedOptionPreviewCard: View {
    public let style: OpenedIslandStyle
    public let isSelected: Bool
    public let onSelect: () -> Void
    @State private var activePreviewTab: IslandTab = .media

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

                Text(style.badgeText)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
            }

            Text(style.styleDescription)
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
        }
    }

    /// Default (Full Hub) preview: header HUD, sliding tab bar, content viewport.
    private var fullHubPreview: some View {
        VStack(spacing: 5) {
            topHeaderPreview

            dividerPreview

            HStack(spacing: 3) {
                ForEach(IslandTab.allCases) { tab in
                    let isActive = tab == activePreviewTab
                    Text(tab.rawValue)
                        .font(.system(size: 8, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.04)))
                        .onTapGesture { activePreviewTab = tab }
                }
            }
            .padding(.horizontal, 10)

            dividerPreview

            miniContentPreview
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
    }

    private var topHeaderPreview: some View {
        HStack {
            HStack(spacing: 3) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
                Text("Dynamic Island")
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
                Text(activePreviewTab == .media ? "Starboy" : activePreviewTab.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                Text(activePreviewTab == .media ? "The Weeknd • Daft Punk" : "Interactive Tool Viewport")
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

// MARK: - Pane 1: General (appearance, closed notch, menu bar, launch at login)

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

                    // Opened Island Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opened Island UI")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("Expanded Workspace")
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

