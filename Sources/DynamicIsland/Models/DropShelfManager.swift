import Foundation
import AppKit
import SwiftUI

public struct DroppedItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let fileName: String
    public let fileSizeString: String
    public let dateAdded: Date
    public let isDirectory: Bool
    
    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.dateAdded = Date()
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            self.fileSizeString = formatter.string(fromByteCount: size)
        } else {
            self.fileSizeString = "--"
        }
    }
}

public class DropShelfManager: ObservableObject {
    public static let shared = DropShelfManager()
    
    @Published public var items: [DroppedItem] = []
    
    private init() {}
    
    public func addItems(urls: [URL]) {
        for url in urls {
            // Prevent duplicates
            if !items.contains(where: { $0.url == url }) {
                items.insert(DroppedItem(url: url), at: 0)
            }
        }
        SoundManager.shared.play(.drop)
    }
    
    public func removeItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
        SoundManager.shared.play(.click)
    }
    
    public func clearAll() {
        items.removeAll()
        SoundManager.shared.play(.click)
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func copyPath(url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        SoundManager.shared.play(.click)
    }
}
