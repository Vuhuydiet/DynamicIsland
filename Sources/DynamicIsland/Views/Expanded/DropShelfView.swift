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

                if !dropManager.selectedItemIDs.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                        Text("\(dropManager.selectedItemIDs.count) selected")
                            .font(IslandFont.micro)
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.cyan.opacity(0.18)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 0.5))
                }
            }

            Spacer()

            if !dropManager.items.isEmpty {
                // Select All / Deselect All Button
                Button {
                    withAnimation(IslandSpring.bouncy) {
                        if dropManager.selectedItemIDs.count == dropManager.items.count {
                            dropManager.clearSelection()
                        } else {
                            dropManager.selectAll()
                        }
                    }
                } label: {
                    Text(dropManager.selectedItemIDs.count == dropManager.items.count ? "Deselect" : "Select All")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.70))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                .help(dropManager.selectedItemIDs.count == dropManager.items.count ? "Deselect all files" : "Select all files (drag any to move all)")

                // Drag Selected Files Pill Handle
                if dropManager.selectedItemIDs.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 8))
                        Text("Drag \(dropManager.selectedItemIDs.count)")
                            .font(IslandFont.micro)
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.22)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 0.5))
                    .onDrag {
                        let urlsToDrag = dropManager.selectedURLs()
                        let firstURL = urlsToDrag.first ?? URL(fileURLWithPath: "/")
                        let provider = NSItemProvider(contentsOf: firstURL) ?? NSItemProvider()
                        let paths = urlsToDrag.map { $0.path }
                        provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
                            let data = try? PropertyListSerialization.data(fromPropertyList: paths, format: .xml, options: 0)
                            completion(data, nil)
                            return nil
                        }
                        DispatchQueue.main.async {
                            let dragPb = NSPasteboard(name: .drag)
                            dragPb.clearContents()
                            dragPb.writeObjects(urlsToDrag as [NSURL])
                        }
                        return provider
                    }
                    .help("Drag all selected files together into another app")
                }

                // Remove Selected or Clear All Button
                Button {
                    withAnimation(IslandSpring.bouncy) {
                        if !dropManager.selectedItemIDs.isEmpty {
                            dropManager.removeSelected()
                        } else {
                            dropManager.clearAll()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text(!dropManager.selectedItemIDs.isEmpty ? "Remove (\(dropManager.selectedItemIDs.count))" : "Clear All")
                            .font(IslandFont.micro)
                    }
                    .foregroundColor(.white.opacity(0.60))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                .help(!dropManager.selectedItemIDs.isEmpty ? "Remove selected files from shelf" : "Clear all parked files")
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

    private var isSelected: Bool {
        dropManager.isSelected(id: item.id)
    }

    public var body: some View {
        cardContent
            .scaleEffect(isHovering ? 1.04 : 1.0)
            .animation(IslandSpring.bouncy, value: isHovering)
            .animation(IslandSpring.bouncy, value: isSelected)
            .onHover { isHovering = $0 }
            .onTapGesture { handleTap() }
            .onDrag { makeItemProvider() }
            .contextMenu { cardContextMenu }
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.cyan.opacity(0.18)
        } else if isHovering {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.06)
        }
    }

    private var cardBorderColor: Color {
        if isSelected {
            return Color.cyan.opacity(0.85)
        } else if isHovering {
            return Color.cyan.opacity(0.40)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    @ViewBuilder
    private var iconWithBadges: some View {
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

            if isSelected || isHovering {
                Button {
                    withAnimation(IslandSpring.bouncy) {
                        dropManager.toggleSelection(id: item.id)
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                        .background(Circle().fill(Color.black.opacity(0.65)))
                }
                .buttonStyle(.plain)
                .offset(x: -20, y: -4)
            }
        }
        .frame(width: 38, height: 34)
    }

    private var cardContent: some View {
        VStack(spacing: 3) {
            iconWithBadges

            Text(item.fileName)
                .font(IslandFont.caption)
                .foregroundColor(isSelected ? .cyan : .white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 60)

            Text(item.fileSizeString)
                .font(IslandFont.micro)
                .foregroundColor(isSelected ? .cyan.opacity(0.75) : .white.opacity(0.45))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .frame(width: 66, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(cardBorderColor, lineWidth: isSelected ? 1.5 : 0.75)
        )
    }

    @ViewBuilder
    private var cardContextMenu: some View {
        if isSelected {
            Button("Deselect") { dropManager.toggleSelection(id: item.id) }
        } else {
            Button("Select") { dropManager.toggleSelection(id: item.id) }
        }
        Button("Select All") { dropManager.selectAll() }
        Divider()
        Button("Reveal in Finder") { dropManager.revealInFinder(url: item.url) }
        Button("Copy Path") { dropManager.copyPath(url: item.url) }
        Divider()
        Button("Remove from Shelf", role: .destructive) { dropManager.removeItem(id: item.id) }
    }

    private func handleTap() {
        let isModifier = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
        withAnimation(IslandSpring.bouncy) {
            if isModifier {
                dropManager.toggleSelection(id: item.id)
            } else if isSelected && dropManager.selectedItemIDs.count == 1 {
                dropManager.clearSelection()
            } else {
                dropManager.selectSingle(id: item.id)
            }
        }
    }

    private func makeItemProvider() -> NSItemProvider {
        if !isSelected {
            dropManager.selectSingle(id: item.id)
        }
        
        let urlsToDrag = dropManager.selectedURLs(including: item.url)
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        
        if urlsToDrag.count > 1 {
            let paths = urlsToDrag.map { $0.path }
            provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
                let data = try? PropertyListSerialization.data(fromPropertyList: paths, format: .xml, options: 0)
                completion(data, nil)
                return nil
            }
            DispatchQueue.main.async {
                let dragPb = NSPasteboard(name: .drag)
                dragPb.clearContents()
                dragPb.writeObjects(urlsToDrag as [NSURL])
            }
        }
        return provider
    }
}

// MARK: - Compact Strip Layout
public struct DropShelfCompactCard: View {
    public let item: DroppedItem
    @ObservedObject var dropManager = DropShelfManager.shared
    @State private var isHovering = false

    private var isSelected: Bool {
        dropManager.isSelected(id: item.id)
    }

    public var body: some View {
        compactCardContent
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .animation(IslandSpring.bouncy, value: isHovering)
            .animation(IslandSpring.bouncy, value: isSelected)
            .onHover { isHovering = $0 }
            .onTapGesture {
                handleTap()
            }
            .onDrag {
                makeItemProvider()
            }
            .contextMenu {
                compactCardContextMenu
            }
    }

    private var compactBackground: Color {
        if isSelected {
            return Color.cyan.opacity(0.18)
        } else if isHovering {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.06)
        }
    }

    private var compactBorderColor: Color {
        if isSelected {
            return Color.cyan.opacity(0.85)
        } else if isHovering {
            return Color.cyan.opacity(0.40)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private var compactCardContent: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(IslandSpring.bouncy) {
                    dropManager.toggleSelection(id: item.id)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : (isHovering ? "circle" : "circle.dashed"))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.50))
            }
            .buttonStyle(.plain)

            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.fileName)
                    .font(IslandFont.caption)
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 80, alignment: .leading)

                Text(item.fileSizeString)
                    .font(IslandFont.micro)
                    .foregroundColor(isSelected ? .cyan.opacity(0.75) : .white.opacity(0.45))
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
                .fill(compactBackground)
        )
        .overlay(
            Capsule()
                .stroke(compactBorderColor, lineWidth: isSelected ? 1.5 : 0.75)
        )
    }

    @ViewBuilder
    private var compactCardContextMenu: some View {
        if isSelected {
            Button("Deselect") { dropManager.toggleSelection(id: item.id) }
        } else {
            Button("Select") { dropManager.toggleSelection(id: item.id) }
        }
        Button("Select All") { dropManager.selectAll() }
        Divider()
        Button("Reveal in Finder") { dropManager.revealInFinder(url: item.url) }
        Button("Copy Path") { dropManager.copyPath(url: item.url) }
        Divider()
        Button("Remove from Shelf", role: .destructive) { dropManager.removeItem(id: item.id) }
    }

    private func handleTap() {
        let isModifier = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
        withAnimation(IslandSpring.bouncy) {
            if isModifier {
                dropManager.toggleSelection(id: item.id)
            } else if isSelected && dropManager.selectedItemIDs.count == 1 {
                dropManager.clearSelection()
            } else {
                dropManager.selectSingle(id: item.id)
            }
        }
    }

    private func makeItemProvider() -> NSItemProvider {
        if !isSelected {
            dropManager.selectSingle(id: item.id)
        }
        
        let urlsToDrag = dropManager.selectedURLs(including: item.url)
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        
        if urlsToDrag.count > 1 {
            let paths = urlsToDrag.map { $0.path }
            provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
                let data = try? PropertyListSerialization.data(fromPropertyList: paths, format: .xml, options: 0)
                completion(data, nil)
                return nil
            }
            DispatchQueue.main.async {
                let dragPb = NSPasteboard(name: .drag)
                dragPb.clearContents()
                dragPb.writeObjects(urlsToDrag as [NSURL])
            }
        }
        return provider
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
