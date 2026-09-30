import Foundation
import AppKit
import Combine

public struct MediaTrack: Equatable {
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
            artist: "Tap to play from Apple Music or Spotify",
            album: "",
            duration: 0,
            position: 0,
            isPlaying: false,
            source: .none,
            artworkData: nil
        )
    }
}

public enum MediaSource: String {
    case music = "Apple Music"
    case spotify = "Spotify"
    case demo = "Demo Player"
    case none = "None"
    
    public var iconName: String {
        switch self {
        case .music: return "apple.logo"
        case .spotify: return "antenna.radiowaves.left.and.right"
        case .demo: return "sparkles"
        case .none: return "music.note"
        }
    }
}

public class MediaManager: ObservableObject {
    public static let shared = MediaManager()
    
    @Published public var currentTrack: MediaTrack = .empty
    @Published public var visualizerHeights: [CGFloat] = [0.2, 0.4, 0.7, 0.9, 0.6, 0.3, 0.5]
    @Published public var volume: Double = 0.75
    
    private var pollTimer: Timer?
    private var visualizerTimer: Timer?
    private var demoTimer: Timer?
    
    private init() {
        startPolling()
        startVisualizer()
    }
    
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
                // Generate dynamic lively wave peaks
                self.visualizerHeights = (0..<7).map { _ in
                    CGFloat.random(in: 0.25...1.0)
                }
            } else {
                self.visualizerHeights = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15]
            }
        }
    }
    
    public func refreshMedia() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // First check Apple Music
            if self.isAppRunning(bundleId: "com.apple.Music") {
                if let track = self.fetchAppleMusicTrack() {
                    DispatchQueue.main.async {
                        self.currentTrack = track
                    }
                    return
                }
            }
            
            // Next check Spotify
            if self.isAppRunning(bundleId: "com.spotify.client") {
                if let track = self.fetchSpotifyTrack() {
                    DispatchQueue.main.async {
                        self.currentTrack = track
                    }
                    return
                }
            }
            
            // If neither is actively playing and current track is not demo, set empty
            DispatchQueue.main.async {
                if self.currentTrack.source != .demo && self.currentTrack.isPlaying {
                    self.currentTrack = .empty
                }
            }
        }
    }
    
    private func isAppRunning(bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
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
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let pos = Double(parts[4]) ?? 0
        let dur = Double(parts[5]) ?? 0
        
        return MediaTrack(
            title: title.isEmpty ? "Unknown Title" : title,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            duration: dur,
            position: pos,
            isPlaying: isPlaying,
            source: .music,
            artworkData: nil
        )
    }
    
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
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let pos = Double(parts[4]) ?? 0
        let dur = Double(parts[5]) ?? 0
        
        return MediaTrack(
            title: title.isEmpty ? "Unknown Title" : title,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            duration: dur,
            position: pos,
            isPlaying: isPlaying,
            source: .spotify,
            artworkData: nil
        )
    }
    
    public func togglePlayPause() {
        SoundManager.shared.play(.click)
        if currentTrack.source == .music {
            _ = runAppleScript("tell application \"Music\" to playpause")
            refreshMedia()
        } else if currentTrack.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to playpause")
            refreshMedia()
        } else if currentTrack.source == .demo {
            currentTrack.isPlaying.toggle()
        } else {
            // Start demo mode if neither music app is active
            startDemoTrack()
        }
    }
    
    public func nextTrack() {
        SoundManager.shared.play(.click)
        if currentTrack.source == .music {
            _ = runAppleScript("tell application \"Music\" to next track")
            refreshMedia()
        } else if currentTrack.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to next track")
            refreshMedia()
        } else if currentTrack.source == .demo {
            cycleDemoTrack()
        }
    }
    
    public func previousTrack() {
        SoundManager.shared.play(.click)
        if currentTrack.source == .music {
            _ = runAppleScript("tell application \"Music\" to previous track")
            refreshMedia()
        } else if currentTrack.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to previous track")
            refreshMedia()
        } else if currentTrack.source == .demo {
            currentTrack.position = 0
        }
    }
    
    public func seek(to seconds: Double) {
        if currentTrack.source == .music {
            _ = runAppleScript("tell application \"Music\" to set player position to \(seconds)")
        } else if currentTrack.source == .spotify {
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(seconds)")
        } else {
            currentTrack.position = seconds
        }
    }
    
    public func openMediaApp() {
        let bundleId = isAppRunning(bundleId: "com.spotify.client") ? "com.spotify.client" : "com.apple.Music"
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
    
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
