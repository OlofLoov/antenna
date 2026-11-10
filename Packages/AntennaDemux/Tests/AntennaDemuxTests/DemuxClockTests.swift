import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Playback keeps going when the audio output stalls.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxClockTests {
    @Test("playback-engine/every-common-stream-type-plays a stalled audio output does not stop the picture")
    func playsOnWithoutSound() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let position = Recorded(await engine.position())
        try await engine.load(base.appending(path: "channel.ts"))
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        engine.playWithoutSound()
        let before = position.values.last?.time ?? .zero
        #expect(await eventually { (position.values.last?.time ?? .zero) > before + .milliseconds(500) })
        #expect(engine.state == .playing)
        position.cancel()
        await engine.stop()
        await server.stop()
    }
}
