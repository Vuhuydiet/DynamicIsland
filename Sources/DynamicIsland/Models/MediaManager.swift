import Foundation
import AppKit
import SwiftUI
import Combine

public struct MediaTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var position: Double
    public var isPlaying: Bool
    public var source: MediaSource
    public var artworkData: Data?
    
    public static var empty: MediaTrack {
        MediaTrack(
            title: "No Media Playing",
            artist: "Play audio or video from YouTube, Spotify, Music, or local players",
            album: "",
            duration: 0,
            position: 0,
            isPlaying: false,
            source: .none,
            artworkData: nil
        )
    }
}

public enum MediaSource: String, Sendable {
    case music = "Apple Music"
    case spotify = "Spotify"
    case youtube = "YouTube"
    case quicktime = "QuickTime Player"
    case vlc = "VLC Media"
    case iina = "IINA"
    case browser = "Web Video"
    case mediaRemote = "Now Playing"
    case demo = "Demo Player"
    case none = "None"
    
    public var iconName: String {
        switch self {
        case .music: return "apple.logo"
        case .spotify: return "antenna.radiowaves.left.and.right"
        case .youtube: return "play.rectangle.fill"
        case .quicktime: return "film"
        case .vlc: return "cone.fill"
        case .iina: return "play.circle.fill"
        case .browser: return "globe"
        case .mediaRemote: return "waveform"
        case .demo: return "sparkles"
        case .none: return "music.note"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .music: return .pink
        case .spotify: return .green
        case .youtube: return .red
        case .quicktime: return .cyan
        case .vlc: return .orange
        case .iina: return .purple
        case .browser: return .indigo
        case .mediaRemote: return .blue
        case .demo: return .pink
        case .none: return .white
        }
    }
}

public class MediaManager: ObservableObject, @unchecked Sendable {
    public static let shared = MediaManager()
    
    @Published public var currentTrack: MediaTrack = .empty
    @Published public var visualizerHeights: [CGFloat] = [0.2, 0.4, 0.7, 0.9, 0.6, 0.3, 0.5]
    @Published public var volume: Double = 0.75
    
    private var pollTimer: Timer?
    private var visualizerTimer: Timer?
    private var demoTimer: Timer?
    
    // MediaRemote function pointers
    private typealias MRGetNowPlayingInfoType = @convention(c) (DispatchQueue, @escaping @Sendable (CFDictionary?) -> Void) -> Void
    private typealias MRRegisterNotificationsType = @convention(c) (DispatchQueue) -> Void
    private var mrGetNowPlayingInfo: MRGetNowPlayingInfoType?
    
    private init() {
        setupMediaRemote()
        startPolling()
        startVisualizer()
    }
    
