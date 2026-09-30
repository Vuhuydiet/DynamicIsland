import SwiftUI

public struct ExpandedIslandView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared
    
    private var isNotchMode: Bool {
        switch settings.notchStyle {
        case .auto: return detector.currentNotch.hasPhysicalNotch
        case .notch: return true
        case .floating: return false
        }
    }
    
    private var notchRowHeight: CGFloat {
        if isNotchMode {
            return max(34.0, detector.currentNotch.notchHeight)
        } else {
            return 8.0
        }
    }
    
    private var notchWidth: CGFloat {
        max(170.0, detector.currentNotch.notchWidth)
    }
    
    private var earWidth: CGFloat {
        max(0, (500.0 - notchWidth) / 2.0)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Row 1: Notch Area (Left & Right Ears around the physical hardware notch)
            if isNotchMode {
                HStack(spacing: 0) {
                    // Left Ear: Brand / Status (strictly to the left of the notch)
                    HStack(spacing: 5) {
                        Image(systemName: "apple.logo")
                            .font(IslandFont.iconSmall)
                            .foregroundColor(.white.opacity(0.45))
                        Text("Dynamic Island")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.leading, 12)
                    .frame(width: earWidth, alignment: .leading)
                    
                    // Center Cutout: Strictly matching the hardware notch dimensions
                    Color.clear
                        .frame(width: notchWidth, height: notchRowHeight)
                    
                    // Right Ear: Actions (Settings Window, Pin, Collapse)
                    HStack(spacing: 6) {
                        Button(action: {
                            SoundManager.shared.play(.click)
                            SettingsWindowController.shared.show()
                        }) {
                            Image(systemName: "gearshape")
                                .font(IslandFont.iconRegular)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings Window")
                        
                        Button(action: {
                            SoundManager.shared.play(.click)
                            appState.isPinned.toggle()
                        }) {
                            Image(systemName: appState.isPinned ? "pin.fill" : "pin")
                                .font(IslandFont.iconRegular)
                                .foregroundColor(appState.isPinned ? .orange : .white.opacity(0.65))
                                .padding(5)
                                .background(appState.isPinned ? Color.orange.opacity(0.2) : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(appState.isPinned ? "Unpin Island" : "Pin Island Open")
                        
                        Button(action: {
                            appState.collapse(force: true)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(IslandFont.iconSmall)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Collapse")
                    }
                    .padding(.trailing, 12)
                    .frame(width: earWidth, alignment: .trailing)
                }
                .frame(width: 500, height: notchRowHeight)
            } else {
                // Floating Mode Header
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "apple.logo")
                            .font(IslandFont.iconSmall)
                            .foregroundColor(.white.opacity(0.45))
                        Text("Dynamic Island")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.leading, 14)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Button(action: {
                            SoundManager.shared.play(.click)
                            SettingsWindowController.shared.show()
                        }) {
                            Image(systemName: "gearshape")
                                .font(IslandFont.iconRegular)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            SoundManager.shared.play(.click)
                            appState.isPinned.toggle()
                        }) {
                            Image(systemName: appState.isPinned ? "pin.fill" : "pin")
                                .font(IslandFont.iconRegular)
                                .foregroundColor(appState.isPinned ? .orange : .white.opacity(0.65))
                                .padding(5)
                                .background(appState.isPinned ? Color.orange.opacity(0.2) : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            appState.collapse(force: true)
                        }) {
                            Image(systemName: "chevron.up")
                                .font(IslandFont.iconSmall)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 14)
                }
                .frame(height: 28)
                .padding(.top, 4)
            }
            
            // MARK: - PART 1 (TOP): Condensed System HUD (CPU, Memory, Battery, Disk)
            CondensedSystemHUDView()
                .padding(.top, 4)
                .padding(.bottom, 6)
            
            // Subtle Section Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            
            // MARK: - PART 2 (BOTTOM): Tab Bar (Media, Drop Shelf, Timer, Clipboard, Notes)
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases) { tab in
                    Button(action: {
                        SoundManager.shared.play(.click)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            appState.activeTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(IslandFont.iconSmall)
                            
                            if appState.activeTab == tab {
                                Text(tab.rawValue)
                                    .font(IslandFont.caption)
                            }
                        }
                        .foregroundColor(appState.activeTab == tab ? .white : .white.opacity(0.55))
                        .padding(.horizontal, appState.activeTab == tab ? 12 : 9)
                        .padding(.vertical, 6)
                        .background(
                            appState.activeTab == tab ?
                                Color.white.opacity(0.22) :
                                Color.white.opacity(0.06)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            
            // Subtle Content Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            
            // MARK: - Tab Content Router
            ZStack {
                switch appState.activeTab {
                case .media:
                    MediaView()
                case .dropShelf:
                    DropShelfView()
                case .timer:
                    TimerView()
                case .clipboard:
                    ClipboardView()
                case .notes:
                    NotesView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .padding(.bottom, 6)
        }
    }
}
