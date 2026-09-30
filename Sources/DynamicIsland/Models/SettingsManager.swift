import Foundation
import SwiftUI
import Combine
import ServiceManagement

public enum NotchStyle: String, CaseIterable, Identifiable {
    case auto = "Auto Detect"
    case notch = "Attach to Notch / Top"
    case floating = "Floating Pill"
    
    public var id: String { rawValue }
}

public enum ExpandTrigger: String, CaseIterable, Identifiable {
    case hoverAndClick = "Hover & Click"
    case clickOnly = "Click Only"
    
    public var id: String { rawValue }
}

public enum IslandTheme: String, CaseIterable, Identifiable {
    case oledBlack = "Pure Jet Black"
    case frostedGlass = "Frosted Dark Glass"
    case midnight = "Midnight Glow"
    
    public var id: String { rawValue }
}

public enum SoundScheme: String, CaseIterable, Identifiable {
    case classic = "macOS Classic"
    case modern = "Modern Clicks"
    case subtle = "Subtle / Soft"
    
    public var id: String { rawValue }
}

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    @Published public var notchStyle: NotchStyle {
        didSet { defaults.set(notchStyle.rawValue, forKey: "notchStyle") }
    }
    
    @Published public var expandTrigger: ExpandTrigger {
        didSet { defaults.set(expandTrigger.rawValue, forKey: "expandTrigger") }
    }
    
    @Published public var islandTheme: IslandTheme {
        didSet { defaults.set(islandTheme.rawValue, forKey: "islandTheme") }
    }
    
    // MARK: - Sound Settings
    @Published public var soundEffectsEnabled: Bool {
        didSet { defaults.set(soundEffectsEnabled, forKey: "soundEffectsEnabled") }
    }
    
    @Published public var soundVolume: Double {
        didSet { defaults.set(soundVolume, forKey: "soundVolume") }
    }
    
    @Published public var soundScheme: SoundScheme {
        didSet { defaults.set(soundScheme.rawValue, forKey: "soundScheme") }
    }
    
    @Published public var soundOnExpand: Bool {
        didSet { defaults.set(soundOnExpand, forKey: "soundOnExpand") }
    }
    
    @Published public var soundOnCollapse: Bool {
        didSet { defaults.set(soundOnCollapse, forKey: "soundOnCollapse") }
    }
    
    @Published public var soundOnTabSwitch: Bool {
        didSet { defaults.set(soundOnTabSwitch, forKey: "soundOnTabSwitch") }
    }
    
    @Published public var soundOnDrop: Bool {
        didSet { defaults.set(soundOnDrop, forKey: "soundOnDrop") }
    }
    
    @Published public var soundOnTimer: Bool {
        didSet { defaults.set(soundOnTimer, forKey: "soundOnTimer") }
    }
    
    // MARK: - General & Geometry Settings
    @Published public var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon")
            AppDelegate.shared?.updateStatusItemVisibility(showMenuBarIcon)
        }
    }
    
    @Published public var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: "hoverDelay") }
    }
    
    @Published public var customWidthOffset: Double {
        didSet { defaults.set(customWidthOffset, forKey: "customWidthOffset") }
    }
    
    @Published public var customYOffset: Double {
        didSet { defaults.set(customYOffset, forKey: "customYOffset") }
    }
    
    @Published public var liveActivityCompact: Bool {
        didSet { defaults.set(liveActivityCompact, forKey: "liveActivityCompact") }
    }
    
    // MARK: - Open / Launch at Login
    @Published public var launchAtLogin: Bool = false
    
    private init() {
        let savedStyle = defaults.string(forKey: "notchStyle").flatMap(NotchStyle.init) ?? .auto
        let savedTrigger = defaults.string(forKey: "expandTrigger").flatMap(ExpandTrigger.init) ?? .hoverAndClick
        let savedTheme = defaults.string(forKey: "islandTheme").flatMap(IslandTheme.init) ?? .oledBlack
        let savedScheme = defaults.string(forKey: "soundScheme").flatMap(SoundScheme.init) ?? .classic
        
        self.notchStyle = savedStyle
        self.expandTrigger = savedTrigger
        self.islandTheme = savedTheme
        self.soundScheme = savedScheme
        
        self.soundEffectsEnabled = defaults.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        self.soundVolume = defaults.object(forKey: "soundVolume") as? Double ?? 0.75
        self.soundOnExpand = defaults.object(forKey: "soundOnExpand") as? Bool ?? true
        self.soundOnCollapse = defaults.object(forKey: "soundOnCollapse") as? Bool ?? true
        self.soundOnTabSwitch = defaults.object(forKey: "soundOnTabSwitch") as? Bool ?? true
        self.soundOnDrop = defaults.object(forKey: "soundOnDrop") as? Bool ?? true
        self.soundOnTimer = defaults.object(forKey: "soundOnTimer") as? Bool ?? true
        
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.hoverDelay = defaults.object(forKey: "hoverDelay") as? Double ?? 0.18
        self.customWidthOffset = defaults.object(forKey: "customWidthOffset") as? Double ?? 0.0
        self.customYOffset = defaults.object(forKey: "customYOffset") as? Double ?? 0.0
        self.liveActivityCompact = defaults.object(forKey: "liveActivityCompact") as? Bool ?? true
        
        var isEnabled = defaults.bool(forKey: "launchAtLogin")
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                isEnabled = true
            }
        }
        self.launchAtLogin = isEnabled
    }
    
    public func setLaunchAtLogin(_ enable: Bool) {
        self.launchAtLogin = enable
        defaults.set(enable, forKey: "launchAtLogin")
        
        // 1. Modern macOS 13+ ServiceManagement SMAppService
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("SMAppService register note: \(error)")
            }
        }
        
        // 2. Synchronize with macOS System Events login items in background
        let bundlePath = Bundle.main.bundlePath
        let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "DynamicIsland"
        
        DispatchQueue.global(qos: .utility).async {
            let script: String
            if enable {
                script = "tell application \"System Events\" to make login item at end with properties {path:\"\(bundlePath)\", hidden:false, name:\"\(appName)\"}"
            } else {
                script = "tell application \"System Events\" to delete (every login item whose name is \"\(appName)\")"
            }
            if let appleScript = NSAppleScript(source: script) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
            }
        }
    }
    
    public func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                self.launchAtLogin = true
                return
            }
        }
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }
}
