import SwiftUI

public struct IslandContainerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var dropManager = DropShelfManager.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    
    @State private var isTargetedForDrop = false
    
    private var isNotchMode: Bool {
        switch settings.notchStyle {
        case .auto: return detector.currentNotch.hasPhysicalNotch
        case .notch: return true
        case .floating: return false
        }
    }
    
    private var notchTopInset: CGFloat {
        if isNotchMode {
            return max(34.0, detector.currentNotch.notchHeight)
        } else {
            return 8.0
        }
    }
    
    private var notchWidth: CGFloat {
        max(170.0, detector.currentNotch.notchWidth)
    }
    
    private var compactLeftEarWidth: CGFloat {
        (mediaManager.currentTrack.isPlaying || timerManager.isTimerRunning) ? 80.0 : 50.0
    }
    
    private var compactRightEarWidth: CGFloat {
        mediaManager.currentTrack.isPlaying ? 44.0 : 50.0
    }
    
    // Dynamic width calculation
    private var islandWidth: CGFloat {
        if appState.isExpanded {
            return 580.0
        } else {
            if isNotchMode {
                return notchWidth + compactLeftEarWidth + compactRightEarWidth + 16.0 + CGFloat(settings.customWidthOffset)
            } else {
                let base: CGFloat = (mediaManager.currentTrack.isPlaying || timerManager.isTimerRunning) ? 230.0 : 185.0
                return base + CGFloat(settings.customWidthOffset)
            }
        }
    }
    
    // Dynamic height calculation (with generous padding so content NEVER overflows)
    private var islandHeight: CGFloat {
        if appState.isExpanded {
            let contentH: CGFloat
            switch appState.activeTab {
            case .media: contentH = 165.0
            case .dropShelf: contentH = 155.0
            case .timer: contentH = 165.0
            case .clipboard: contentH = 160.0
            case .notes: contentH = 155.0
            }
            return notchTopInset + 38.0 + contentH + 16.0
        } else {
            return isNotchMode ? max(34.0, detector.currentNotch.notchHeight) : 34.0
        }
    }
    
    private var cornerRadius: CGFloat {
        appState.isExpanded ? 26.0 : (isNotchMode ? 14.0 : 17.0)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main Island Body: ZStack strictly aligned to top
            ZStack(alignment: .top) {
                // Background & Outer Glow
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                appState.isHovering ? Color.white.opacity(0.22) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(appState.isExpanded ? 0.6 : 0.25),
                        radius: appState.isExpanded ? 24 : 8,
                        x: 0,
                        y: appState.isExpanded ? 12 : 3
                    )
                
                // Content View (Compact vs Expanded)
                Group {
                    if appState.isExpanded {
                        ExpandedIslandView()
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        CompactIslandView()
                            .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    }
                }
            }
            .frame(width: islandWidth, height: islandHeight)
            // CLIP SHAPE: Strictly guarantees that zero pixels ever overflow outside the capsule!
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0), value: appState.isExpanded)
            .animation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0), value: appState.activeTab)
            .onHover { hovering in
                if hovering {
                    appState.handleMouseEnter()
                } else {
                    appState.handleMouseLeave()
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                appState.expand(tab: .dropShelf)
                var urls: [URL] = []
                let group = DispatchGroup()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url { urls.append(url) }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    if !urls.isEmpty {
                        dropManager.addItems(urls: urls)
                    }
                }
                return true
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
