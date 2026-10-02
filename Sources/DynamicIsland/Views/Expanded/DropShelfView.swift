import SwiftUI
import AppKit

/// Bottom Shelf Rectangle: A distinct, secondary floating glass rectangle
/// positioned at the bottom of the tab content that appears whenever files are parked or being dragged.
public struct BottomShelfRectangleView: View {
    @ObservedObject var dropManager = DropShelfManager.shared
    @ObservedObject var appState    = AppState.shared
    @ObservedObject var settings    = SettingsManager.shared
    @Binding var isTargeted: Bool

    private let cornerRadius: CGFloat = 18.0

    public init(isTargeted: Binding<Bool> = .constant(false)) {
        self._isTargeted = isTargeted
    }

    public var body: some View {
        ZStack {
            // 1. Frosted Material Layer
            LiquidGlassBackground(cornerRadius: cornerRadius, topCornerRadius: cornerRadius)
                .opacity(settings.islandTheme == .dark ? 0.0 : 0.92)

            // 2. Base Dark Tint
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(settings.islandTheme == .dark ? 0.85 : 0.65))

            // 3. Subtle Gradient Sheen
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // 4. Active Drop Glow Fill
            if isTargeted {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cyan.opacity(0.12))
                    .transition(.opacity)
            }

            // 5. Specular Rim Stroke & Drop highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    isTargeted
                        ? Color.cyan.opacity(0.95)
                        : Color.white.opacity(0.18),
                    lineWidth: isTargeted ? 2.0 : 0.75
                )

            // 6. Content
            VStack(spacing: 6) {
                headerBar

                if dropManager.items.isEmpty {
                    emptyDropZone
                } else {
                    cardsScrollView
                }
            }
        }
        .frame(height: settings.dropShelfCardStyle == .square ? 92 : 60)
        .shadow(
            color: isTargeted ? Color.cyan.opacity(0.50) : Color.black.opacity(0.40),
            radius: isTargeted ? 16 : 10,
            x: 0,
            y: 5
        )
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .onDrop(of: [.fileURL, .item], isTargeted: $isTargeted) { providers in
            dropManager.handleDrop(providers: providers)
            appState.isDraggingOver = false
            return true
        }
        .animation(IslandSpring.bouncy, value: dropManager.items.count)
        .animation(IslandSpring.bouncy, value: isTargeted)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(IslandFont.iconMicro)
                    .foregroundColor(.cyan)

                Text("Parked Shelf")
                    .font(IslandFont.caption)
                    .foregroundColor(.white.opacity(0.90))

                if !dropManager.items.isEmpty {
                    Text("\(dropManager.items.count)")
                        .font(IslandFont.metricNumeric)
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.cyan.opacity(0.20)))
                }
            }

            Spacer()

            if !dropManager.items.isEmpty {
                Button {
                    withAnimation(IslandSpring.bouncy) {
                        dropManager.clearAll()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear All")
                            .font(IslandFont.micro)
                    }
                    .foregroundColor(.white.opacity(0.60))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                .help("Clear all parked files")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
    }

    private var emptyDropZone: some View {
        HStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "plus.circle.dashed")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(isTargeted ? .cyan : .white.opacity(0.45))
                .scaleEffect(isTargeted ? 1.20 : 1.0)
                .animation(IslandSpring.bouncy, value: isTargeted)

            Text(isTargeted ? "Release to park on shelf" : "Drop files here to park on shelf")
                .font(IslandFont.caption)
                .fontWeight(isTargeted ? .semibold : .regular)
                .foregroundColor(isTargeted ? .cyan : .white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isTargeted ? Color.cyan.opacity(0.18) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isTargeted ? Color.cyan : Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: isTargeted ? 1.8 : 1.2, dash: isTargeted ? [8, 4] : [6, 4])
                )
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 7)
    }

    private var cardsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dropManager.items) { item in
                    if settings.dropShelfCardStyle == .square {
                        DropShelfSquareCard(item: item)
                    } else {
                        DropShelfCompactCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 7)
        }
    }
}

// MARK: - Square Card Layout (Default)
public struct DropShelfSquareCard: View {
    public let item: DroppedItem
    @ObservedObject var dropManager = DropShelfManager.shared
    @State private var isHovering = false

    public var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 2)

                if isHovering {
                    Button {
                        withAnimation(IslandSpring.bouncy) {
                            dropManager.removeItem(id: item.id)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -4)
                }
            }
            .frame(width: 38, height: 34)

            Text(item.fileName)
                .font(IslandFont.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 60)

            Text(item.fileSizeString)
                .font(IslandFont.micro)
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .frame(width: 66, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isHovering ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.75)
        )
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(IslandSpring.bouncy, value: isHovering)
        .onHover { isHovering = $0 }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Reveal in Finder") { dropManager.revealInFinder(url: item.url) }
            Button("Copy Path") { dropManager.copyPath(url: item.url) }
            Divider()
            Button("Remove from Shelf", role: .destructive) { dropManager.removeItem(id: item.id) }
        }
    }
}

// MARK: - Compact Strip Layout
public struct DropShelfCompactCard: View {
    public let item: DroppedItem
    @ObservedObject var dropManager = DropShelfManager.shared
    @State private var isHovering = false

    public var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.fileName)
                    .font(IslandFont.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 80, alignment: .leading)

                Text(item.fileSizeString)
                    .font(IslandFont.micro)
                    .foregroundColor(.white.opacity(0.45))
            }

            if isHovering {
                Button {
                    withAnimation(IslandSpring.bouncy) {
                        dropManager.removeItem(id: item.id)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(
            Capsule()
                .fill(isHovering ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(isHovering ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.75)
        )
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(IslandSpring.bouncy, value: isHovering)
        .onHover { isHovering = $0 }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Reveal in Finder") { dropManager.revealInFinder(url: item.url) }
            Button("Copy Path") { dropManager.copyPath(url: item.url) }
            Divider()
            Button("Remove from Shelf", role: .destructive) { dropManager.removeItem(id: item.id) }
        }
    }
}

/// Fallback wrapper
public struct NotchDropShelfTrayView: View {
    public init() {}
    public var body: some View {
        BottomShelfRectangleView()
    }
}

public struct DropShelfView: View {
    public init() {}
    public var body: some View {
        BottomShelfRectangleView()
    }
}
