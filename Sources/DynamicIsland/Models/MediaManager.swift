import Foundation
import AppKit
import SwiftUI
import Combine
import CoreAudio

public struct MediaTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var position: Double
    public var isPlaying: Bool
    public var source: MediaSource
    public var artworkData: Data?
    public var url: String?
    
    public init(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        position: Double,
        isPlaying: Bool,
        source: MediaSource,
        artworkData: Data? = nil,
        url: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.source = source
        self.artworkData = artworkData
        self.url = url
    }
    
    public static var empty: MediaTrack {
        MediaTrack(
            title: "No Media Playing",
            artist: "Play audio or video from YouTube, Spotify, Music, or local players",
            album: "",
            duration: 0,
            position: 0,
            isPlaying: false,
            source: .none,
            artworkData: nil,
            url: nil
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
        case .none: return .white
        }
    }
}

// MARK: - CoreAudio System Audio Monitor
public final class AudioOutputMonitor: @unchecked Sendable {
    public static let shared = AudioOutputMonitor()
    
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private var listenerInstalled = false
    public var onPlaybackStateChanged: (@Sendable () -> Void)?
    
    private init() {
        updateDevice()
        setupListeners()
    }
    
    public func isAudioPlaying() -> Bool {
        if defaultOutputDeviceID == 0 || defaultOutputDeviceID == kAudioDeviceUnknown {
            updateDevice()
        }
        guard defaultOutputDeviceID != 0 && defaultOutputDeviceID != kAudioDeviceUnknown else { return false }
        
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &isRunning)
        if status != noErr {
            updateDevice()
            let retry = AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &isRunning)
            return retry == noErr && isRunning != 0
        }
        return isRunning != 0
    }
    
    private func updateDevice() {
        var devID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devID)
        if status == noErr {
            defaultOutputDeviceID = devID
        }
    }
    
    private func setupListeners() {
        guard !listenerInstalled, defaultOutputDeviceID != 0, defaultOutputDeviceID != kAudioDeviceUnknown else { return }
        
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let runBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.onPlaybackStateChanged?()
        }
        
        AudioObjectAddPropertyListenerBlock(defaultOutputDeviceID, &runAddress, DispatchQueue.main, runBlock)
        
        var devAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateDevice()
                self?.onPlaybackStateChanged?()
            }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddress, DispatchQueue.main, devBlock)
        
        listenerInstalled = true
    }
}

public enum MRPlaybackStatus: Sendable {
    case playing
    case paused
    case stopped
}

public class MediaManager: ObservableObject, @unchecked Sendable {
    public static let shared = MediaManager()
    
    @Published public var currentTrack: MediaTrack = .empty
    @Published public var playbackStatus: MRPlaybackStatus = .stopped
    @Published public var visualizerHeights: [CGFloat] = [0.2, 0.4, 0.7, 0.9, 0.6, 0.3, 0.5]
    @Published public var volume: Double = 0.75
    
    private var lastUserToggleTime: Date = .distantPast
    private var pollTimer: Timer?
    private var visualizerTimer: Timer?
    private var stateCheckTimer: DispatchSourceTimer?
    
    // MediaRemote function pointers
    private typealias MRGetNowPlayingInfoType = @convention(c) (DispatchQueue, @escaping @Sendable (CFDictionary?) -> Void) -> Void
    private typealias MRRegisterNotificationsType = @convention(c) (DispatchQueue) -> Void
    private typealias MRSendCommandType = @convention(c) (Int32, CFDictionary?) -> Bool
    private typealias MRGetPIDType = @convention(c) (DispatchQueue, @escaping @Sendable (pid_t) -> Void) -> Void
    private typealias MRGetIsPlayingType = @convention(c) (DispatchQueue, @escaping @Sendable (Bool) -> Void) -> Void
    private typealias MRGetPlaybackStateType = @convention(c) (DispatchQueue, @escaping @Sendable (UInt32) -> Void) -> Void
    
    private var mrGetNowPlayingInfo: MRGetNowPlayingInfoType?
    private var mrGetNowPlayingPID: MRGetPIDType?
    private var mrSendCommand: MRSendCommandType?
    private var mrGetIsPlaying: MRGetIsPlayingType?
    private var mrGetPlaybackState: MRGetPlaybackStateType?
    
