import AppKit
import SwiftUI
import Combine

/// Standardized manager for discovering, downloading, caching, and serving application logos and icons.
public class PluginIconManager: ObservableObject {
    public static let shared = PluginIconManager()
    
    private let cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    
    /// User application support directory where custom/downloaded icons are cached
    public let customIconsDirectory: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let islandSupport = appSupport.appendingPathComponent("DynamicIsland", isDirectory: true)
        self.customIconsDirectory = islandSupport.appendingPathComponent("PluginIcons", isDirectory: true)
        
        try? fileManager.createDirectory(at: customIconsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    // MARK: - Icon Discovery & Resolution
    
    /// Resolves the authentic app icon for a given plugin ID or app name.
    /// Hierarchy: Memory Cache -> User App Support -> Bundle Resources -> Development Resources -> Installed App -> nil.
    public func icon(for id: String) -> NSImage? {
        let cacheKey = id as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        let normalizedIDs = candidateKeys(for: id)
        
        // 1. User Application Support cache directory
        for key in normalizedIDs {
            let fileURL = customIconsDirectory.appendingPathComponent("\(key).png")
            if let image = NSImage(contentsOf: fileURL) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
        }
        
        // 2. App Bundle Resources / PluginIcons/
        for key in normalizedIDs {
            // Check in subdirectory "PluginIcons"
            if let bundleURL = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "PluginIcons"),
               let image = NSImage(contentsOf: bundleURL) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
            // Check directly in resourceURL/PluginIcons/
            if let resURL = Bundle.main.resourceURL?.appendingPathComponent("PluginIcons/\(key).png"),
               let image = NSImage(contentsOf: resURL) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
            // Check in root resources
            if let rootURL = Bundle.main.url(forResource: key, withExtension: "png"),
               let image = NSImage(contentsOf: rootURL) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
        }
        
        // 3. Project Development fallback (e.g. running from source before bundle copy)
        for key in normalizedIDs {
            let devPath = "Resources/PluginIcons/\(key).png"
            if fileManager.fileExists(atPath: devPath),
               let image = NSImage(contentsOfFile: devPath) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
        }
        
        // 4. Installed macOS Application Bundle Icon
        for key in normalizedIDs {
            if let appImg = PluginManager.appIcon(bundleIdentifier: key) {
                cache.setObject(appImg, forKey: cacheKey)
                return appImg
            }
        }
        
        return nil
    }
    
    /// Checks if a direct logo image file exists for the given ID.
    public func hasIcon(for id: String) -> Bool {
        icon(for: id) != nil
    }
    
    // MARK: - Storage & Downloading
    
    /// Saves an NSImage to local persistent cache for the given plugin ID.
    public func saveIcon(image: NSImage, for id: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return
        }
        
        let destination = customIconsDirectory.appendingPathComponent("\(id).png")
        try? png.write(to: destination)
        cache.setObject(image, forKey: id as NSString)
        
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// Downloads an icon from a remote URL, saves it to persistent storage, and caches it.
    public func downloadAndCacheIcon(from url: URL, for id: String, completion: ((NSImage?) -> Void)? = nil) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = NSImage(data: data) else {
                DispatchQueue.main.async { completion?(nil) }
                return
            }
            
            self.saveIcon(image: image, for: id)
            DispatchQueue.main.async {
                completion?(image)
            }
        }
        task.resume()
    }
    
    // MARK: - Standardized View Providers
    
    /// Standardized icon view for any plugin, rendering the downloaded logo if available or fallback.
    public func iconView(for plugin: any IslandPlugin, size: CGFloat = 12) -> AnyView {
        if let img = icon(for: plugin.id) {
            return AnyView(
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            )
        }
        
        if let custom = plugin.makeIconView(size: size) {
            return custom
        }
        
        return AnyView(
            Image(systemName: plugin.icon)
                .font(.system(size: size, weight: .bold))
        )
    }
    
    /// Standardized icon view for any island tab.
    public func iconView(for tab: IslandTab, size: CGFloat = 12) -> AnyView {
        switch tab {
        case .media:
            return AnyView(Image(systemName: "music.note").font(.system(size: size, weight: .bold)))
        case .timer:
            return AnyView(Image(systemName: "timer").font(.system(size: size, weight: .bold)))
        case .clipboard:
            return AnyView(Image(systemName: "doc.on.clipboard.fill").font(.system(size: size, weight: .bold)))
        case .notes:
            return AnyView(Image(systemName: "note.text").font(.system(size: size, weight: .bold)))
        case .plugin(let id):
            if let img = icon(for: id) {
                return AnyView(
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                )
            }
            if let custom = PluginManager.shared.plugin(for: id)?.makeIconView(size: size) {
                return custom
            }
            let sfIcon = PluginManager.shared.plugin(for: id)?.icon ?? "puzzlepiece.extension"
            return AnyView(Image(systemName: sfIcon).font(.system(size: size, weight: .bold)))
        }
    }
    
    // MARK: - Helpers

    /// The filenames an id's icon might be stored under, most specific first.
    ///
    /// Web-app ids embed the whole host, so the *last* component is often a public
    /// suffix: `com.dynamicisland.webapp.web.web.whatsapp.com` ends in `com`, and
    /// matching only that would make `whatsapp.png` unreachable. Leading platform
    /// labels are therefore skipped, so that id also tries `whatsapp`.
    private func candidateKeys(for id: String) -> [String] {
        var keys = [id]
        let lower = id.lowercased()
        if !keys.contains(lower) {
            keys.append(lower)
        }
        for label in Self.iconLabelCandidates(for: id) {
            if !keys.contains(label) {
                keys.append(label)
            }
        }
        return keys
    }

    /// Host labels worth trying as a filename, most specific first.
    static func iconLabelCandidates(for id: String) -> [String] {
        let labels = id.lowercased().split(separator: ".").map(String.init)
        // Drop platform labels and the trailing public suffix, keeping at least one
        // label so a single-label host still resolves.
        var trimmed = labels
        while trimmed.count > 1, let first = trimmed.first, Self.nonIconLabels.contains(first) {
            trimmed.removeFirst()
        }
        while trimmed.count > 1, let last = trimmed.last, Self.nonIconLabels.contains(last) {
            trimmed.removeLast()
        }
        return trimmed + labels.reversed()
    }

    /// Host labels that are never a useful icon filename.
    private static let nonIconLabels: Set<String> = [
        "com", "net", "org", "io", "co", "app", "dev", "me", "ai", "sh", "tv", "gg",
        "www", "web", "m", "chat", "mail", "mobile",
    ]
}
