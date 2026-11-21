import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// A channel that lists a picture and sends only sound
/// (playback-engine/every-common-stream-type-plays).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxNoPictureTests {
    @Test("playback-engine/every-common-stream-type-plays a channel whose picture never comes starts with sound only")
    func startsWithSoundOnly() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "no-picture.ts"))
        let presented = await current(engine.presentation())
        let format = try #require(presented.flatMap { $0 })
        #expect(format.video == nil)
        #expect(format.audio?.codec == "aac")
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/every-common-stream-type-plays the held sound is queued from its start when the picture is given up")
    func heldSoundIsQueued() async throws {
        let outcome = try await PictureCheck.run(FixtureServer.fixtures().appending(path: "no-picture.ts"))
        #expect(outcome.queued.isEmpty)
        let first = try #require(outcome.sound.first)
        #expect(first.time.seconds < 1.6)
        let end = try #require(outcome.sound.last).time.seconds
        #expect(end - first.time.seconds > 3.5)
    }
}
