import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case sound = "Sound Effects"
    case geometry = "Geometry & Notch"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .sound: return "speaker.wave.3.fill"
        case .geometry: return "macbook.and.iphone"
        case .shortcuts: return "command"
        case .about: return "info.circle.fill"
        }
    }
}

public struct SettingsWindowView: View {
    @State private var activeTab: SettingsTab = .general
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Sidebar Navigation
            VStack(alignment: .leading, spacing: 6) {
                // Sidebar Header
                HStack(spacing: 8) {
                    Image(systemName: "capsule.portrait.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.pink)
                    Text("Dynamic Island")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Sidebar Items
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        activeTab = tab
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .frame(width: 18)
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                            Spacer()
                        }
                        .foregroundColor(activeTab == tab ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            activeTab == tab ?
                                Color.accentColor :
                                Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
            }
            .frame(width: 180)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // MARK: - Right Content Area
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch activeTab {
                        case .general:
                            GeneralSettingsTab()
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
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 660, minHeight: 560)
    }
}

// MARK: - General Settings Tab
public struct GeneralSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Preferences")
                .font(.system(size: 16, weight: .bold))

            // ── Appearance Theme ──────────────────────────────────────────
            GroupBox(label: Label("Appearance Theme", systemImage: "paintpalette.fill").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(IslandTheme.allCases) { theme in
                            ThemeCard(theme: theme, isSelected: settings.islandTheme == theme) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.islandTheme = theme
                                }
                            }
                        }
                    }
                    Text("Liquid Glass uses the system blur material. Dark is solid near-black. Light uses a bright frosted surface.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // ── UI Styles (Versions) ──────────────────────────────────────
            GroupBox(label: Label("Island UI Versions", systemImage: "paintbrush.fill").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 14) {
                    // Closed Notch Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Closed Notch UI")
                            .font(.system(size: 12, weight: .semibold))

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
                        Text("Opened Island UI")
                            .font(.system(size: 12, weight: .semibold))

                        ForEach(OpenedIslandStyle.allCases) { style in
                            OpenedOptionPreviewCard(style: style, isSelected: settings.openedIslandStyle == style) {
                                withAnimation(IslandSpring.bouncy) {
                                    settings.openedIslandStyle = style
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }

            // ── Tab Visibility ────────────────────────────────────────────
            GroupBox(label: Label("Visible Tabs", systemImage: "rectangle.3.group.fill").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(IslandTab.allCases.enumerated()), id: \.element.id) { idx, tab in
                        if idx > 0 { Divider() }
                        HStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .frame(width: 20)
                                .foregroundColor(.accentColor)
                            Text(tab.rawValue)
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { settings.isTabVisible(tab) },
                                set: { visible in
                                    if visible {
                                        settings.hiddenTabs.remove(tab.rawValue)
                                    } else {
                                        // Keep at least one tab visible
                                        let remaining = IslandTab.allCases.filter { settings.isTabVisible($0) }
                                        if remaining.count > 1 {
                                            settings.hiddenTabs.insert(tab.rawValue)
                                        }
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            // Island Mode Group
            GroupBox(label: Label("Island Behavior & Mode", systemImage: "macbook").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Island Mode:", selection: $settings.notchStyle) {
                        ForEach(NotchStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Auto Detect anchors to the physical MacBook notch on the built-in screen and displays as a floating pill on external displays.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Divider()

                    Picker("Trigger Expansion:", selection: $settings.expandTrigger) {
                        ForEach(ExpandTrigger.allCases) { trig in
                            Text(trig.rawValue).tag(trig)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hover Delay:")
                                .font(.system(size: 12))
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
                .padding(8)
            }

            // Startup & Login Group
            GroupBox(label: Label("Startup & Login", systemImage: "power").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch Dynamic Island at Login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    .font(.system(size: 12))

                    Text("Automatically opens Dynamic Island when your Mac boots or you log in.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // Menu Bar Group
            GroupBox(label: Label("Menu Bar Item", systemImage: "menubar.rectangle").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show Dynamic Island Icon in Menu Bar", isOn: $settings.showMenuBarIcon)
                        .font(.system(size: 12))
                    Text("Displays a persistent capsule icon in macOS menu bar for accessing Preferences, Launch at Login, and Quit.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
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
            VStack(spacing: 6) {
                // Mini island preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(previewGradient)
                        .frame(width: 80, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(previewAccent, lineWidth: 1)
                        )
                    // Mini "notch bar" indicator
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(previewAccent)
                        .frame(width: 36, height: 6)
                        .offset(y: -11)
                }

                Text(theme.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlColor))
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

// MARK: - Sound Settings Tab
public struct SoundSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sound Preferences")
                .font(.system(size: 16, weight: .bold))
            
            // Master Sound Toggle & Volume Card
            GroupBox(label: Label("Master Audio Settings", systemImage: "speaker.wave.2.fill").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Sound Effects", isOn: $settings.soundEffectsEnabled)
                        .font(.system(size: 13, weight: .semibold))
                    
                    if settings.soundEffectsEnabled {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Effects Volume:")
                                    .font(.system(size: 12))
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
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sound Theme Scheme:")
                                .font(.system(size: 12))
                            
                            Picker("", selection: $settings.soundScheme) {
                                ForEach(SoundScheme.allCases) { scheme in
                                    Text(scheme.rawValue).tag(scheme)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(8)
            }
            
            // Per-Event Sounds & Audition Test Card
            if settings.soundEffectsEnabled {
                GroupBox(label: Label("Event Audio & Test", systemImage: "music.note.list").font(.system(size: 12, weight: .semibold))) {
                    VStack(spacing: 10) {
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
                            onTest: { SoundManager.shared.play(.timerAlert) }
                        )
                    }
                    .padding(8)
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
                .font(.system(size: 12))
            Spacer()
            Button("Test Sound") {
                onTest()
            }
            .font(.system(size: 11))
        }
    }
}

// MARK: - Geometry Settings Tab
public struct GeometrySettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var detector = NotchDetector.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Geometry & Alignment")
                .font(.system(size: 16, weight: .bold))
            
            // Hardware Detection Card
            GroupBox(label: Label("Display & Hardware Notch", systemImage: "display").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hardware Notch:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(detector.currentNotch.hasPhysicalNotch ? "Detected (MacBook Pro)" : "None (Floating Mode)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(detector.currentNotch.hasPhysicalNotch ? .green : .blue)
                    }
                    
                    HStack {
                        Text("Measured Notch Width:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.1f pt", detector.currentNotch.notchWidth))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Measured Notch Height:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.1f pt", detector.currentNotch.notchHeight))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Screen Resolution:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(detector.currentNotch.screenFrame.width)) × \(Int(detector.currentNotch.screenFrame.height)) pt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            
            // Sliders for Fine-Tuning
            GroupBox(label: Label("Position Fine-Tuning", systemImage: "slider.horizontal.3").font(.system(size: 12, weight: .semibold))) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Width Offset:")
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%+.0f pt", settings.customWidthOffset))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        Slider(value: $settings.customWidthOffset, in: -50...100, step: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Y-Axis Offset:")
                                .font(.system(size: 12))
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
                .padding(8)
            }
        }
    }
}

// MARK: - Shortcuts Settings Tab
public struct ShortcutsSettingsTab: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gestures & Shortcuts")
                .font(.system(size: 16, weight: .bold))
            
            GroupBox(label: Label("Keyboard Shortcuts", systemImage: "command").font(.system(size: 12, weight: .semibold))) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Toggle Dynamic Island", shortcut: "⌥ ⌘ I")
                    Divider()
                    ShortcutRow(title: "Collapse Island", shortcut: "Esc")
                    Divider()
                    ShortcutRow(title: "Lock Screen", shortcut: "⌃ ⌘ Q")
                }
                .padding(8)
            }
            
            GroupBox(label: Label("Mouse & Drag Gestures", systemImage: "cursorarrow.rays").font(.system(size: 12, weight: .semibold))) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Hover over Notch", shortcut: "Peek & Expand")
                    Divider()
                    ShortcutRow(title: "Click Compact Island", shortcut: "Open / Expand")
                    Divider()
                    ShortcutRow(title: "Drag Any File to Notch", shortcut: "Open Drop Shelf")
                    Divider()
                    ShortcutRow(title: "Click Pin Icon", shortcut: "Lock Island Open")
                }
                .padding(8)
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
                .font(.system(size: 12))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - About Settings Tab
public struct AboutSettingsTab: View {
    public var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer(minLength: 10)
            
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                    .shadow(radius: 8)
                
                Image(systemName: "capsule.portrait.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            VStack(spacing: 4) {
                Text("Dynamic Island")
                    .font(.system(size: 18, weight: .bold))
                Text("Version 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text("Designed natively for MacBook Pro & MacBook Air in Swift & SwiftUI.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 320)
            
            Divider()
                .frame(width: 280)
            
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

                Text("Full Hub")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
            }

            Text("Full multi-tab workspace with persistent header HUD, fluid sliding tab bar, and tool views.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Visual Example Container
            VStack(spacing: 5) {
                // Top Header Example
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

                    // Center camera notch indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black)
                        .frame(width: 48, height: 10)
                        .overlay(Circle().fill(Color(white: 0.25)).frame(width: 4, height: 4))

                    Spacer()

                    // Condensed stats + pin
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

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)

                // Tab Bar Example
                HStack(spacing: 3) {
                    ForEach(["Media", "Drop Shelf", "Timer", "Clipboard", "Notes"], id: \.self) { tabName in
                        let isActive = (activePreviewTab == tabName)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                activePreviewTab = tabName
                            }
                        } label: {
                            Text(tabName)
                                .font(.system(size: 8, weight: isActive ? .bold : .regular))
                                .foregroundColor(isActive ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule()
                                        .fill(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)

                // Content View Example
                HStack(spacing: 8) {
                    // Mini artwork
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activePreviewTab == "Media" ? "Starboy" : activePreviewTab)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Text(activePreviewTab == "Media" ? "The Weeknd • Daft Punk" : "Interactive Tool Active")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    // Playback controls preview
                    HStack(spacing: 6) {
                        Image(systemName: "backward.fill").font(.system(size: 8)).foregroundColor(.white.opacity(0.7))
                        Image(systemName: "play.circle.fill").font(.system(size: 16)).foregroundColor(.pink)
                        Image(systemName: "forward.fill").font(.system(size: 8)).foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
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
}