    // MARK: - MediaRemote Framework Bridge
    private func setupMediaRemote() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return
        }
        
        if let getInfoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            mrGetNowPlayingInfo = unsafeBitCast(getInfoSym, to: MRGetNowPlayingInfoType.self)
        }
        
        if let registerSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFn = unsafeBitCast(registerSym, to: MRRegisterNotificationsType.self)
            registerFn(DispatchQueue.main)
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshMedia()
            }
        }
    }
    
    // MARK: - Polling & Visualizer
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshMedia()
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshMedia()
        }
    }
    
    public func startVisualizer() {
        visualizerTimer?.invalidate()
        visualizerTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentTrack.isPlaying {
                self.visualizerHeights = (0..<7).map { _ in
                    CGFloat.random(in: 0.25...1.0)
                }
            } else {
                self.visualizerHeights = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15]
            }
        }
    }
    
    // MARK: - Multi-Tier Media Detection
    public func refreshMedia() {
        // If demo track is playing, let it finish or cycle unless another real media starts
        if currentTrack.source == .demo && currentTrack.isPlaying {
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // Tier 1: Check Apple Music
            if self.isAppRunning(bundleId: "com.apple.Music"), let track = self.fetchAppleMusicTrack() {
                DispatchQueue.main.async { self.currentTrack = track }
                return
            }
            
            // Tier 2: Check Spotify
            if self.isAppRunning(bundleId: "com.spotify.client"), let track = self.fetchSpotifyTrack() {
                DispatchQueue.main.async { self.currentTrack = track }
                return
            }
            
            // Tier 3: Check Local Video Players (QuickTime, VLC)
            if self.isAppRunning(bundleId: "com.apple.QuickTimePlayerX"), let track = self.fetchQuickTimeTrack() {
                DispatchQueue.main.async { self.currentTrack = track }
                return
            }
            
            if self.isAppRunning(bundleId: "org.videolan.vlc"), let track = self.fetchVLCTrack() {
                DispatchQueue.main.async { self.currentTrack = track }
                return
            }
            
            // Tier 4: Check Web Browsers for YouTube & Web Video (Chrome, Safari, Brave, Arc, Edge)
            if let track = self.fetchWebVideoTrack() {
                DispatchQueue.main.async { self.currentTrack = track }
                return
            }
            
            // Tier 5: System-wide NowPlaying via MediaRemote
            self.fetchMediaRemoteTrack { [weak self] mrTrack in
                guard let self = self else { return }
                if let mrTrack = mrTrack {
                    DispatchQueue.main.async { self.currentTrack = mrTrack }
                } else {
                    DispatchQueue.main.async {
                        if self.currentTrack.source != .demo && self.currentTrack.isPlaying {
                            self.currentTrack = .empty
                        }
                    }
                }
            }
        }
    }
    
    private func isAppRunning(bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    // MARK: - Apple Music Adapter
    private func fetchAppleMusicTrack() -> MediaTrack? {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set pState to player state as string
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tPos to player position
                set tDur to duration of current track
                return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tPos & "|||" & tDur
            else
                return "stopped"
            end if
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty, output != "stopped" else {
            return nil
        }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0].lowercased().contains("playing")
        return MediaTrack(
            title: parts[1].isEmpty ? "Unknown Title" : parts[1],
            artist: parts[2].isEmpty ? "Apple Music" : parts[2],
            album: parts[3],
            duration: Double(parts[5]) ?? 0,
            position: Double(parts[4]) ?? 0,
            isPlaying: isPlaying,
            source: .music,
            artworkData: nil
        )
    }
    
    // MARK: - Spotify Adapter
    private func fetchSpotifyTrack() -> MediaTrack? {
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set pState to player state as string
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tPos to player position
                set tDur to (duration of current track) / 1000
                return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tPos & "|||" & tDur
            else
                return "stopped"
            end if
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty, output != "stopped" else {
            return nil
        }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0].lowercased().contains("playing")
        return MediaTrack(
            title: parts[1].isEmpty ? "Unknown Title" : parts[1],
            artist: parts[2].isEmpty ? "Spotify" : parts[2],
            album: parts[3],
            duration: Double(parts[5]) ?? 0,
            position: Double(parts[4]) ?? 0,
            isPlaying: isPlaying,
            source: .spotify,
            artworkData: nil
        )
    }
    
    // MARK: - QuickTime Player Adapter
    private func fetchQuickTimeTrack() -> MediaTrack? {
        let script = """
        tell application "QuickTime Player"
            if (count of documents) > 0 then
                set doc to document 1
                set pState to playing of doc
                set docName to name of doc
                set curTime to current time of doc
                set docDur to duration of doc
                return (pState as string) & "|||" & docName & "|||" & curTime & "|||" & docDur
            else
                return "stopped"
            end if
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty, output != "stopped" else {
            return nil
        }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }
        
        let isPlaying = parts[0].lowercased().contains("true")
        return MediaTrack(
            title: parts[1].isEmpty ? "Video" : parts[1],
            artist: "QuickTime Player",
            album: "Local Video",
            duration: Double(parts[3]) ?? 0,
            position: Double(parts[2]) ?? 0,
            isPlaying: isPlaying,
            source: .quicktime,
            artworkData: nil
        )
    }
    
    // MARK: - VLC Media Player Adapter
    private func fetchVLCTrack() -> MediaTrack? {
        let script = """
        tell application "VLC"
            if playing then
                set tName to name of current item
                set curTime to current time
                set tDur to duration of current item
                return "playing|||" & tName & "|||" & curTime & "|||" & tDur
            else
                return "stopped"
            end if
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty, output != "stopped" else {
            return nil
        }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }
        
        return MediaTrack(
            title: parts[1].isEmpty ? "Media File" : parts[1],
            artist: "VLC Media Player",
            album: "Video / Audio",
            duration: Double(parts[3]) ?? 0,
            position: Double(parts[2]) ?? 0,
            isPlaying: true,
            source: .vlc,
            artworkData: nil
        )
    }
    
    // MARK: - Web Browsers (YouTube & Video streaming)
    private func fetchWebVideoTrack() -> MediaTrack? {
        // 1. Google Chrome
        if isAppRunning(bundleId: "com.google.Chrome") {
            let script = """
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        set tTitle to title of t
                        set tUrl to URL of t
                        if tTitle contains "- YouTube" or tUrl contains "youtube.com/watch" or tUrl contains "youtu.be" or tUrl contains "vimeo.com" or tUrl contains "netflix.com/watch" or tUrl contains "twitch.tv" then
                            return tTitle & "|||" & tUrl
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
            if let output = runAppleScript(script), !output.isEmpty, let track = parseWebVideoOutput(output) {
                return track
            }
        }
        
        // 2. Safari
        if isAppRunning(bundleId: "com.apple.Safari") {
            let script = """
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        set tTitle to name of t
                        set tUrl to URL of t
                        if tTitle contains "- YouTube" or tUrl contains "youtube.com/watch" or tUrl contains "youtu.be" or tUrl contains "vimeo.com" or tUrl contains "netflix.com/watch" or tUrl contains "twitch.tv" then
                            return tTitle & "|||" & tUrl
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
            if let output = runAppleScript(script), !output.isEmpty, let track = parseWebVideoOutput(output) {
                return track
            }
        }
        
        // 3. Brave Browser
        if isAppRunning(bundleId: "com.brave.Browser") {
            let script = """
            tell application "Brave Browser"
                repeat with w in windows
                    repeat with t in tabs of w
                        set tTitle to title of t
                        set tUrl to URL of t
                        if tTitle contains "- YouTube" or tUrl contains "youtube.com/watch" or tUrl contains "youtu.be" or tUrl contains "vimeo.com" or tUrl contains "netflix.com/watch" or tUrl contains "twitch.tv" then
                            return tTitle & "|||" & tUrl
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
            if let output = runAppleScript(script), !output.isEmpty, let track = parseWebVideoOutput(output) {
                return track
            }
        }
        
        return nil
    }
    
    private func parseWebVideoOutput(_ raw: String) -> MediaTrack? {
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        
        var title = parts[0]
        let url = parts[1]
        
        // Clean title prefixes like "(1) ", "▶ ", etc.
        if let regex = try? NSRegularExpression(pattern: #"^(\([0-9]+\)|\▶|\[Playing\])\s*"#, options: []) {
            title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count), withTemplate: "")
        }
        
        let isYouTube = title.contains("- YouTube") || url.contains("youtube.com") || url.contains("youtu.be")
        if isYouTube {
            title = title.replacingOccurrences(of: " - YouTube", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty || title == "YouTube" {
                return nil
            }
            return MediaTrack(
                title: title,
                artist: "YouTube",
                album: "Web Video",
                duration: 0,
                position: 0,
                isPlaying: true,
                source: .youtube,
                artworkData: nil
            )
        }
        
        let isNetflix = url.contains("netflix.com")
        let isTwitch = url.contains("twitch.tv")
        let isVimeo = url.contains("vimeo.com")
        
        let brandName: String = isNetflix ? "Netflix" : (isTwitch ? "Twitch" : (isVimeo ? "Vimeo" : "Web Video"))
        
        return MediaTrack(
            title: title.isEmpty ? brandName : title,
            artist: brandName,
            album: "Streaming Video",
            duration: 0,
            position: 0,
            isPlaying: true,
            source: .browser,
            artworkData: nil
        )
    }
    
    // MARK: - System-Wide MediaRemote
    private func fetchMediaRemoteTrack(completion: @escaping @Sendable (MediaTrack?) -> Void) {
        guard let getInfo = mrGetNowPlayingInfo else {
            completion(nil)
            return
        }
        
        getInfo(DispatchQueue.global(qos: .utility)) { dict in
            guard let dict = dict as? [String: Any] else {
                completion(nil)
                return
            }
            
            let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
            guard !title.isEmpty else {
                completion(nil)
                return
            }
            
            let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? "Now Playing"
            let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
            let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
            let position = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue ?? 0
            let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 1.0
            let artwork = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            let isPlaying = rate > 0.01
            
            var source: MediaSource = .mediaRemote
            if artist.lowercased().contains("youtube") || title.lowercased().contains("youtube") {
                source = .youtube
            } else if artist.lowercased().contains("spotify") {
                source = .spotify
            } else if artist.lowercased().contains("quicktime") {
                source = .quicktime
            }
            
            let track = MediaTrack(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                position: position,
                isPlaying: isPlaying,
                source: source,
                artworkData: artwork
            )
            completion(track)
        }
    }
    
    // MARK: - Playback Controls
    public func togglePlayPause() {
        SoundManager.shared.play(.click)
        
        switch currentTrack.source {
        case .music:
            _ = runAppleScript("tell application \"Music\" to playpause")
            refreshMedia()
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to playpause")
            refreshMedia()
        case .quicktime:
            let script = """
            tell application "QuickTime Player"
                if (count of documents) > 0 then
                    set doc to document 1
                    if playing of doc then
                        pause doc
                    else
                        play doc
                    end if
                end if
            end tell
            """
            _ = runAppleScript(script)
            refreshMedia()
        case .vlc:
            _ = runAppleScript("tell application \"VLC\" to play")
            refreshMedia()
        case .youtube, .browser, .mediaRemote:
            // Send system-wide Play/Pause media key
            sendSystemMediaKey(key: 16)
            currentTrack.isPlaying.toggle()
        case .demo:
            currentTrack.isPlaying.toggle()
        case .none:
            startDemoTrack()
        default:
            sendSystemMediaKey(key: 16)
        }
    }
    
    public func nextTrack() {
        SoundManager.shared.play(.click)
        switch currentTrack.source {
        case .music:
            _ = runAppleScript("tell application \"Music\" to next track")
            refreshMedia()
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to next track")
            refreshMedia()
        case .vlc:
            _ = runAppleScript("tell application \"VLC\" to next")
            refreshMedia()
        case .demo:
            cycleDemoTrack()
        default:
            // Send system-wide Next Track media key
            sendSystemMediaKey(key: 17)
        }
    }
    
    public func previousTrack() {
        SoundManager.shared.play(.click)
        switch currentTrack.source {
        case .music:
            _ = runAppleScript("tell application \"Music\" to previous track")
            refreshMedia()
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to previous track")
            refreshMedia()
        case .vlc:
            _ = runAppleScript("tell application \"VLC\" to previous")
            refreshMedia()
        case .demo:
            currentTrack.position = 0
        default:
            // Send system-wide Previous Track media key
            sendSystemMediaKey(key: 18)
        }
    }
    
    public func seek(to seconds: Double) {
        switch currentTrack.source {
        case .music:
            _ = runAppleScript("tell application \"Music\" to set player position to \(seconds)")
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(seconds)")
        case .quicktime:
            _ = runAppleScript("tell application \"QuickTime Player\" to set current time of document 1 to \(seconds)")
        default:
            currentTrack.position = seconds
        }
    }
    
    public func openMediaApp() {
        if isAppRunning(bundleId: "com.spotify.client") && currentTrack.source == .spotify {
            openApp(bundleId: "com.spotify.client")
        } else if isAppRunning(bundleId: "com.apple.Music") && currentTrack.source == .music {
            openApp(bundleId: "com.apple.Music")
        } else if isAppRunning(bundleId: "com.apple.QuickTimePlayerX") && currentTrack.source == .quicktime {
            openApp(bundleId: "com.apple.QuickTimePlayerX")
        } else if isAppRunning(bundleId: "org.videolan.vlc") && currentTrack.source == .vlc {
            openApp(bundleId: "org.videolan.vlc")
        } else if isAppRunning(bundleId: "com.google.Chrome") {
            openApp(bundleId: "com.google.Chrome")
        } else if isAppRunning(bundleId: "com.apple.Safari") {
            openApp(bundleId: "com.apple.Safari")
        } else {
            openApp(bundleId: "com.apple.Music")
        }
    }
    
    private func openApp(bundleId: String) {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
    
    // MARK: - Virtual System Media Keys
    private func sendSystemMediaKey(key: Int32) {
        func post(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? .init(rawValue: 0xa00) : .init(rawValue: 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            if let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                ev.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        post(down: true)
        post(down: false)
    }
    
    // MARK: - Demo Mode
    public func startDemoTrack() {
        currentTrack = MediaTrack(
            title: "Midnight City Lights",
            artist: "Synthwave Collective",
            album: "Neon Horizons",
            duration: 214,
            position: 45,
            isPlaying: true,
            source: .demo,
            artworkData: nil
        )
        
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.currentTrack.source == .demo, self.currentTrack.isPlaying else { return }
            if self.currentTrack.position < self.currentTrack.duration {
                self.currentTrack.position += 1
            } else {
                self.currentTrack.position = 0
            }
        }
    }
    
    private func cycleDemoTrack() {
        let songs = [
            ("Starboy", "The Weeknd ft. Daft Punk", "Starboy", 230.0),
            ("Blinding Lights", "The Weeknd", "After Hours", 200.0),
            ("Get Lucky", "Daft Punk ft. Pharrell", "Random Access Memories", 248.0),
            ("Midnight City Lights", "Synthwave Collective", "Neon Horizons", 214.0)
        ]
        let currentIdx = songs.firstIndex(where: { $0.0 == currentTrack.title }) ?? 0
        let nextIdx = (currentIdx + 1) % songs.count
        let next = songs[nextIdx]
        
        currentTrack = MediaTrack(
            title: next.0,
            artist: next.1,
            album: next.2,
            duration: next.3,
            position: 0,
            isPlaying: true,
            source: .demo,
            artworkData: nil
        )
    }
    
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let scriptObj = NSAppleScript(source: source) else { return nil }
        let output = scriptObj.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return output.stringValue
    }
}
