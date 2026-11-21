import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Internet radio at an address with no extension goes to Apple's player
/// (playback-engine/every-common-stream-type-plays).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxRadioTests {
    @Test(
        "playback-engine/every-common-stream-type-plays MP3 and AAC radio at an address with no extension goes to Apple's player",
        arguments: [
            ("stream", "radio.mp3", "application/octet-stream"), (";", "radio.aac", "application/octet-stream"),
            ("live", "garbage.bin", "audio/aacp"),
        ])
    func radioHandsOver(path: String, fixture: String, contentType: String) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let body = try Data(contentsOf: server.root.appending(path: fixture))
        await server.always("/\(path)", .body(body, contentType: contentType))
        let engine = DemuxEngine(sleep: { _ in }, firstFrameTimeout: .seconds(2), log: { _ in })
        await #expect(throws: EngineHandoff.toSystemPlayer) { try await engine.load(base.appending(path: path)) }
        #expect(engine.state == .idle)
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/every-common-stream-type-plays garbage with no audio content type stays unreadable")
    func garbageStaysUnreadable() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let body = try Data(contentsOf: server.root.appending(path: "garbage.bin"))
        await server.always("/live", .body(body, contentType: "application/octet-stream"))
        let engine = DemuxEngine(sleep: { _ in }, firstFrameTimeout: .seconds(2), log: { _ in })
        await #expect(throws: PlaybackFailure.unreadable) { try await engine.load(base.appending(path: "live")) }
        await engine.stop()
        await server.stop()
    }
}
