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
                        clipboard.clearHistory()
                    }) {
                        Text("Clear")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
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
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 96)
            }
        }
        .padding(.bottom, 6)
    }
}

public struct ClipboardRow: View {
    public let item: ClipboardItem
    @ObservedObject var clipboard = ClipboardManager.shared
    
    public var body: some View {
        Button(action: {
            clipboard.copyToClipboard(item)
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
                } else {
                    Text("Copy")
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
