import SwiftUI

public struct ClipboardView: View {
    @ObservedObject var clipboard = ClipboardManager.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // Search & Clear Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                        .font(IslandFont.iconRegular)
                    
                    TextField("Search clipboard history...", text: $clipboard.searchText)
                        .textFieldStyle(.plain)
                        .font(IslandFont.body)
                        .foregroundColor(.white)
                    
                    if !clipboard.searchText.isEmpty {
                        Button(action: { clipboard.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.4))
                                .font(IslandFont.iconRegular)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                if !clipboard.history.isEmpty {
                    Button(action: {
                        withAnimation(IslandSpring.bouncy) {
                            clipboard.clearHistory()
                        }
                    }) {
                        Text("Clear")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // Clipboard Items List
            if clipboard.filteredHistory.isEmpty {
                VStack(spacing: 4) {
                    Text("No clipboard history yet")
                        .font(IslandFont.subtitle)
                        .foregroundColor(.white.opacity(0.4))
                    Text("Copy text or links anywhere to see them here")
                        .font(IslandFont.micro)
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(clipboard.filteredHistory) { item in
                            ClipboardRow(item: item)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 96)
                .animation(IslandSpring.bouncy, value: clipboard.filteredHistory.count)
            }
        }
        .padding(.bottom, 6)
    }
}

public struct ClipboardRow: View {
    public let item: ClipboardItem
    @ObservedObject var clipboard = ClipboardManager.shared
    @State private var isHovering = false
    
    public var body: some View {
        Button(action: {
            withAnimation(IslandSpring.bouncy) {
                clipboard.copyToClipboard(item)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.isURL ? "link" : "doc.text")
                    .font(IslandFont.iconRegular)
                    .foregroundColor(item.isURL ? .blue : .white.opacity(0.5))
                
                Text(item.content)
                    .font(item.isURL ? IslandFont.timeNumeric : IslandFont.body)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if clipboard.recentlyCopiedId == item.id {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(IslandFont.iconMicro)
                        Text("Copied")
                            .font(IslandFont.micro)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                } else {
                    Text("Copy")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(isHovering ? 0.8 : 0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovering ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(IslandSpring.bouncy, value: clipboard.recentlyCopiedId)
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.98))
        .onHover { hovering in
            withAnimation(IslandSpring.bouncy) {
                isHovering = hovering
            }
        }
    }
}
