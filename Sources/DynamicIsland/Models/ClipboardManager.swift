import Foundation
import AppKit
import Combine

public struct ClipboardItem: Identifiable, Equatable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    public let isURL: Bool
    
    public init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isURL = content.hasPrefix("http://") || content.hasPrefix("https://")
    }
}

public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()
    
    @Published public var history: [ClipboardItem] = []
    @Published public var searchText: String = ""
    @Published public var recentlyCopiedId: UUID?
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
        addSampleItem()
    }
    
    private func addSampleItem() {
        history.append(ClipboardItem(content: "https://github.com/vuhuydiet/dynamic-island"))
        history.append(ClipboardItem(content: "git clone https://github.com/example/repo.git"))
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Remove duplicates
            self.history.removeAll(where: { $0.content == text })
            self.history.insert(ClipboardItem(content: text), at: 0)
            
            // Limit to 40 items
            if self.history.count > 40 {
                self.history.removeLast()
            }
        }
    }
    
    public func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        
        SoundManager.shared.play(.click)
        recentlyCopiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.recentlyCopiedId == item.id {
                self?.recentlyCopiedId = nil
            }
        }
    }
    
    public func clearHistory() {
        history.removeAll()
        SoundManager.shared.play(.click)
    }
    
    public var filteredHistory: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return history
        } else {
            return history.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
