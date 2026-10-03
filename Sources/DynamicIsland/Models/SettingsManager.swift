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
    case liquidGlass = "Liquid Glass"
    case dark        = "Dark"
    case light       = "Light"

    public var id: String { rawValue }
}

public enum ClosedNotchStyle: String, CaseIterable, Identifiable {
    case defaultStyle = "Default"
    
    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue {
        case "Default", "Option 1 (Default)", "Option 1":
            self = .defaultStyle
        default:
            return nil
        }
    }
}

public enum OpenedIslandStyle: String, CaseIterable, Identifiable {
    case defaultStyle   = "Default"
    case bottomDeck     = "Bottom Deck"
    case compactHUD     = "Compact HUD"
    case floatingCards  = "Floating Cards"
    case commandCenter  = "Command Center"
    
    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue {
        case "Default", "Option 1 (Default)", "Option 1":
            self = .defaultStyle
        case "Bottom Deck":
            self = .bottomDeck
        case "Compact HUD":
            self = .compactHUD
        case "Floating Cards":
            self = .floatingCards
        case "Command Center":
            self = .commandCenter
        default:
            return nil
        }
    }
}

public enum SoundScheme: String, CaseIterable, Identifiable {
    case classic = "macOS Classic"
    case modern = "Modern Clicks"
    case subtle = "Subtle / Soft"
    
    public var id: String { rawValue }
}

public enum TimerAlertCadence: String, CaseIterable, Identifiable {
    case rapid = "Rapid (0.65s)"
    case balanced = "Balanced (1.0s)"
    case relaxed = "Relaxed (1.5s)"
    
    public var id: String { rawValue }
    
    public var interval: TimeInterval {
        switch self {
        case .rapid: return 0.65
        case .balanced: return 1.0
        case .relaxed: return 1.5
        }
    }
    
    public var repeatCount: Int {
        switch self {
        case .rapid: return 6
        case .balanced: return 4
        case .relaxed: return 3
        }
    }
}

public enum DropShelfCardStyle: String, CaseIterable, Identifiable {
    case square = "Square Cards"
    case compact = "Compact Strip"
    
    public var id: String { rawValue }
}

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    @Published public var dropShelfCardStyle: DropShelfCardStyle {
        didSet { defaults.set(dropShelfCardStyle.rawValue, forKey: "dropShelfCardStyle") }
    }
    
    @Published public var notchStyle: NotchStyle {
        didSet { defaults.set(notchStyle.rawValue, forKey: "notchStyle") }
    }
    
    @Published public var expandTrigger: ExpandTrigger {
        didSet { defaults.set(expandTrigger.rawValue, forKey: "expandTrigger") }
    }
    
    @Published public var islandTheme: IslandTheme {
        didSet { defaults.set(islandTheme.rawValue, forKey: "islandTheme") }
    }

    @Published public var closedNotchStyle: ClosedNotchStyle {
        didSet { defaults.set(closedNotchStyle.rawValue, forKey: "closedNotchStyle") }
    }

    @Published public var openedIslandStyle: OpenedIslandStyle {
        didSet { defaults.set(openedIslandStyle.rawValue, forKey: "openedIslandStyle") }
    }

    @Published public var expansionAnimation: ExpansionAnimationStyle {
        didSet { defaults.set(expansionAnimation.rawValue, forKey: "expansionAnimation") }
    }

    @Published public var animationSpeedMultiplier: Double {
        didSet { defaults.set(animationSpeedMultiplier, forKey: "animationSpeedMultiplier") }
    }

    /// Raw values of tabs the user wants hidden from the tab bar.
    @Published public var hiddenTabs: Set<String> {
        didSet {
            defaults.set(Array(hiddenTabs), forKey: "hiddenTabs")
        }
    }

    /// Returns true when the given tab should appear in the tab bar.
    public func isTabVisible(_ tab: IslandTab) -> Bool {
        !hiddenTabs.contains(tab.rawValue)
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
    
    @Published public var timerAlertCadence: TimerAlertCadence {
        didSet { defaults.set(timerAlertCadence.rawValue, forKey: "timerAlertCadence") }
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
        let savedTheme = defaults.string(forKey: "islandTheme").flatMap(IslandTheme.init) ?? .liquidGlass
        let savedClosedStyle = defaults.string(forKey: "closedNotchStyle").flatMap(ClosedNotchStyle.init) ?? .defaultStyle
        let savedOpenedStyle = defaults.string(forKey: "openedIslandStyle").flatMap(OpenedIslandStyle.init) ?? .defaultStyle
        let savedAnim = defaults.string(forKey: "expansionAnimation").flatMap(ExpansionAnimationStyle.init) ?? .fluidApple
        let savedSpeed = defaults.object(forKey: "animationSpeedMultiplier") as? Double ?? 1.0
        let savedScheme = defaults.string(forKey: "soundScheme").flatMap(SoundScheme.init) ?? .classic
        let savedCardStyle = defaults.string(forKey: "dropShelfCardStyle").flatMap(DropShelfCardStyle.init) ?? .square

        self.dropShelfCardStyle = savedCardStyle
        self.notchStyle = savedStyle
        self.expandTrigger = savedTrigger
        self.islandTheme = savedTheme
        self.closedNotchStyle = savedClosedStyle
        self.openedIslandStyle = savedOpenedStyle
        self.expansionAnimation = savedAnim
        self.animationSpeedMultiplier = savedSpeed
        self.soundScheme = savedScheme

        // Restore hidden tabs (stored as array of raw-value strings)
        let savedHidden = defaults.stringArray(forKey: "hiddenTabs") ?? []
        self.hiddenTabs = Set(savedHidden)
        
        self.soundEffectsEnabled = defaults.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        self.soundVolume = defaults.object(forKey: "soundVolume") as? Double ?? 0.75
        self.soundOnExpand = defaults.object(forKey: "soundOnExpand") as? Bool ?? true
        self.soundOnCollapse = defaults.object(forKey: "soundOnCollapse") as? Bool ?? true
        self.soundOnTabSwitch = defaults.object(forKey: "soundOnTabSwitch") as? Bool ?? true
        self.soundOnDrop = defaults.object(forKey: "soundOnDrop") as? Bool ?? true
        self.soundOnTimer = defaults.object(forKey: "soundOnTimer") as? Bool ?? true
        let savedCadence = defaults.string(forKey: "timerAlertCadence").flatMap(TimerAlertCadence.init) ?? .rapid
        self.timerAlertCadence = savedCadence
        
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.hoverDelay = defaults.object(forKey: "hoverDelay") as? Double ?? 0.05
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

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.setOpenedIslandStyle"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let styleStr = note.object as? String, let style = OpenedIslandStyle(rawValue: styleStr) {
                self?.openedIslandStyle = style
            }
        }
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
