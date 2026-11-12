import AntennaCore
import SwiftUI

/// Draws `engine`'s subtitle cues over its picture, fitted to the picture's
/// shape (playback-engine/audio-and-subtitle-languages). Goes over a
/// `PlayerSurfaceView` of the same engine.
struct PlayerSubtitles: View {
    let engine: any PlaybackEngine
    /// Points the lines move up while controls cover the bottom.
    var raised: CGFloat = 0
    @State private var cues: [SubtitleCue] = []
    @State private var aspect: Double?

    var body: some View {
        SubtitleOverlay(cues: cues, aspect: aspect, raised: raised)
            .animation(nil, value: cues)
            .task(id: ObjectIdentifier(engine)) {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await followCues() }
                    group.addTask { await followShape() }
                }
            }
    }

    private func followCues() async {
        for await next in await engine.subtitleCues() {
            cues = next
        }
    }

    private func followShape() async {
        for await info in await engine.presentation() {
            guard let video = info?.video, video.width > 0, video.height > 0 else { continue }
            aspect = Double(video.width) / Double(video.height)
        }
    }
}
