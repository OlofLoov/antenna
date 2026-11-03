import SwiftUI
import AVKit
import AntennaCore

/// Thin player screen. Routes to the system player for HLS. The demuxer path
/// (FFmpeg → VideoToolbox → AVSampleBufferVideoRenderer) is the next engine to
/// add; until then TS streams also go through AVPlayer so the UI can be exercised.
struct PlayerView: View {
    let channel: Channel
    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .navigationTitle(channel.name)
            .onAppear {
                player.replaceCurrentItem(with: AVPlayerItem(url: channel.streamURL))
                player.play()
            }
            .onDisappear { player.pause() }
    }
}
