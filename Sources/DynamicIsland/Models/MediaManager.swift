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
    public var bundleIdentifier: String?
    
    public init(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        position: Double,
        isPlaying: Bool,
        source: MediaSource,
        artworkData: Data? = nil,
        url: String? = nil,
        bundleIdentifier: String? = nil
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
        self.bundleIdentifier = bundleIdentifier
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
            url: nil,
            bundleIdentifier: nil
        )
    }

    /// Whether this track represents "no media at all".
    ///
    /// This is the single definition of emptiness, and it is the *source*, not the
    /// title, that decides. It previously was a string comparison against the
    /// literal `"No Media Playing"`, which made a user-visible English caption
    /// load-bearing control flow in three separate files: a real track genuinely
    /// titled "No Media Playing" would be suppressed, and re-wording the empty-state
    /// copy would have silently broken the compact ear and the playback-state guard.
    /// The caption is now free to change without touching behaviour.
    public var isEmpty: Bool { source == .none }
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
    private var currentListenedDeviceID: AudioDeviceID = 0
    private var runBlock: AudioObjectPropertyListenerBlock?
    /// The system-wide default-output-device listener, retained so it can be removed.
    /// The per-device `runBlock` above was already removed on device change; this one
    /// was registered once in `init` and never unregistered.
    private var systemBlock: AudioObjectPropertyListenerBlock?
    public var onPlaybackStateChanged: (@Sendable () -> Void)?

    private init() {
        setupSystemListener()
        updateDevice()
    }

    deinit {
        var devAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let systemBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &devAddress, DispatchQueue.main, systemBlock
            )
        }
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if currentListenedDeviceID != 0, let runBlock {
            AudioObjectRemovePropertyListenerBlock(
                currentListenedDeviceID, &runAddress, DispatchQueue.main, runBlock
            )
        }
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
        if status == noErr && devID != 0 && devID != kAudioDeviceUnknown {
            defaultOutputDeviceID = devID
            attachDeviceListener(to: devID)
        }
    }
    
    private func setupSystemListener() {
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
        self.systemBlock = devBlock
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddress, DispatchQueue.main, devBlock)
    }
    
    private func attachDeviceListener(to newDeviceID: AudioDeviceID) {
        guard newDeviceID != currentListenedDeviceID else { return }
        
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if currentListenedDeviceID != 0, let oldBlock = runBlock {
            AudioObjectRemovePropertyListenerBlock(currentListenedDeviceID, &runAddress, DispatchQueue.main, oldBlock)
        }
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.onPlaybackStateChanged?()
        }
        self.runBlock = block
        self.currentListenedDeviceID = newDeviceID
        
        AudioObjectAddPropertyListenerBlock(newDeviceID, &runAddress, DispatchQueue.main, block)
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
    @Published public var visualizerHeights: [CGFloat] = MediaManager.visualizerIdlePattern
    /// Rotation offset for the equalizer's wave pattern. See `startVisualizer()` —
    /// these are not audio levels, and deliberately so.
    private var visualizerPhase = 0
    @Published public var volume: Double = 0.75
    
    private var lastUserToggleTime: Date = .distantPast
    private let userToggleCooldown: TimeInterval = 1.2
    private var lastPositionUpdateTime: Date = Date()
    private var pollTimer: Timer?
    private var visualizerTimer: Timer?
    
    /// Debounce counter: how many consecutive poll cycles have reported isPlaying=false.
    /// We require multiple consecutive false readings before flipping the UI state to
    /// prevent flicker caused by transient MediaRemote timeouts during video playback.
    private var playingFalseStreak: Int = 0
    private let playingFalseThreshold: Int = 3
    
    /// Debounce counter: how many consecutive refresh cycles have returned no track.
    /// We require multiple consecutive empty results before dropping an active track to avoid flicker.
    private var emptyTrackStreak: Int = 0
    private let emptyTrackThreshold: Int = 3
    
    // MediaRemote function pointers
    private typealias MRGetNowPlayingInfoType = @convention(c) (DispatchQueue, @escaping @Sendable (CFDictionary?) -> Void) -> Void
    private typealias MRRegisterNotificationsType = @convention(c) (DispatchQueue) -> Void
    private typealias MRSendCommandType = @convention(c) (Int32, CFDictionary?) -> Bool
    private typealias MRGetPIDType = @convention(c) (DispatchQueue, @escaping @Sendable (pid_t) -> Void) -> Void
    private typealias MRGetIsPlayingType = @convention(c) (DispatchQueue, @escaping @Sendable (Bool) -> Void) -> Void
    private typealias MRGetPlaybackStateType = @convention(c) (DispatchQueue, @escaping @Sendable (UInt32) -> Void) -> Void
    private typealias MRSetElapsedType = @convention(c) (Double) -> Void
    
    private var mrGetNowPlayingInfo: MRGetNowPlayingInfoType?
    private var mrGetNowPlayingPID: MRGetPIDType?
    private var mrSendCommand: MRSendCommandType?
    private var mrGetIsPlaying: MRGetIsPlayingType?
    private var mrGetPlaybackState: MRGetPlaybackStateType?
    private var mrSetElapsedTime: MRSetElapsedType?
    
    private var isRefreshing = false
    private var cachedWebTrack: MediaTrack?
    private var lastWebQueryTime: Date = .distantPast

    /// Tokens for the block-based distributed-notification observers registered in
    /// `setupDistributedNotifications`, plus the `NotificationCenter` observers
    /// installed by the MediaRemote bridge. Held so `deinit` can unregister them.
    private var observationTokens: [any NSObjectProtocol] = []

    /// Tokens for the *local* `NotificationCenter` observers registered by the
    /// MediaRemote bridge. Kept separate because the removal call targets a
    /// different centre than the distributed ones.
    private var mediaRemoteNotificationTokens: [any NSObjectProtocol] = []
    
    private init() {
        setupMediaRemote()
        setupDistributedNotifications()
        setupAudioMonitor()
        startPolling()
        startVisualizer()
    }

    deinit {
        DistributedObservationTokens.remove(observationTokens)
        for token in mediaRemoteNotificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        mediaRemoteNotificationTokens = []
        pollTimer?.invalidate()
        visualizerTimer?.invalidate()
    }
    
    private func setupAudioMonitor() {
        AudioOutputMonitor.shared.onPlaybackStateChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.quickPlaybackStateCheck()
                self?.refreshMedia()
            }
        }
    }
    
    private func setupDistributedNotifications() {
        observationTokens = DistributedObservationTokens.observe([
            "com.apple.Music.playerInfo": { [weak self] _ in
                self?.refreshMedia()
            },
            "com.spotify.client.PlaybackStateChanged": { [weak self] _ in
                self?.refreshMedia()
            },
        ])
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
        
        if let setElapsedSym = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            mrSetElapsedTime = unsafeBitCast(setElapsedSym, to: MRSetElapsedType.self)
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
                let token = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name(notifName),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.handleMediaRemoteNotification()
                }
                mediaRemoteNotificationTokens.append(token)
            }
        }
    }
    
    private func handleMediaRemoteNotification() {
        refreshMedia()
    }
    
    // MARK: - Polling & Visualizer
    public func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateLivePosition()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.quickPlaybackStateCheck()
                self?.refreshMedia()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.refreshMedia()
        }
    }
    
    /// Smoothly advances the elapsed time counter and progress scrubber while playing
    private func updateLivePosition() {
        let now = Date()
        let delta = now.timeIntervalSince(lastPositionUpdateTime)
        lastPositionUpdateTime = now
        
        if currentTrack.isPlaying && currentTrack.duration > 0 && delta > 0 && delta < 3.0 {
            currentTrack.position = min(currentTrack.duration, currentTrack.position + delta)
        }
    }
    
    private func quickPlaybackStateCheck() {
        guard Date().timeIntervalSince(lastUserToggleTime) >= userToggleCooldown else { return }
        
        // Do not flip isPlaying to true if there is no actual active media track!
        guard !currentTrack.isEmpty else {
            if currentTrack.isPlaying {
                DispatchQueue.main.async { [weak self] in
                    self?.currentTrack.isPlaying = false
                    self?.playbackStatus = .stopped
                }
            }
            return
        }
        
        let (newIsPlaying, isPaused) = checkPlaybackState(rate: nil)
        let currentIsPlaying = currentTrack.isPlaying
        
        if newIsPlaying {
            // Immediately apply playing state & reset debounce streak
            playingFalseStreak = 0
            if !currentIsPlaying {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentTrack.isPlaying = true
                    self.cachedWebTrack?.isPlaying = true
                    self.playbackStatus = .playing
                }
            }
        } else if currentIsPlaying {
            // Debounce: require multiple consecutive not-playing readings before flipping
            playingFalseStreak += 1
            if playingFalseStreak >= playingFalseThreshold {
                playingFalseStreak = 0
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentTrack.isPlaying = false
                    self.cachedWebTrack?.isPlaying = false
                    self.playbackStatus = isPaused ? .paused : .stopped
                }
            }
        }
    }
    
    public func startVisualizer() {
        visualizerTimer?.invalidate()
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // NB: these heights are NOT audio levels.
            //
            // This used to be `CGFloat.random(in: 0.25...1.0)` while playing, which
            // fabricated system state: the island showed a live-looking equalizer
            // that was pure noise, implying it was reading the audio stream when it
            // was reading nothing. docs/DESIGN.md §7 is explicit that production code
            // reflects reality and that no simulated stand-ins ship for a capability
            // the app does not have.
            //
            // Real output metering is genuinely unavailable here, and deliberately so:
            // the public level-meter selector is not exported by the SDK
            // (`kAudioDevicePropertyDeviceLevelMeterScalar` does not exist in any
            // public header), and the only supported route would be a private symbol
            // via `dlsym` — the same fragility as the MediaRemote bridge, for a
            // cosmetic animation. The project has zero third-party dependencies and
            // adds none for this.
            //
            // So the equalizer now animates a fixed, gentle, honest pattern driven
            // only by whether audio is actually playing. It reads as "audio is
            // playing", which is true, and claims nothing about levels. If real
            // metering is ever wanted, this is the single place to change.
            let isPlaying = self.currentTrack.isPlaying
            let phase = self.visualizerPhase
            self.visualizerPhase = (phase + 1) % 6
            self.visualizerHeights = isPlaying
                ? (0..<7).map { Self.visualizerPattern[($0 + phase) % Self.visualizerPattern.count] }
                : Self.visualizerIdlePattern
        }
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }

    /// Rotating bar heights, in 0...1. A fixed pattern, not a random one, so the
    /// animation is a repeating wave rather than noise.
    private static let visualizerPattern: [CGFloat] = [0.35, 0.55, 0.75, 1.0, 0.75, 0.55]
    private static let visualizerIdlePattern: [CGFloat] = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15]
    
    // MARK: - Multi-Tier Media Detection (MediaRemote Primary)
    public func refreshMedia() {
        if isRefreshing { return }
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Tier 1: System-wide NowPlaying via MediaRemote (Primary source of truth for macOS)
            self.fetchMediaRemoteTrack { [weak self] mrTrack in
                guard let self = self else { return }
                if let track = mrTrack {
                    DispatchQueue.main.async {
                        self.emptyTrackStreak = 0
                        self.applyTrackUpdate(track)
                        self.isRefreshing = false
                    }
                    return
                }
                
                // Tiers 2-4: query each desktop app directly, in `DesktopMediaApp`
                // order. This was five hand-written blocks that each named a bundle
                // id and called its own `fetch…Track()` wrapper — the same order,
                // the same shape, the same three lines of `DispatchQueue.main`
                // boilerplate, restated per app. The wrappers existed only to hide
                // the argument, and the ids were a fourth copy of the registry.
                //
                // Order matters and is unchanged: Music, then Spotify, then the
                // document players. It is a policy, not an alphabetical accident, so
                // it lives in one list that `DesktopMediaAppTests` can pin.
                for app in DesktopMediaApp.allCases {
                    guard self.isAppRunning(bundleId: app.bundleIdentifier) else { continue }
                    guard let desktopTrack = self.fetchDesktopAppTrack(app) else { continue }
                    DispatchQueue.main.async {
                        self.emptyTrackStreak = 0
                        self.applyTrackUpdate(desktopTrack)
                        self.isRefreshing = false
                    }
                    return
                }
                
                // Tier 5: Browser active media tab fallback
                let isAudioRunning = AudioOutputMonitor.shared.isAudioPlaying()
                if let webTrack = self.fetchWebVideoTrack(isAudioRunning: isAudioRunning) {
                    DispatchQueue.main.async {
                        self.emptyTrackStreak = 0
                        self.applyTrackUpdate(webTrack)
                        self.isRefreshing = false
                    }
                    return
                }
                
                // Tier 6: No media active anywhere
                DispatchQueue.main.async {
                    // If audio is actively playing through the system or track is marked playing,
                    // debounce transitioning to .empty to avoid flicker on transient metadata misses.
                    if self.currentTrack.source != .none && (isAudioRunning || self.currentTrack.isPlaying) {
                        self.emptyTrackStreak += 1
                        if self.emptyTrackStreak < self.emptyTrackThreshold {
                            self.isRefreshing = false
                            return
                        }
                    }
                    self.emptyTrackStreak = 0
                    self.applyTrackUpdate(.empty)
                    self.isRefreshing = false
                }
            }
        }
    }
    
    private func applyTrackUpdate(_ track: MediaTrack) {
        let isUserCooldown = Date().timeIntervalSince(lastUserToggleTime) < userToggleCooldown
        
        if self.currentTrack.title != track.title || self.currentTrack.source != track.source {
            self.currentTrack = track
            if isUserCooldown {
                self.currentTrack.isPlaying = (self.playbackStatus == .playing)
            }
            self.lastPositionUpdateTime = Date()
        } else {
            // Track title & source unchanged: update state smoothly without flickering view
            if !isUserCooldown {
                if track.isPlaying && !self.currentTrack.isPlaying {
                    // Going from paused → playing: apply immediately
                    self.currentTrack.isPlaying = true
                    playingFalseStreak = 0
                } else if !track.isPlaying && self.currentTrack.isPlaying {
                    // Going from playing → paused: let debounce handle it (don't flip here)
                    // quickPlaybackStateCheck will confirm after consecutive readings
                } else {
                    // No change — just reset streak if still playing
                    if track.isPlaying { playingFalseStreak = 0 }
                }
            }
            if !isUserCooldown && abs(self.currentTrack.position - track.position) > 1.5 {
                self.currentTrack.position = track.position
                self.lastPositionUpdateTime = Date()
            }
            if self.currentTrack.duration != track.duration {
                self.currentTrack.duration = track.duration
            }
            if self.currentTrack.artworkData != track.artworkData {
                self.currentTrack.artworkData = track.artworkData
            }
            if self.currentTrack.bundleIdentifier != track.bundleIdentifier {
                self.currentTrack.bundleIdentifier = track.bundleIdentifier
            }
            if self.currentTrack.url != track.url && track.url != nil {
                self.currentTrack.url = track.url
            }
        }
        
        if track.source == .none {
            self.playbackStatus = .stopped
        } else {
            self.playbackStatus = self.currentTrack.isPlaying ? .playing : .paused
        }
    }

    private func checkPlaybackState(rate: Double?) -> (isPlaying: Bool, isPaused: Bool) {
        let (mrPlaying, mrPaused) = getMRPlaybackState()
        let mrIsPlaying = getMRIsPlaying() ?? false
        let ratePlaying = (rate ?? 0.0) > 0.01
        let audioRunning = AudioOutputMonitor.shared.isAudioPlaying()
        
        // 1. Explicit positive playing indicators
        if ratePlaying || mrPlaying || mrIsPlaying {
            return (isPlaying: true, isPaused: false)
        }
        
        // 2. Explicit paused indicators from MediaRemote
        if mrPaused || (rate != nil && rate == 0.0) {
            return (isPlaying: false, isPaused: true)
        }
        
        // 3. CoreAudio hardware output running (fallback when MediaRemote has no explicit state)
        if audioRunning {
            return (isPlaying: true, isPaused: false)
        }
        
        return (isPlaying: false, isPaused: mrPaused)
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
        _ = sema.wait(timeout: .now() + 0.08)
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
        _ = sema.wait(timeout: .now() + 0.08)
        return box.val
    }
    
    private func isAppRunning(bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    // MARK: - Desktop Player Adapters
    //
    // All four direct-query adapters are the same shape: run this app's script,
    // parse the delimited response. The differences (app name, unit conversion,
    // fallback strings, script vocabulary) are data on `DesktopMediaApp`, and the
    // parsing is a pure function there, so this is the only place the two concerns
    // meet. See `DesktopMediaApp` for why the duration scaling had to move out of
    // the script text.
    private func fetchDesktopAppTrack(_ app: DesktopMediaApp) -> MediaTrack? {
        guard let output = runAppleScript(app.script), !output.isEmpty else { return nil }
        return DesktopMediaApp.parse(output: output, app: app)
    }

    /// Which desktop app, if any, a track came from.
    ///
    /// This replaces a chain that appeared **ten times** across the three control
    /// methods:
    ///
    ///     if currentTrack.source == .music || currentTrack.bundleIdentifier == "com.apple.Music" { … }
    ///     else if currentTrack.source == .spotify || currentTrack.bundleIdentifier == "com.spotify.client" { … }
    ///     …
    ///
    /// Every one of those ten branches was a hand-maintained copy of the same
    /// mapping, and the `||` made the lookup a *guess* — it accepted a track that
    /// claimed `source == .music` even when its bundle id said Spotify, and sent
    /// Music's `next track` to Spotify. The two fields disagree in practice: a
    /// track from a browser carries `.youtube` or `.browser`, while a track read
    /// from a desktop app carries that app's bundle id.
    ///
    /// Resolution is by bundle id first and source second. Matching on the id alone
    /// means a wrong source can no longer be sent the wrong app's command.
    private var owningApp: DesktopMediaApp? {
        Self.desktopAppOwning(source: currentTrack.source, bundleIdentifier: currentTrack.bundleIdentifier)
    }

    /// The pure form of `owningApp`, so the policy is testable without a live track.
    ///
    /// Bundle id is authoritative because it is what the OS actually reported; the
    /// source is only consulted when the id is absent or unrecognised, which
    /// happens for MediaRemote-sourced tracks that never carried a bundle id.
    ///
    /// `internal` rather than `private` specifically so `MediaManagerTests` can pin
    /// the id-wins rule without a running app or a live `MediaRemote` pointer —
    /// which is the whole point of extracting it.
    static func desktopAppOwning(
        source: MediaSource,
        bundleIdentifier: String?
    ) -> DesktopMediaApp? {
        // Three cases, in order, and the distinction between the last two matters:
        //
        // 1. A recognised bundle id names the app. Authoritative, because the id is
        //    what the OS actually reported.
        // 2. No id at all means nothing was reported, so the source is the only
        //    evidence there is. This is the MediaRemote path.
        // 3. An id we do *not* recognise means the track came from an app outside
        //    this registry, so no desktop app owns it — even if the source happens
        //    to name one. Falling through to the source here would address a player
        //    that never reported the track, which is the bug the `||` chain had.
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return DesktopMediaApp.allCases.first { $0.bundleIdentifier == bundleIdentifier }
        }
        return DesktopMediaApp.allCases.first { $0.source == source }
    }
    
    // MARK: - Web Browsers (YouTube & Web Video Fallback)
    private func fetchWebVideoTrack(isAudioRunning: Bool) -> MediaTrack? {
        let now = Date()
        if var cached = cachedWebTrack, now.timeIntervalSince(lastWebQueryTime) < 1.2 {
            cached.isPlaying = isAudioRunning
            return cached
        }
        
        var track: MediaTrack? = nil

        // Ordered per `MediaBrowser.detectionOrder`. Each browser is a case in that
        // list, so adding one here is impossible to forget: `detectionOrder` is the
        // only enumeration, and `MediaBrowserTests` pins that it is exhaustive.
        //
        // No `switch` on `tabScriptStyle` here any more: the per-browser difference
        // used to select between two near-identical query methods, which is how the
        // Safari one ended up hardcoding its own app name and bundle id. The
        // difference is now applied inside `queryBrowser`, so a browser is queried
        // by being *listed*, not by being *wired up*.
        for browser in MediaBrowser.detectionOrder where track == nil {
            guard isAppRunning(bundleId: browser.bundleIdentifier) else { continue }
            track = queryBrowser(
                browser,
                keywords: MediaBrowser.mediaURLKeywords,
                isAudioRunning: isAudioRunning
            )
        }

        if let found = track {
            cachedWebTrack = found
            lastWebQueryTime = now
            return found
        } else {
            if isAudioRunning, var cached = cachedWebTrack, now.timeIntervalSince(lastWebQueryTime) < 3.5 {
                cached.isPlaying = true
                return cached
            }
            cachedWebTrack = nil
            return nil
        }
    }

    /// Asks one browser for its first tab whose URL matches a media keyword.
    ///
    /// This is the single place a browser is queried for a track. It used to be two
    /// near-identical methods — `queryChromiumBrowser` and `querySafariBrowser` —
    /// and the Safari copy hardcoded both `tell application "Safari"` and the
    /// `com.apple.Safari` bundle id *inside its body*, while the Chromium copy read
    /// both off the `MediaBrowser` it was handed. That is the exact split-brain
    /// `MediaBrowser` exists to prevent: a Safari bundle id corrected in one place
    /// but not the other would leave `MediaBrowserTests` green and Safari detection
    /// silently broken.
    ///
    /// The one real difference between the two — Safari calls the title property
    /// `name`, Chromium calls it `title` — is not a coincidence, it is
    /// `tabScriptStyle`, and it is the reason that enum exists.
    private func queryBrowser(
        _ browser: MediaBrowser,
        keywords: [String],
        isAudioRunning: Bool
    ) -> MediaTrack? {
        let conditions = keywords
            .map { "URL contains \"\($0)\"" }
            .joined(separator: " or ")
        // Safari exposes the title as `name`; the Chromium family as `title`.
        let titleProperty = browser.tabScriptStyle == .safari ? "name" : "title"
        let script = """
        tell application "\(browser.applicationName)"
            if (count of windows) > 0 then
                repeat with w in windows
                    set m to (every tab of w whose \(conditions))
                    if (count of m) > 0 then
                        set t to item 1 of m
                        return (\(titleProperty) of t) & "\(DesktopMediaApp.PIPE_DELIMITER)" & (URL of t)
                    end if
                end repeat
            end if
            return ""
        end tell
        """
        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
        return parseWebVideoOutput(
            output,
            bundleId: browser.bundleIdentifier,
            isAudioRunning: isAudioRunning
        )
    }

    private func parseWebVideoOutput(_ raw: String, bundleId: String, isAudioRunning: Bool) -> MediaTrack? {
        // Same wire format and the same splitter as the desktop adapters, so the two
        // AppleScript families cannot drift into disagreeing about what a separator
        // means. `parseWebVideoOutput` previously split on a bare `"|||"` literal
        // while `DesktopMediaApp.fields` owned the documented behaviour for the very
        // same delimiter.
        let parts = DesktopMediaApp.fields(of: raw)
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
                url: url,
                bundleIdentifier: bundleId
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
                url: url,
                bundleIdentifier: bundleId
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
                url: url,
                bundleIdentifier: bundleId
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
            url: url,
            bundleIdentifier: bundleId
        )
    }

    // MARK: - System-Wide MediaRemote
    private func fetchMediaRemoteTrack(completion: @escaping @Sendable (MediaTrack?) -> Void) {
        guard let getInfo = mrGetNowPlayingInfo else {
            completion(nil)
            return
        }
        
        getInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] dict in
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
            let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue
            let artwork = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            
            let (isPlaying, _) = self.checkPlaybackState(rate: rate)
            
            if let getPID = self.mrGetNowPlayingPID {
                getPID(DispatchQueue.global(qos: .userInitiated)) { [weak self] pid in
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
        let classification = MediaSourceClassification.classify(bundleId: bundleId, artist: artist, title: title)
        var finalArtist = artist
        if finalArtist.isEmpty {
            finalArtist = classification.fallbackArtist
        }
        let source = classification.source

        // Strip trailing " - YouTube" if present in video title
        var cleanTitle = title
        if cleanTitle.hasSuffix(" - YouTube") {
            cleanTitle = String(cleanTitle.dropLast(10))
        }
        
        return MediaTrack(
            title: cleanTitle,
            artist: finalArtist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            source: source,
            artworkData: artwork,
            bundleIdentifier: bundleId.isEmpty ? nil : bundleId
        )
    }
    
    // MARK: - Playback Controls
    public enum MRCommand: Int32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
        case seekToPlaybackPosition = 24
    }

    @discardableResult
    public func sendMediaRemoteCommand(_ command: Int32, options: [String: Any]? = nil) -> Bool {
        if let mrSendCommand = mrSendCommand {
            let cfDict: CFDictionary? = options != nil ? ((options! as NSDictionary) as CFDictionary) : nil
            return mrSendCommand(command, cfDict)
        }
        return false
    }

    public func togglePlayPause() {
        SoundManager.shared.play(.click)

        let willPlay = !currentTrack.isPlaying
        var handled = false

        // 1. Targeted native player handling via AppleScript.
        //
        // The verb comes from the app's own `controls`, so which app is addressed and
        // which command is sent are one lookup rather than four `||` branches that
        // each had to name both. QuickTime's play/pause guards on document count
        // inside the script, so pressing play with nothing open is a no-op.
        if let controls = owningApp?.controls {
            let script = willPlay ? controls.play : controls.pause
            handled = executeAppleScript(script)
        }

        // 2. System-wide MediaRemote command
        if !handled {
            let cmd: Int32 = willPlay ? MRCommand.play.rawValue : MRCommand.pause.rawValue
            let sent = sendMediaRemoteCommand(cmd)
            if !sent {
                _ = sendMediaRemoteCommand(MRCommand.togglePlayPause.rawValue)
                sendSystemMediaKey(key: 16)
            }
        }
        
        lastUserToggleTime = Date()
        currentTrack.isPlaying = willPlay
        cachedWebTrack?.isPlaying = willPlay
        playbackStatus = willPlay ? .playing : .paused
        lastPositionUpdateTime = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.refreshMedia()
        }
    }
    
    public func nextTrack() {
        advanceTrack(direction: .next)
    }

    public func previousTrack() {
        advanceTrack(direction: .previous)
    }

    /// Which way to move within a playlist.
    ///
    /// This is the whole reason `nextTrack` and `previousTrack` can be one function.
    /// The two were byte-for-byte identical apart from four values — the AppleScript
    /// verb, the MediaRemote command, the YouTube CSS selector, and the media key —
    /// so any future edit to the fallback order had to be made twice and a
    /// half-applied edit produced a chain that went *forward* on some sources and
    /// *backward* on others.
    private enum TrackStep {
        case next
        case previous

        var mediaRemoteCommand: MRCommand { self == .next ? .nextTrack : .previousTrack }

        /// The YouTube player's own button. Injected into a background tab, so it is
        /// only reached when the track is already known to be a web video.
        var youTubeSelector: String { self == .next ? ".ytp-next-button" : ".ytp-prev-button" }

        /// `NX_KEYTYPE_NEXT` / `NX_KEYTYPE_PREVIOUS`, the last-resort hardware event.
        var systemMediaKey: Int32 { self == .next ? 17 : 18 }

        func script(for controls: DesktopMediaApp.PlaybackControls) -> String? {
            self == .next ? controls.next : controls.previous
        }
    }

    private func advanceTrack(direction: TrackStep) {
        SoundManager.shared.play(.click)
        var handled = false

        // 1. Native desktop players via AppleScript.
        //
        // QuickTime has no `next`/`previous` concept, so its `controls` are `nil`
        // here and the chain falls through to MediaRemote — which is correct, and
        // used to be an absent branch that read as an oversight.
        if let script = owningApp?.controls.flatMap({ direction.script(for: $0) }) {
            handled = executeAppleScript(script)
        }

        // 2. System-wide MediaRemote command (like a physical keyboard key)
        if !handled {
            handled = sendMediaRemoteCommand(direction.mediaRemoteCommand.rawValue)
        }

        // 3. YouTube DOM button fallback
        if !handled && currentTrack.source == .youtube {
            triggerYouTubeButton(selector: direction.youTubeSelector)
            handled = true
        }

        // 4. System media key fallback
        if !handled {
            sendSystemMediaKey(key: direction.systemMediaKey)
        }

        lastUserToggleTime = Date()
        lastPositionUpdateTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshMedia()
        }
    }

    public func seek(to seconds: Double) {
        lastUserToggleTime = Date()
        
        // 1. Send MediaRemote seekToPlaybackPosition (Command 24)
        // Natively supported by macOS MPRemoteCommandCenter across Chrome, Edge, Brave, Arc, Safari, etc.
        let options: [String: Any] = [
            "kMRMediaRemoteOptionPlaybackPosition": NSNumber(value: seconds)
        ]
        _ = sendMediaRemoteCommand(MRCommand.seekToPlaybackPosition.rawValue, options: options)
        
        // 2. Also call legacy mrSetElapsedTime if available
        if let mrSetElapsed = mrSetElapsedTime {
            mrSetElapsed(seconds)
        }
        
        // 3. Desktop player specific AppleScripts
        //
        // The seek verb comes from the owning app rather than a `switch` on source
        // that restated the app name a fourth time. Apps with no `setPosition` —
        // VLC — are simply skipped, which is the behaviour that switch already had.
        if let setPosition = owningApp?.controls?.setPosition(seconds) {
            _ = runAppleScript(setPosition)
        }
        
        currentTrack.position = seconds
        lastPositionUpdateTime = Date()
    }
    
    private func triggerYouTubeButton(selector: String) {
        let js = "document.querySelector('\(selector)')?.click()"
        let safeJs = js.replacingOccurrences(of: "\"", with: "\\\"")

        // Only the browsers listed in `youTubeControlBrowsers`, and via the same
        // `tabScriptStyle` split the detection path uses — so a browser cannot be
        // detectable for media yet un-injectable for its controls.
        for browser in MediaBrowser.youTubeControlBrowsers {
            guard isAppRunning(bundleId: browser.bundleIdentifier) else { continue }
            let script: String
            switch browser.tabScriptStyle {
            case .chromium:
                script = """
                try
                    tell application "\(browser.applicationName)"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t contains "youtube.com") or (URL of t contains "youtu.be") then
                                    tell t to execute javascript "\(safeJs)"
                                    return "ok"
                                end if
                            end repeat
                        end repeat
                    end tell
                on error
                end try
                """
            case .safari:
                script = """
                try
                    tell application "\(browser.applicationName)"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t contains "youtube.com") or (URL of t contains "youtu.be") then
                                    tell t to do JavaScript "\(safeJs)"
                                    return "ok"
                                end if
                            end repeat
                        end repeat
                    end tell
                on error
                end try
                """
            }
            _ = runAppleScript(script)
        }
    }
    
    public func openMediaPage() {
        SoundManager.shared.play(.click)
        
        // 1. If we have a direct web URL, focus that tab in the running browser or open URL.
        // Iterating the registry rather than an inline list is what keeps this in step
        // with detection: a browser the island can read a track from is a browser it
        // can also focus the tab of.
        if let urlStr = currentTrack.url, !urlStr.isEmpty {
            for browser in MediaBrowser.detectionOrder
            where isAppRunning(bundleId: browser.bundleIdentifier) {
                if focusBrowserTab(browser: browser, urlOrTitle: urlStr) {
                    return
                }
            }
            if let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // 2. If it's a browser without direct URL, try to focus the tab by track title
        if let bundleId = currentTrack.bundleIdentifier {
            // Resolving through the registry means "is this a browser we support" is
            // one question answered by one lookup, not a dictionary that can drift out
            // of date relative to `detectionOrder`.
            if let browser = MediaBrowser(bundleIdentifier: bundleId),
               isAppRunning(bundleId: bundleId) {
                if focusBrowserTab(browser: browser, urlOrTitle: currentTrack.title) {
                    return
                }
            }

            // 3. Activate the specific owning application directly
            if isAppRunning(bundleId: bundleId) {
                openApp(bundleId: bundleId)
                return
            }
        }
        
        // 4. Fall back to opening media app by source
        openMediaApp()
    }
    
    private func focusBrowserTab(browser: MediaBrowser, urlOrTitle: String) -> Bool {
        let safePattern = urlOrTitle.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch browser.tabScriptStyle {
        case .safari:
            script = """
            tell application "\(browser.applicationName)"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t contains "\(safePattern)") or (name of t contains "\(safePattern)") then
                            set current tab of w to t
                            set index of w to 1
                            return "ok"
                        end if
                    end repeat
                end repeat
                return "not_found"
            end tell
            """
        case .chromium:
            script = """
            tell application "\(browser.applicationName)"
                activate
                repeat with w in windows
                    set tabIdx to 0
                    repeat with t in tabs of w
                        set tabIdx to tabIdx + 1
                        if (URL of t contains "\(safePattern)") or (title of t contains "\(safePattern)") then
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
    
    /// Opens whatever app most plausibly owns the current track.
    ///
    /// Both branches now resolve through the two registries rather than repeating
    /// bundle ids. The desktop half used to spell out four ids inline that
    /// `DesktopMediaApp` already owns, and the browser half hardcoded Chrome and
    /// Safari — a third copy of the browser list, in a function that decides which
    /// app to launch, and the one place a stale id is most visible: the button
    /// silently opens the wrong app.
    ///
    /// Order is deliberate and unchanged: the app that actually produced the track
    /// wins, then any running browser in `detectionOrder`, then Music as the
    /// always-present default.
    public func openMediaApp() {
        // 1. The desktop app that produced this exact source, if it is running.
        if let app = DesktopMediaApp.allCases.first(where: { $0.source == currentTrack.source }),
           isAppRunning(bundleId: app.bundleIdentifier) {
            openApp(bundleId: app.bundleIdentifier)
            return
        }

        // 2. Any running browser, in detection order.
        if let browser = MediaBrowser.detectionOrder.first(where: {
            isAppRunning(bundleId: $0.bundleIdentifier)
        }) {
            openApp(bundleId: browser.bundleIdentifier)
            return
        }

        // 3. Fall back to Music, which ships with the system.
        openApp(bundleId: DesktopMediaApp.music.bundleIdentifier)
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

    @discardableResult
    private func executeAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        guard let scriptObj = NSAppleScript(source: source) else { return false }
        scriptObj.executeAndReturnError(&error)
        return error == nil
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
