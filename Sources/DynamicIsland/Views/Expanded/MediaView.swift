import SwiftUI

public struct MediaView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @State private var isSeeking = false
    @State private var seekPosition: Double = 0.0
    
    public var body: some View {
        VStack(spacing: 14) {
            // MARK: - Track Info & Artwork
            HStack(spacing: 14) {
                // Album Art / Video Thumbnail / Disc
                Button(action: {
                    mediaManager.openMediaPage()
                }) {
                    ZStack {
                        if let artData = mediaManager.currentTrack.artworkData,
                           let nsImg = NSImage(data: artData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .scaleEffect(mediaManager.currentTrack.isPlaying ? 1.0 : 0.90)
                                .shadow(
                                    color: mediaManager.currentTrack.source.accentColor.opacity(mediaManager.currentTrack.isPlaying ? 0.45 : 0.15),
                                    radius: mediaManager.currentTrack.isPlaying ? 10 : 4,
                                    y: 4
                                )
                                .animation(IslandSpring.expand, value: mediaManager.currentTrack.isPlaying)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            mediaManager.currentTrack.source.accentColor.opacity(0.85),
                                            mediaManager.currentTrack.source.accentColor.opacity(0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 54)
                                .scaleEffect(mediaManager.currentTrack.isPlaying ? 1.0 : 0.90)
                                .shadow(
                                    color: mediaManager.currentTrack.source.accentColor.opacity(mediaManager.currentTrack.isPlaying ? 0.40 : 0.15),
                                    radius: mediaManager.currentTrack.isPlaying ? 10 : 4,
                                    y: 4
                                )
                                .animation(IslandSpring.expand, value: mediaManager.currentTrack.isPlaying)
                            
                            Image(systemName: mediaManager.currentTrack.source.iconName)
                                .font(IslandFont.iconHero)
                                .foregroundColor(.white)
                                .scaleEffect(mediaManager.currentTrack.isPlaying ? 1.0 : 0.90)
                                .animation(IslandSpring.expand, value: mediaManager.currentTrack.isPlaying)
                        }
                    }
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.94))
                
                // Track metadata
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Button(action: {
                            mediaManager.openMediaPage()
                        }) {
                            HStack(spacing: 5) {
                                Text(mediaManager.currentTrack.title)
                                    .font(IslandFont.title)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        EqualizerVisualizerView(tint: mediaManager.currentTrack.source.accentColor, maxHeight: 12)
                    }
                    
                    Text(mediaManager.currentTrack.artist)
                        .font(IslandFont.subtitle)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: mediaManager.currentTrack.source.iconName)
                            .font(IslandFont.iconMicro)
                            .foregroundColor(mediaManager.currentTrack.source.accentColor)
                        Text(mediaManager.currentTrack.source.rawValue)
                            .font(IslandFont.caption)
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // MARK: - Progress Scrubber
            if mediaManager.currentTrack.duration > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track background
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            // Progress bar
                            let progress = isSeeking ? (seekPosition / mediaManager.currentTrack.duration) : (mediaManager.currentTrack.position / mediaManager.currentTrack.duration)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 4)
                        }
                        .frame(height: 14)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    isSeeking = true
                                    let pct = max(0.0, min(1.0, Double(gesture.location.x / geo.size.width)))
                                    seekPosition = pct * mediaManager.currentTrack.duration
                                }
                                .onEnded { gesture in
                                    let pct = max(0.0, min(1.0, Double(gesture.location.x / geo.size.width)))
                                    let targetSec = pct * mediaManager.currentTrack.duration
                                    mediaManager.seek(to: targetSec)
                                    isSeeking = false
                                }
                        )
                    }
                    .frame(height: 14)
                    
                    HStack {
                        let cur = isSeeking ? seekPosition : mediaManager.currentTrack.position
                        Text(formatTime(cur))
                            .font(IslandFont.timeNumeric)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text(formatTime(mediaManager.currentTrack.duration))
                            .font(IslandFont.timeNumeric)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 14)
            }
            
            // MARK: - Controls Row (Centered Playback Controls)
            HStack(spacing: 28) {
                Spacer()
                
                // Previous
                Button(action: {
                    mediaManager.previousTrack()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "backward.fill")
                            .font(IslandFont.iconLarge)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
                .help("Previous Track")
                
                // Play / Pause / Stop
                Button(action: {
                    mediaManager.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 42, height: 42)
                            .shadow(color: Color.white.opacity(mediaManager.currentTrack.isPlaying ? 0.35 : 0.15), radius: 6, y: 2)
                        
                        Image(systemName: playButtonIconName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: mediaManager.currentTrack.isPlaying ? 0 : 1.5)
                            .scaleEffect(mediaManager.currentTrack.isPlaying ? 1.0 : 1.06)
                            .animation(IslandSpring.bouncy, value: mediaManager.currentTrack.isPlaying)
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                .help(mediaManager.currentTrack.isPlaying ? "Pause" : "Play")
                
                // Next
                Button(action: {
                    mediaManager.nextTrack()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "forward.fill")
                            .font(IslandFont.iconLarge)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
                .help("Next Track")
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
    
    private var playButtonIconName: String {
        mediaManager.currentTrack.isPlaying ? "pause.fill" : "play.fill"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
