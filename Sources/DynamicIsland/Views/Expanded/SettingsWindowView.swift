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
        .frame(width: 640, height: 480)
    }
}

// MARK: - General Settings Tab
public struct GeneralSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Preferences")
                .font(.system(size: 16, weight: .bold))
            
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
                            Text(String(format: "%.0f ms", settings.hoverDelay * 1000))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.hoverDelay, in: 0.05...0.60, step: 0.01)
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
                    Text("Provides a persistent icon in your menu bar to quickly toggle the island or switch tabs.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
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
