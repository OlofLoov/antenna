import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

#if os(macOS)
    /// The Mac display stays on while the FFmpeg path plays
    /// (playback-engine/the-display-stays-on-while-a-stream-plays).
    @MainActor
    @Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxDisplaySleepTests {
        @Test(
            "playback-engine/the-display-stays-on-while-a-stream-plays the display stays on while playing, not when paused or stopped"
        )
        func followsPlayback() async throws {
            let server = try FixtureServer()
            let base = try await server.start()
            let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
            #expect(!engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            try await engine.load(base.appending(path: "film.mkv"))
            #expect(!engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            await engine.play()
            #expect(await eventually { engine.state == .playing })
            #expect(engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            await engine.pause()
            #expect(!engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            await engine.play()
            #expect(await eventually { engine.state == .playing })
            #expect(engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            await engine.stop()
            #expect(!engine.videoLayer.preventsDisplaySleepDuringVideoPlayback)
            await server.stop()
        }
    }
#endif
