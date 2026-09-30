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
            return 600.0
        } else {
            if isNotchMode {
                return notchWidth + compactLeftEarWidth + compactRightEarWidth + 16.0 + CGFloat(settings.customWidthOffset)
            } else {
                let base: CGFloat = (mediaManager.currentTrack.isPlaying || timerManager.isTimerRunning) ? 230.0 : 185.0
                return base + CGFloat(settings.customWidthOffset)
            }
        }
    }
    
    // Dynamic height calculation (strictly anchored to top, perfectly stable across all tabs)
    private var islandHeight: CGFloat {
        if appState.isExpanded {
            let contentH: CGFloat = 165.0
            return notchTopInset + 38.0 + contentH + 16.0
        } else {
            return isNotchMode ? max(34.0, detector.currentNotch.notchHeight) : 34.0
        }
    }
    
    private var cornerRadius: CGFloat {
        appState.isExpanded ? 26.0 : (isNotchMode ? 14.0 : 17.0)
    }

    /// Top corners are always 0 in notch mode so the island is flush against
    /// the screen edge — no crescent-shaped gap for the mouse to slip through.
    private var topCornerRadius: CGFloat {
        isNotchMode ? 0 : cornerRadius
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main Island Body: ZStack strictly aligned to top
            ZStack(alignment: .top) {
                // ── Liquid Glass background ──────────────────────────────
                if appState.isExpanded {
                    // Frosted material layer (AppKit NSVisualEffectView)
                    LiquidGlassBackground(cornerRadius: cornerRadius, topCornerRadius: topCornerRadius)
                        .opacity(0.92)

                    // Dark tint to deepen contrast on the glass
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.52))

                    // Subtle gradient sheen — light at top, transparent at bottom
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.06),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Specular rim (bright top edge)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(appState.isHovering ? 0.38 : 0.22), location: 0.0),
                                    .init(color: Color.white.opacity(0.08), location: 0.35),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .shadow(color: Color.white.opacity(0.08), radius: 2, x: 0, y: -1)

                } else {
                    // Compact — plain opaque black pill
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(
                                    appState.isHovering
                                        ? Color.white.opacity(0.22)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                }

                // Drop shadow
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(appState.isExpanded ? 0.7 : 0.3),
                        radius: appState.isExpanded ? 28 : 8,
                        x: 0,
                        y: appState.isExpanded ? 14 : 3
                    )
                
                // Content View (Compact vs Expanded)
                Group {
                    if appState.isExpanded {
                        ExpandedIslandView()
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    } else {
                        CompactIslandView()
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                    }
                }
            }
            .frame(width: islandWidth, height: islandHeight, alignment: .top)
            // CLIP SHAPE: flat top in notch mode → no gap between island and screen edge
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topCornerRadius,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: topCornerRadius,
                    style: .continuous
                )
            )
            // Drop shelf glow when a drag is hovering over the island
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: topCornerRadius,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: topCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isTargetedForDrop ? Color.blue.opacity(0.8) : Color.clear,
                    lineWidth: isTargetedForDrop ? 2 : 0
                )
                .shadow(
                    color: isTargetedForDrop ? Color.blue.opacity(0.5) : .clear,
                    radius: 12
                )
                .animation(.easeInOut(duration: 0.15), value: isTargetedForDrop)
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0), value: appState.isExpanded)
            .animation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0), value: appState.activeTab)
            .onHover { hovering in
                if hovering {
                    appState.handleMouseEnter()
                } else {
                    appState.handleMouseLeave()
                }
            }
            // Accept any file being dragged — expand to Drop Shelf immediately on enter
            .onDrop(of: [.fileURL, .item], isTargeted: $isTargetedForDrop) { providers in
                // Expand to Drop Shelf immediately
                appState.expand(tab: .dropShelf)
                // Collect all dropped URLs
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
            // As soon as a drag enters the compact island, open Drop Shelf immediately
            .onChange(of: isTargetedForDrop) { _, targeted in
                if targeted {
                    appState.expand(tab: .dropShelf)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
