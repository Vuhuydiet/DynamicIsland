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
    
    private var expandedWidth: CGFloat {
        600.0
    }
    
    private var earWidth: CGFloat {
        max(0, (expandedWidth - notchWidth) / 2.0)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Row 1: Notch Area (Left & Right Ears around the physical hardware notch)
            if isNotchMode {
                HStack(spacing: 0) {
                    // Left Ear: Brand / Title
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
                    
                    // Right Ear: System Stats & Pin Button
                    HStack(spacing: 6) {
                        CondensedSystemHUDView()
                        
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
                    }
                    .padding(.trailing, 10)
                    .frame(width: earWidth, alignment: .trailing)
                }
                .frame(width: expandedWidth, height: notchRowHeight)
            } else {
                // Floating Mode Header
                HStack {
                    // Left: Brand / Title
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
                    
                    // Right: System Stats & Pin Button
                    HStack(spacing: 6) {
                        CondensedSystemHUDView()
                        
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
                    }
                    .padding(.trailing, 12)
                }
                .frame(height: 32)
                .padding(.top, 4)
            }
            
            // Subtle Header Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.top, 4)
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
            ZStack(alignment: .top) {
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
            .frame(height: 165, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            .padding(.bottom, 6)
        }
    }
}
