import SwiftUI
import AppKit

public struct DropShelfView: View {
    @ObservedObject var dropManager = DropShelfManager.shared
    @State private var isTargeted = false
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(.blue)
                        .font(IslandFont.iconRegular)
                    Text("File Drop Shelf")
                        .font(IslandFont.title)
                        .foregroundColor(.white)
                    
                    if !dropManager.items.isEmpty {
                        Text("\(dropManager.items.count)")
                            .font(IslandFont.metricNumeric)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if !dropManager.items.isEmpty {
                    Button(action: {
                        dropManager.clearAll()
                    }) {
                        Text("Clear All")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // Content
            if dropManager.items.isEmpty {
                // Empty state drop target
                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "plus.circle.dashed")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(isTargeted ? .blue : .white.opacity(0.35))
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: isTargeted)
                    
                    Text("Drag & Drop any file, image, or link here")
                        .font(IslandFont.subtitle)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Park files at the notch to drop into apps later")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 94)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isTargeted ? Color.blue : Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
                .padding(.horizontal, 14)
            } else {
                // List of dropped items
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dropManager.items) { item in
                            DroppedItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 100)
            }
        }
        .padding(.bottom, 6)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                dropManager.addItems(urls: urls)
            }
        }
    }
}

public struct DroppedItemCard: View {
    public let item: DroppedItem
    @ObservedObject var dropManager = DropShelfManager.shared
    @State private var isHovering = false
    
    public var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // File icon thumbnail
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .shadow(radius: 3)
                
                // Remove button on hover
                if isHovering {
                    Button(action: {
                        dropManager.removeItem(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(IslandFont.iconRegular)
                            .foregroundColor(.white.opacity(0.85))
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
            .frame(width: 50, height: 48)
            
            Text(item.fileName)
                .font(IslandFont.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .frame(width: 70)
            
            Text(item.fileSizeString)
                .font(IslandFont.micro)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Reveal in Finder") {
                dropManager.revealInFinder(url: item.url)
            }
            Button("Copy Path") {
                dropManager.copyPath(url: item.url)
            }
            Divider()
            Button("Remove from Shelf", role: .destructive) {
                dropManager.removeItem(id: item.id)
            }
        }
    }
}
