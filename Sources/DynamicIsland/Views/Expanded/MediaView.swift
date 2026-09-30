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
                ZStack {
                    if let artData = mediaManager.currentTrack.artworkData,
                       let nsImg = NSImage(data: artData) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: mediaManager.currentTrack.source.accentColor.opacity(0.3), radius: 8, y: 4)
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
                            .shadow(color: mediaManager.currentTrack.source.accentColor.opacity(0.35), radius: 8, y: 4)
                        
                        Image(systemName: mediaManager.currentTrack.source.iconName)
                            .font(IslandFont.iconHero)
                            .foregroundColor(.white)
                    }
                }
                
                // Track metadata
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(mediaManager.currentTrack.title)
                            .font(IslandFont.title)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
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
            
            // MARK: - Controls Row
            HStack(spacing: 24) {
                // Open App button
                Button(action: {
                    mediaManager.openMediaApp()
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(IslandFont.iconRegular)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Previous
                Button(action: {
                    mediaManager.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(IslandFont.iconLarge)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Play / Pause
                Button(action: {
                    mediaManager.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: mediaManager.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(IslandFont.iconLarge)
                            .foregroundColor(.black)
                            .offset(x: mediaManager.currentTrack.isPlaying ? 0 : 1.5)
                    }
                }
                .buttonStyle(.plain)
                
                // Next
                Button(action: {
                    mediaManager.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(IslandFont.iconLarge)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
