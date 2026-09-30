import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var detector = NotchDetector.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .font(IslandFont.iconRegular)
                    Text("Settings")
                        .font(IslandFont.title)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    SoundManager.shared.play(.click)
                    SettingsWindowController.shared.show()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow.badge.plus")
                            .font(IslandFont.iconSmall)
                        Text("Settings Window...")
                            .font(IslandFont.caption)
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Open Full Settings Window")
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            
            // Island Mode Row
            HStack {
                Text("Mode")
                    .font(IslandFont.subtitle)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Picker("", selection: $settings.notchStyle) {
                    ForEach(NotchStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(.horizontal, 14)
            
            // Sound Settings Box
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: settings.soundEffectsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(IslandFont.iconSmall)
                            .foregroundColor(settings.soundEffectsEnabled ? .green : .gray)
                        Text("Sound")
                            .font(IslandFont.subtitle)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Toggle("", isOn: $settings.soundEffectsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .scaleEffect(0.75)
                    
                    Spacer()
                    
                    if settings.soundEffectsEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.fill")
                                .font(IslandFont.iconMicro)
                                .foregroundColor(.white.opacity(0.4))
                            Slider(value: $settings.soundVolume, in: 0.1...1.0)
                                .frame(width: 65)
                            Text(String(format: "%.0f%%", settings.soundVolume * 100))
                                .font(IslandFont.timeNumeric)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 26, alignment: .trailing)
                        }
                        
                        Button("Test") {
                            SoundManager.shared.play(.expand)
                        }
                        .font(IslandFont.micro)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                
                if settings.soundEffectsEnabled {
                    HStack {
                        Text("Theme")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Picker("", selection: $settings.soundScheme) {
                            ForEach(SoundScheme.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 14)
            
            // Bottom Row: Menu Bar & Quit
            HStack(spacing: 12) {
                Toggle("Show in Menu Bar", isOn: $settings.showMenuBarIcon)
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .font(IslandFont.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button("Quit Dynamic Island") {
                    NSApplication.shared.terminate(nil)
                }
                .font(IslandFont.caption)
                .foregroundColor(.red.opacity(0.9))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 6)
    }
}
