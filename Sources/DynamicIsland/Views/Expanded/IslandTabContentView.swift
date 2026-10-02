import SwiftUI

/// Shared tab content host that renders whichever tool tab is active.
/// UI layout options for Opened Island organize header, tab bars, and transitions,
/// while reusing this shared content view.
public struct IslandTabContentView: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch appState.activeTab {
                case .media:     MediaView()
                case .dropShelf: DropShelfView()
                case .timer:     TimerView()
                case .clipboard: ClipboardView()
                case .notes:     NotesView()
                }
            }
            .id(appState.activeTab)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 6)).combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity.combined(with: .offset(y: -4))
                )
            )
        }
        .animation(IslandSpring.tabSlide, value: appState.activeTab)
    }
}
