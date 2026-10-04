import SwiftUI

// MARK: - Settings window shell, pane registry, and shared row primitives

import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case animations = "Animations"
    case behavior = "Behavior & Tabs"
    case plugins = "Plugins"
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
        case .plugins: return "puzzlepiece.extension.fill"
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
        case .plugins: return .cyan
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
                        case .plugins:
                            PluginsSettingsTab()
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