    private var isRefreshing = false
    private var cachedWebTrack: MediaTrack?
    private var lastWebQueryTime: Date = .distantPast
    
    private init() {
        setupMediaRemote()
        setupDistributedNotifications()
        setupAudioMonitor()
        startPolling()
        startVisualizer()
    }
    
    private func setupAudioMonitor() {
        AudioOutputMonitor.shared.onPlaybackStateChanged = { [weak self] in
            self?.quickPlaybackStateCheck()
            self?.refreshMedia()
        }
    }
    
    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMedia()
        }
        
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMedia()
        }
    }
    
    // MARK: - MediaRemote Framework Bridge
    private func setupMediaRemote() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return
        }
        
        if let getInfoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            mrGetNowPlayingInfo = unsafeBitCast(getInfoSym, to: MRGetNowPlayingInfoType.self)
        }
        
        if let pidSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            mrGetNowPlayingPID = unsafeBitCast(pidSym, to: MRGetPIDType.self)
        }
        
        if let sendSym = dlsym(handle, "MRMediaRemoteSendCommand") {
            mrSendCommand = unsafeBitCast(sendSym, to: MRSendCommandType.self)
        }
        
        if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            mrGetIsPlaying = unsafeBitCast(isPlayingSym, to: MRGetIsPlayingType.self)
        }
        
        if let stateSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPlaybackState") {
            mrGetPlaybackState = unsafeBitCast(stateSym, to: MRGetPlaybackStateType.self)
        }
        
        if let registerSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFn = unsafeBitCast(registerSym, to: MRRegisterNotificationsType.self)
            registerFn(DispatchQueue.main)
            
            let notifications = [
                "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                "kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification",
                "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
            ]
            
            for notifName in notifications {
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name(notifName),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.handleMediaRemoteNotification()
                }
            }
        }
    }
    
    private func handleMediaRemoteNotification() {
        if let getIsPlaying = self.mrGetIsPlaying {
            getIsPlaying(DispatchQueue.main) { [weak self] isPlaying in
                guard let self = self else { return }
                if self.currentTrack.source != .none && self.currentTrack.isPlaying != isPlaying {
                    self.currentTrack.isPlaying = isPlaying
                }
            }
        }
        refreshMedia()
    }
    
    // MARK: - Polling & Visualizer
    public func startPolling() {
        startFastStateCheck()
        
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshMedia()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.refreshMedia()
        }
    }
    
    private func startFastStateCheck() {
        stateCheckTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(120), leeway: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            self?.quickPlaybackStateCheck()
        }
        timer.resume()
        stateCheckTimer = timer
    }
    
    private func quickPlaybackStateCheck() {
        guard Date().timeIntervalSince(lastUserToggleTime) >= 0.4 else { return }
        
        let newIsPlaying: Bool
        if let mrIsPlaying = getMRIsPlaying() {
            newIsPlaying = mrIsPlaying
        } else {
            let (mrPlaying, mrPaused) = getMRPlaybackState()
            if mrPlaying {
                newIsPlaying = true
            } else if mrPaused {
                newIsPlaying = false
            } else {
                newIsPlaying = AudioOutputMonitor.shared.isAudioPlaying()
            }
        }
        
        let currentIsPlaying = currentTrack.isPlaying
        
        if currentIsPlaying != newIsPlaying {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentTrack.isPlaying = newIsPlaying
                self.cachedWebTrack?.isPlaying = newIsPlaying
                self.playbackStatus = newIsPlaying ? .playing : .paused
                
                if newIsPlaying && self.currentTrack.source == .none {
                    self.refreshMedia()
                }
            }
        }
    }
    
    public func startVisualizer() {
        visualizerTimer?.invalidate()
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentTrack.isPlaying {
                self.visualizerHeights = (0..<7).map { _ in
                    CGFloat.random(in: 0.25...1.0)
                }
            } else {
                self.visualizerHeights = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15]
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }
    
    // MARK: - Multi-Tier Media Detection
    public func refreshMedia() {
        if isRefreshing { return }
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer { self.isRefreshing = false }
            
            let (mrPlaying, mrPaused) = self.getMRPlaybackState()
            let mrIsPlaying = self.getMRIsPlaying()
            let isAudioActive: Bool
            if let mr = mrIsPlaying {
                isAudioActive = mr
            } else if mrPlaying {
                isAudioActive = true
            } else if mrPaused {
                isAudioActive = false
            } else {
                isAudioActive = AudioOutputMonitor.shared.isAudioPlaying()
            }
            
            // Tier 1: Check Apple Music
            var musicTrack: MediaTrack? = nil
            if self.isAppRunning(bundleId: "com.apple.Music") {
                musicTrack = self.fetchAppleMusicTrack()
                if let track = musicTrack, track.isPlaying {
                    DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                    return
                }
            }
            
            // Tier 2: Check Spotify
            var spotifyTrack: MediaTrack? = nil
            if self.isAppRunning(bundleId: "com.spotify.client") {
                spotifyTrack = self.fetchSpotifyTrack()
                if let track = spotifyTrack, track.isPlaying {
                    DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                    return
                }
            }
            
            // Tier 3: Check Local Video Players (QuickTime, VLC)
            var quickTimeTrack: MediaTrack? = nil
            if self.isAppRunning(bundleId: "com.apple.QuickTimePlayerX") {
                quickTimeTrack = self.fetchQuickTimeTrack()
                if let track = quickTimeTrack, track.isPlaying {
                    DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                    return
                }
            }
            
            var vlcTrack: MediaTrack? = nil
            if self.isAppRunning(bundleId: "org.videolan.vlc") {
                vlcTrack = self.fetchVLCTrack()
                if let track = vlcTrack, track.isPlaying {
                    DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                    return
                }
            }
            
            // Tier 4: Check Web Browsers for YouTube & Web Video (Chrome, Safari, Brave, Arc, Edge)
            let webTrack = self.fetchWebVideoTrack(isAudioRunning: isAudioActive)
            if let track = webTrack, track.isPlaying {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            // Tier 5: None is actively playing. Prioritize paused media tracks:
            if let track = webTrack {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            if let track = spotifyTrack {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            if let track = musicTrack {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            if let track = quickTimeTrack {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            if let track = vlcTrack {
                DispatchQueue.main.async { self.applyTrackUpdate(track, mrPaused: mrPaused) }
                return
            }
            
            // Tier 6: System-wide NowPlaying via MediaRemote fallback
            self.fetchMediaRemoteTrack { [weak self] mrTrack in
                guard let self = self else { return }
                if let mrTrack = mrTrack {
                    DispatchQueue.main.async { self.applyTrackUpdate(mrTrack, mrPaused: mrPaused) }
                } else {
                    DispatchQueue.main.async {
                        self.applyTrackUpdate(.empty, mrPaused: mrPaused)
                    }
                }
            }
        }
    }
    
    private func applyTrackUpdate(_ track: MediaTrack, mrPaused: Bool) {
        self.currentTrack = track
        self.playbackStatus = track.isPlaying ? .playing : (mrPaused ? .paused : .stopped)
    }

    private final class PlaybackStateBox: @unchecked Sendable {
        var state: UInt32 = 0
    }

    private func getMRPlaybackState() -> (isPlaying: Bool, isPaused: Bool) {
        guard let getPlaybackState = mrGetPlaybackState else {
            return (false, false)
        }
        let sema = DispatchSemaphore(value: 0)
        let box = PlaybackStateBox()
        getPlaybackState(DispatchQueue.global(qos: .userInitiated)) { s in
            box.state = s
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 0.1)
        let s = box.state
        // 1 = Playing, 2 = Paused, 3 = Stopped
        return (s == 1, s == 2 || s == 3)
    }

    private final class IsPlayingBox: @unchecked Sendable {
        var val: Bool? = nil
    }

    private func getMRIsPlaying() -> Bool? {
        guard let getIsPlaying = mrGetIsPlaying else { return nil }
        let sema = DispatchSemaphore(value: 0)
        let box = IsPlayingBox()
        getIsPlaying(DispatchQueue.global(qos: .userInitiated)) { p in
            box.val = p
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 0.1)
        return box.val
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
    
    // MARK: - Web Browsers (YouTube & Web Video)
    private func fetchWebVideoTrack(isAudioRunning: Bool) -> MediaTrack? {
        let now = Date()
        if var cached = cachedWebTrack, now.timeIntervalSince(lastWebQueryTime) < 1.2 {
            cached.isPlaying = isAudioRunning
            return cached
        }
        
        let mediaKeywords = ["youtube.com", "youtu.be", "netflix.com", "twitch.tv", "vimeo.com", "soundcloud.com", "bilibili.com", "spotify.com"]
        
        var track: MediaTrack? = nil
        
        // 1. Google Chrome
        if isAppRunning(bundleId: "com.google.Chrome") {
            track = queryChromiumBrowser(appName: "Google Chrome", keywords: mediaKeywords, isAudioRunning: isAudioRunning)
        }
        
        // 2. Safari
        if track == nil && isAppRunning(bundleId: "com.apple.Safari") {
            track = querySafariBrowser(keywords: mediaKeywords, isAudioRunning: isAudioRunning)
        }
        
        // 3. Brave Browser
        if track == nil && isAppRunning(bundleId: "com.brave.Browser") {
            track = queryChromiumBrowser(appName: "Brave Browser", keywords: mediaKeywords, isAudioRunning: isAudioRunning)
        }
        
        // 4. Arc Browser
        if track == nil && isAppRunning(bundleId: "company.thebrowser.Browser") {
            track = queryChromiumBrowser(appName: "Arc", keywords: mediaKeywords, isAudioRunning: isAudioRunning)
        }
        
        // 5. Microsoft Edge
        if track == nil && isAppRunning(bundleId: "com.microsoft.edgemac") {
            track = queryChromiumBrowser(appName: "Microsoft Edge", keywords: mediaKeywords, isAudioRunning: isAudioRunning)
        }
        
        if let found = track {
            cachedWebTrack = found
            lastWebQueryTime = now
            return found
        } else {
            cachedWebTrack = nil
            return nil
        }
    }

    private func queryChromiumBrowser(appName: String, keywords: [String], isAudioRunning: Bool) -> MediaTrack? {
        let conditions = keywords.map { "URL of t contains \"\($0)\"" }.joined(separator: " or ")
        let script = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                try
                    set t to active tab of front window
                    if \(conditions) then
                        return (title of t) & "|||" & (URL of t)
                    end if
                end try
                repeat with w in windows
                    set m to (every tab of w whose \(conditions))
                    if (count of m) > 0 then
                        set t to item 1 of m
                        return (title of t) & "|||" & (URL of t)
                    end if
                end repeat
            end if
            return ""
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
        return parseWebVideoOutput(output, isAudioRunning: isAudioRunning)
    }

    private func querySafariBrowser(keywords: [String], isAudioRunning: Bool) -> MediaTrack? {
        let conditions = keywords.map { "URL of t contains \"\($0)\"" }.joined(separator: " or ")
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                try
                    set t to current tab of front window
                    if \(conditions) then
                        return (name of t) & "|||" & (URL of t)
                    end if
                end try
                repeat with w in windows
                    set m to (every tab of w whose \(conditions))
                    if (count of m) > 0 then
                        set t to item 1 of m
                        return (name of t) & "|||" & (URL of t)
                    end if
                end repeat
            end if
            return ""
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
        return parseWebVideoOutput(output, isAudioRunning: isAudioRunning)
    }

    private func parseWebVideoOutput(_ raw: String, isAudioRunning: Bool) -> MediaTrack? {
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        
        var title = parts[0]
        let url = parts[1]
        
        // Clean title prefixes like "(1) ", "▶ ", "[Playing] ", etc.
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
                isPlaying: isAudioRunning,
                source: .youtube,
                artworkData: nil,
                url: url
            )
        }
        
        if url.contains("netflix.com") {
            return MediaTrack(
                title: title.isEmpty ? "Netflix Video" : title,
                artist: "Netflix",
                album: "Streaming",
                duration: 0,
                position: 0,
                isPlaying: isAudioRunning,
                source: .browser,
                artworkData: nil,
                url: url
            )
        }
        
        if url.contains("twitch.tv") {
            return MediaTrack(
                title: title.isEmpty ? "Twitch Stream" : title,
                artist: "Twitch",
                album: "Live Stream",
                duration: 0,
                position: 0,
                isPlaying: isAudioRunning,
                source: .browser,
                artworkData: nil,
                url: url
            )
        }
        
        return MediaTrack(
            title: title.isEmpty ? "Web Video" : title,
            artist: "Web Browser",
            album: "Online Media",
            duration: 0,
            position: 0,
            isPlaying: isAudioRunning,
            source: .browser,
            artworkData: nil,
            url: url
        )
    }

    // MARK: - System-Wide MediaRemote
    private func fetchMediaRemoteTrack(completion: @escaping @Sendable (MediaTrack?) -> Void) {
        guard let getInfo = mrGetNowPlayingInfo else {
            completion(nil)
            return
        }
        
        getInfo(DispatchQueue.global(qos: .utility)) { [weak self] dict in
            guard let self = self, let dict = dict as? [String: Any] else {
                completion(nil)
                return
            }
            
            let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
            guard !title.isEmpty else {
                completion(nil)
                return
            }
            
            let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
            let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
            let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
            let position = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue ?? 0
            let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0.0
            let artwork = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            let isPlaying = rate > 0.01 || AudioOutputMonitor.shared.isAudioPlaying()
            
            if let getPID = self.mrGetNowPlayingPID {
                getPID(DispatchQueue.global(qos: .utility)) { [weak self] pid in
                    let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
                    let track = self?.buildMediaRemoteTrack(
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        position: position,
                        isPlaying: isPlaying,
                        artwork: artwork,
                        bundleId: bundleId
                    )
                    completion(track)
                }
            } else {
                let track = self.buildMediaRemoteTrack(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    position: position,
                    isPlaying: isPlaying,
                    artwork: artwork,
                    bundleId: ""
                )
                completion(track)
            }
        }
    }
    
    private func buildMediaRemoteTrack(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        position: Double,
        isPlaying: Bool,
        artwork: Data?,
        bundleId: String
    ) -> MediaTrack {
        var finalArtist = artist
        var source: MediaSource = .mediaRemote
        
        if bundleId == "com.apple.Music" {
            source = .music
        } else if bundleId == "com.spotify.client" {
            source = .spotify
        } else if bundleId == "com.apple.QuickTimePlayerX" {
            source = .quicktime
        } else if bundleId == "org.videolan.vlc" {
            source = .vlc
        } else {
            let isBrowser = bundleId.contains("Chrome") || bundleId.contains("Safari") || bundleId.contains("Brave") || bundleId.contains("Arc") || bundleId.contains("Edge")
            let isYouTube = artist.lowercased().contains("youtube") || title.lowercased().contains("youtube")
            
            if isYouTube {
                source = .youtube
                if finalArtist.isEmpty {
                    finalArtist = "YouTube"
                }
            } else if isBrowser {
                source = .browser
            }
        }
        
        if finalArtist.isEmpty {
            finalArtist = "Now Playing"
        }
        
        return MediaTrack(
            title: title,
            artist: finalArtist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            source: source,
            artworkData: artwork
        )
    }
    
    // MARK: - Playback Controls
    // MediaRemote Command Constants (from Apple's private MediaRemote framework)
    public enum MRCommand: Int32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }

    @discardableResult
    public func sendMediaRemoteCommand(_ command: Int32) -> Bool {
        if let mrSendCommand = mrSendCommand {
            return mrSendCommand(command, nil)
        }
        return false
    }

    public func togglePlayPause() {
        SoundManager.shared.play(.click)
        
        var handled = false
        switch currentTrack.source {
        case .music:
            if runAppleScript("tell application \"Music\" to playpause") != nil {
                handled = true
            }
        case .spotify:
            if runAppleScript("tell application \"Spotify\" to playpause") != nil {
                handled = true
            }
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
            if runAppleScript(script) != nil {
                handled = true
            }
        case .vlc:
            if runAppleScript("tell application \"VLC\" to play") != nil {
                handled = true
            }
        default:
            break
        }
        
        let willPlay = !currentTrack.isPlaying
        if !handled {
            let cmd: Int32 = willPlay ? MRCommand.play.rawValue : MRCommand.pause.rawValue
            if !sendMediaRemoteCommand(cmd) {
                _ = sendMediaRemoteCommand(MRCommand.togglePlayPause.rawValue)
                sendSystemMediaKey(key: 16)
            }
        }
        
        lastUserToggleTime = Date()
        currentTrack.isPlaying = willPlay
        cachedWebTrack?.isPlaying = willPlay
        playbackStatus = willPlay ? .playing : .paused
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshMedia()
        }
    }
    
    public func nextTrack() {
        SoundManager.shared.play(.click)
        var handled = false
        switch currentTrack.source {
        case .music:
            if runAppleScript("tell application \"Music\" to next track") != nil {
                handled = true
            }
        case .spotify:
            if runAppleScript("tell application \"Spotify\" to next track") != nil {
                handled = true
            }
        case .vlc:
            if runAppleScript("tell application \"VLC\" to next") != nil {
                handled = true
            }
        default:
            break
        }
        
        // 4 = Next Track in MediaRemote (command 3 is kMRStop!)
        if !handled {
            if !sendMediaRemoteCommand(MRCommand.nextTrack.rawValue) {
                sendSystemMediaKey(key: 17)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshMedia()
        }
    }
    
    public func previousTrack() {
        SoundManager.shared.play(.click)
        var handled = false
        switch currentTrack.source {
        case .music:
            if runAppleScript("tell application \"Music\" to previous track") != nil {
                handled = true
            }
        case .spotify:
            if runAppleScript("tell application \"Spotify\" to previous track") != nil {
                handled = true
            }
        case .vlc:
            if runAppleScript("tell application \"VLC\" to previous") != nil {
                handled = true
            }
        default:
            break
        }
        
        // 5 = Previous Track in MediaRemote (command 4 is kMRNextTrack!)
        if !handled {
            if !sendMediaRemoteCommand(MRCommand.previousTrack.rawValue) {
                sendSystemMediaKey(key: 18)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshMedia()
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
    
    public func openMediaPage() {
        SoundManager.shared.play(.click)
        
        // 1. If we have a web URL, focus that tab in the running browser or open the URL
        if let urlStr = currentTrack.url, !urlStr.isEmpty {
            if isAppRunning(bundleId: "com.google.Chrome") && focusBrowserTab(appName: "Google Chrome", urlPattern: urlStr) {
                return
            }
            if isAppRunning(bundleId: "com.apple.Safari") && focusBrowserTab(appName: "Safari", urlPattern: urlStr) {
                return
            }
            if isAppRunning(bundleId: "com.brave.Browser") && focusBrowserTab(appName: "Brave Browser", urlPattern: urlStr) {
                return
            }
            if isAppRunning(bundleId: "company.thebrowser.Browser") && focusBrowserTab(appName: "Arc", urlPattern: urlStr) {
                return
            }
            if isAppRunning(bundleId: "com.microsoft.edgemac") && focusBrowserTab(appName: "Microsoft Edge", urlPattern: urlStr) {
                return
            }
            if let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // 2. Fall back to opening the native app
        openMediaApp()
    }
    
    private func focusBrowserTab(appName: String, urlPattern: String) -> Bool {
        let safePattern = urlPattern.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        if appName == "Safari" {
            script = """
            tell application "Safari"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "\(safePattern)" then
                            set current tab of w to t
                            set index of w to 1
                            return "ok"
                        end if
                    end repeat
                end repeat
                return "not_found"
            end tell
            """
        } else {
            script = """
            tell application "\(appName)"
                activate
                repeat with w in windows
                    set tabIdx to 0
                    repeat with t in tabs of w
                        set tabIdx to tabIdx + 1
                        if URL of t contains "\(safePattern)" then
                            set active tab index of w to tabIdx
                            set index of w to 1
                            return "ok"
                        end if
                    end repeat
                end repeat
                return "not_found"
            end tell
            """
        }
        
        let res = runAppleScript(script)
        return res?.contains("ok") == true
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
                ev.cgEvent?.post(tap: .cgSessionEventTap)
            }
        }
        post(down: true)
        post(down: false)
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
