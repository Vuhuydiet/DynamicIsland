import Foundation
import AppKit
import Combine

public struct ClipboardItem: Identifiable, Equatable, Codable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    public let isURL: Bool
    
    public init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
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
    
    public static let maxHistoryCount: Int = 1000
    
    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DynamicIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_history.json")
    }
    
    private let userDefaultsKey = "dynamic_island_persistent_clipboard_history"
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadHistory()
        startMonitoring()
    }
    
    private func loadHistory() {
        var loaded: [ClipboardItem] = []
        let fileURL = Self.storageURL
        
        if let data = try? Data(contentsOf: fileURL),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            loaded = items
        } else if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            loaded = items
        }
        
        // Ensure hardcoded sample items are purged completely
        loaded.removeAll(where: {
            $0.content == "https://github.com/vuhuydiet/dynamic-island" ||
            $0.content == "git clone https://github.com/example/repo.git"
        })
        
        // Enforce maximum history limit of 1000
        if loaded.count > Self.maxHistoryCount {
            loaded = Array(loaded.prefix(Self.maxHistoryCount))
        }
        
        self.history = loaded
        if !loaded.isEmpty {
            saveHistory()
        }
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: Self.storageURL, options: .atomic)
        // Store recent items in UserDefaults as lightweight backup
        let backup = Array(history.prefix(200))
        if let backupData = try? JSONEncoder().encode(backup) {
            UserDefaults.standard.set(backupData, forKey: userDefaultsKey)
        }
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
        
        // Never save the unwanted sample URLs if they somehow match
        guard text != "https://github.com/vuhuydiet/dynamic-island" &&
              text != "git clone https://github.com/example/repo.git" else { return }
        
        DispatchQueue.main.async {
            // Remove duplicates
            self.history.removeAll(where: { $0.content == text })
            self.history.insert(ClipboardItem(content: text), at: 0)
            
            // Limit to maxHistoryCount (1000 items)
            if self.history.count > Self.maxHistoryCount {
                self.history.removeSubrange(Self.maxHistoryCount...)
            }
            self.saveHistory()
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
    
    public func deleteItem(_ item: ClipboardItem) {
        history.removeAll(where: { $0.id == item.id })
        saveHistory()
        SoundManager.shared.play(.click)
    }
    
    public func clearHistory() {
        history.removeAll()
        saveHistory()
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
