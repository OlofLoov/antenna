import AntennaCore
import SwiftUI

/// Plays one channel full screen through the routed engine: HLS and files
/// on Apple's player, raw broadcast streams, Matroska and AVI on the
/// demuxing engine. Player controls come with the player controls change.
struct PlayerView: View {
    let channel: Channel
    @State private var engine: RoutedEngine
    @State private var lifecycle: PlaybackLifecycle

    init(channel: Channel) {
        self.channel = channel
        let engine = RoutedEngine.app()
        _engine = State(initialValue: engine)
        _lifecycle = State(initialValue: PlaybackLifecycle(engine: engine) { engine.continuesInPictureInPicture })
    }

    var body: some View {
        PlayerSurfaceView(engine: engine)
            .ignoresSafeArea()
            .navigationTitle(channel.name)
            .task(id: channel.streamURL) {
                lifecycle.start()
                do {
                    try await engine.load(channel.streamURL)
                    await engine.play()
                } catch {
                    // The engine reports the reason through its state; this
                    // screen has no error view yet.
                }
            }
            .onDisappear {
                lifecycle.end()
                Task { await engine.stop() }
            }
    }
}
