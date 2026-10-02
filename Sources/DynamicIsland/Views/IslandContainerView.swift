import SwiftUI

public struct IslandContainerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var detector = NotchDetector.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var dropManager = DropShelfManager.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    
    @State private var isTopHoveringDrag = false
    @State private var isTrayDropTargeted = false
    @State private var dragExitWorkItem: DispatchWorkItem? = nil
    
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
    
    private var compactEarWidth: CGFloat {
        appState.compactEarWidth
    }
    
    // Dynamic width calculation
    private var islandWidth: CGFloat {
        if appState.isExpanded {
            return appState.expandedWidth
        } else {
            return appState.compactIslandWidth
        }
    }

    /// The visible body width between the straight vertical side edges,
    /// excluding the top corner flares that expand outward into the screen bezel.
    private var islandBodyWidth: CGFloat {
        if isNotchMode {
            return max(240.0, islandWidth - (currentFlareWidth * 2.0))
        } else {
            return islandWidth
        }
    }
    
    // Dynamic height calculation (strictly anchored to top, perfectly stable across all tabs)
    private var islandHeight: CGFloat {
        if appState.isExpanded {
            return appState.expandedHeight(isNotchMode: isNotchMode, notchHeight: detector.currentNotch.notchHeight)
        } else {
            return isNotchMode ? max(34.0, detector.currentNotch.notchHeight) : 34.0
        }
    }
    
    private var currentFlareWidth: CGFloat {
        if isNotchMode {
            return appState.isExpanded ? NotchIslandShape.expandedFlareWidth : NotchIslandShape.compactFlareWidth
        }
        return 0
    }
    
    private var currentFlareHeight: CGFloat {
        if isNotchMode {
            return appState.isExpanded ? NotchIslandShape.expandedFlareHeight : NotchIslandShape.compactFlareHeight
        }
        return 0
    }
    
    private var cornerRadius: CGFloat {
        appState.isExpanded ? 32.0 : (isNotchMode ? 14.0 : 17.0)
    }

    /// Top corners are always 0 in notch mode so the island is flush against
    /// the screen edge — no crescent-shaped gap for the mouse to slip through.
    private var topCornerRadius: CGFloat {
        isNotchMode ? 0 : cornerRadius
    }
    
    private var containerShape: IslandContainerShape {
        IslandContainerShape(
            isNotchMode: isNotchMode,
            cornerRadius: cornerRadius,
            flareWidth: currentFlareWidth,
            flareHeight: currentFlareHeight
        )
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Island Body: ZStack strictly aligned to top
            ZStack(alignment: .top) {
                // ── Continuous Background — theme-aware, cross-faded ─────────

                // Helpers: opacity values driven by theme + expansion state
                let isDark  = settings.islandTheme == .dark
                let isLight = settings.islandTheme == .light

                // 1. Base layer
                //    • LiquidGlass / Dark: near-black fill (compact = opaque, expanded = semi-trans)
                //    • Light: white/near-white fill
                containerShape
                    .fill(isLight
                        ? Color.white.opacity(appState.isExpanded ? 0.80 : 0.95)
                        : Color.black.opacity(
                            isDark
                                ? (appState.isExpanded ? 0.82 : 1.0)   // dark: keep solid
                                : (appState.isExpanded ? 0.62 : 1.0)   // liquidGlass default
                          )
                    )

                // 2. Frosted material (NSVisualEffectView) — only for LiquidGlass + Light
                if !isDark {
                    LiquidGlassBackground(cornerRadius: cornerRadius, topCornerRadius: topCornerRadius)
                        .opacity(appState.isExpanded ? (isLight ? 0.75 : 0.92) : 0.0)
                }

                // 3. Expanded secondary tint for depth
                containerShape
                    .fill(isLight
                        ? Color.white.opacity(appState.isExpanded ? 0.18 : 0.0)  // keep bright
                        : Color.black.opacity(
                            isDark
                                ? (appState.isExpanded ? 0.22 : 0.0)
                                : (appState.isExpanded ? 0.35 : 0.0)
                          )
                    )

                // 4. Gradient sheen
                containerShape
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (isLight
                                    ? Color.white.opacity(appState.isExpanded ? 0.55 : 0.0)
                                    : Color.white.opacity(appState.isExpanded ? 0.06 : 0.0)
                                ),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // 5. Specular rim
                containerShape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: (isLight
                                    ? Color.black.opacity(appState.isExpanded ? 0.12 : 0.0)
                                    : Color.white.opacity(appState.isExpanded ? (appState.isHovering ? 0.38 : 0.22) : 0.0)
                                ), location: 0.0),
                                .init(color: (isLight
                                    ? Color.black.opacity(appState.isExpanded ? 0.04 : 0.0)
                                    : Color.white.opacity(appState.isExpanded ? 0.08 : 0.0)
                                ), location: 0.35),
                                .init(color: (isLight
                                    ? Color.black.opacity(appState.isExpanded ? 0.08 : 0.0)
                                    : Color.white.opacity(appState.isExpanded ? 0.14 : 0.0)
                                ), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .shadow(color: (isLight
                        ? Color.black.opacity(appState.isExpanded ? 0.05 : 0.0)
                        : Color.white.opacity(appState.isExpanded ? 0.08 : 0.0)
                    ), radius: 2, x: 0, y: -1)

                // 6. Compact sleek border
                containerShape
                    .stroke(
                        appState.isHovering
                            ? (isLight ? Color.black.opacity(0.18) : Color.white.opacity(0.24))
                            : (isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.12)),
                        lineWidth: 1
                    )
                    .opacity(appState.isExpanded ? 0.0 : 1.0)

                // 7. Drop shadow
                containerShape
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(appState.isExpanded ? 0.45 : 0.25),
                        radius: appState.isExpanded ? 16 : 8,
                        x: 0,
                        y: appState.isExpanded ? 8 : 3
                    )
                
                // Content View (Compact vs Expanded) with orchestrated asymmetric reveal
                Group {
                    if appState.isExpanded {
                        ExpandedIslandView()
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                                        .animation(IslandSpring.expand.delay(0.04)),
                                    removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                                        .animation(.easeOut(duration: 0.12))
                                )
                            )
                    } else {
                        CompactIslandView()
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.88, anchor: .top))
                                        .animation(IslandSpring.collapse.delay(0.06)),
                                    removal: .opacity.combined(with: .scale(scale: 0.82, anchor: .top))
                                        .animation(.easeOut(duration: 0.10))
                                )
                            )
                    }
                }
            }
            .frame(width: islandWidth, height: islandHeight, alignment: .top)
            // CLIP SHAPE: NotchIslandShape with smoothly interpolated top fillets and bottom corners
            .clipShape(containerShape)
            // Hovering a drag over the main island expands to reveal the shelf below,
            // but the main island itself rejects drops (drops belong exclusively to the shelf tray).
            .onDrop(of: [.fileURL, .item], isTargeted: $isTopHoveringDrag) { _ in
                return false
            }
            // Subtle breathing hover when idle in compact mode
            .scaleEffect(appState.isHovering && !appState.isExpanded ? 1.02 : 1.0, anchor: .top)
            .animation(IslandSpring.hover, value: appState.isHovering)
            .animation(appState.isExpanded ? IslandSpring.expand : IslandSpring.collapse, value: appState.isExpanded)
            .animation(IslandSpring.tabSlide, value: appState.activeTab)
            .onHover { hovering in
                if !hovering {
                    appState.cancelHover()
                }
            }

            // ── Split Bottom Shelf Rectangle (Separate rectangle below tab content) ──
            if appState.isExpanded && (!dropManager.items.isEmpty || appState.isDraggingOver || isTrayDropTargeted || isTopHoveringDrag) {
                BottomShelfRectangleView(isTargeted: $isTrayDropTargeted)
                    .frame(width: islandBodyWidth)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)).combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity.combined(with: .offset(y: 4)).combined(with: .scale(scale: 0.94, anchor: .top))
                        )
                    )
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isTopHoveringDrag) { _, targeted in
            if targeted {
                dragExitWorkItem?.cancel()
                dragExitWorkItem = nil
                appState.isDraggingOver = true
                appState.expand()
            } else {
                scheduleDragExitCheck()
            }
        }
        .onChange(of: isTrayDropTargeted) { _, targeted in
            if targeted {
                dragExitWorkItem?.cancel()
                dragExitWorkItem = nil
                appState.isDraggingOver = true
            } else {
                scheduleDragExitCheck()
            }
        }
    }

    private func scheduleDragExitCheck() {
        dragExitWorkItem?.cancel()
        let work = DispatchWorkItem { [weak appState] in
            guard let appState = appState else { return }
            if !isTopHoveringDrag && !isTrayDropTargeted {
                withAnimation(IslandSpring.collapse) {
                    appState.isDraggingOver = false
                    if !appState.isPinned && !appState.isHovering {
                        appState.collapse()
                    }
                }
            }
        }
        dragExitWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}
