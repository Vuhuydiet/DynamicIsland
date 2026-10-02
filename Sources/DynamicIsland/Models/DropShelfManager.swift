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
    
    private init() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.addShelfItems"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let path = note.object as? String {
                let url = URL(fileURLWithPath: path)
                self?.addItems(urls: [url])
            }
        }
    }
    
    public func handleDrop(providers: [NSItemProvider]) {
        var collectedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            collectedURLs.append(url)
                        }
                    }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            collectedURLs.append(url)
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            collectedURLs.append(url)
                        } else if let str = item as? String, let url = URL(string: str) {
                            collectedURLs.append(url)
                        }
                    }
                    group.leave()
                }
            } else {
                provider.loadItem(forTypeIdentifier: "public.item", options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            collectedURLs.append(url)
                        }
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if collectedURLs.isEmpty {
                let dragPboard = NSPasteboard(name: .drag)
                if let urls = dragPboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
                    collectedURLs = urls
                }
            }
            
            if !collectedURLs.isEmpty {
                self.addItems(urls: collectedURLs)
            }
        }
    }
    
    public func addItems(urls: [URL]) {
        for url in urls {
            let cleanURL = url.standardizedFileURL
            // Prevent duplicates
            if !items.contains(where: { $0.url.path == cleanURL.path }) {
                items.insert(DroppedItem(url: cleanURL), at: 0)
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
