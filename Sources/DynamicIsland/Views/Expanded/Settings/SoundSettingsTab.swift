import SwiftUI

// MARK: - Pane 4: Sound effects (global + per-plugin)

// MARK: - Tab 4: Sound Settings Tab

public struct SoundSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var pluginManager = PluginManager.shared
    
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
            
            // Per-Plugin Audio Card — generated from the plugin registry so that any
            // plugin (present or future) is configurable with sound automatically.
            if settings.soundEffectsEnabled && !pluginManager.plugins.isEmpty {
                SettingsCard(
                    title: "Plugin Sounds",
                    icon: "puzzlepiece.extension.fill",
                    iconColor: .cyan,
                    subtitle: "Each plugin has its own audio profile. Mute a plugin or change the cues it plays for alerts and interactions."
                ) {
                    VStack(spacing: 10) {
                        ForEach(pluginManager.plugins, id: \.id) { plugin in
                            PluginSoundSettingsRow(
                                pluginID: plugin.id,
                                pluginName: plugin.name,
                                pluginIcon: plugin.icon,
                                defaultProfile: plugin.defaultSoundProfile
                            )
                            
                            if plugin.id != pluginManager.plugins.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Audio controls for a single plugin, derived entirely from
/// `IslandPluginSoundEvent.allCases` so it works for any plugin.
public struct PluginSoundSettingsRow: View {
    @ObservedObject private var settings = SettingsManager.shared
    public let pluginID: String
    public let pluginName: String
    public let pluginIcon: String
    public let defaultProfile: IslandPluginSoundProfile

    public var body: some View {
        let profile = settings.soundProfile(forPlugin: pluginID)
        let isOverridden = settings.pluginSoundOverrides[pluginID] != nil

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: pluginIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                    .frame(width: 16)

                Text(pluginName)
                    .font(.system(size: 12.5, weight: .semibold))
                
                Spacer()
                
                if isOverridden {
                    Button("Reset") {
                        settings.resetPluginSound(pluginID)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .help("Restore this plugin's default audio profile")
                }
                
                Toggle("", isOn: Binding(
                    get: { profile.isEnabled },
                    set: { newValue in
                        settings.updatePluginSound(pluginID) { $0.isEnabled = newValue }
                    }
                ))
                .labelsHidden()
            }
            
            if profile.isEnabled {
                HStack(spacing: 10) {
                    Text("Volume:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { profile.volume },
                            set: { newValue in
                                settings.updatePluginSound(pluginID) { $0.volume = newValue }
                            }
                        ),
                        in: 0.0...1.0,
                        step: 0.05
                    )
                    .frame(maxWidth: 160)
                    
                    Text(String(format: "%.0f%%", profile.volume * 100))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.leading, 24)
                
                VStack(spacing: 5) {
                    ForEach(IslandPluginSoundEvent.allCases, id: \.self) { event in
                        HStack(spacing: 8) {
                            Text(event.displayName)
                                .font(.system(size: 11.5, weight: .medium))
                                .frame(width: 108, alignment: .leading)
                            
                            Picker("", selection: Binding(
                                get: { profile.cue(for: event) },
                                set: { newValue in
                                    settings.updatePluginSound(pluginID) { $0.setCue(newValue, for: event) }
                                }
                            )) {
                                ForEach(IslandSoundCue.allCases, id: \.self) { cue in
                                    Text(cue.displayName).tag(cue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            
                            Button {
                                SoundManager.shared.playPluginCue(event, pluginId: pluginID)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 7.5))
                                    Text("Test")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color(NSColor.controlColor))
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
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

