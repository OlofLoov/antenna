import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

/// The engine the player screens use, `RoutedEngine.app()`, against the
/// fixture server: each kind of address reaches the engine that plays it.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct RoutedPlaybackTests {
    @Test("playback-engine/every-common-stream-type-plays the app's engine plays raw broadcast streams on the demuxing engine")
    func rawBroadcastPlays() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = RoutedEngine.app()
        try await engine.load(base.appending(path: "channel.ts"))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.demuxer)
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/every-common-stream-type-plays the app's engine switches between its two paths")
    func switchesPaths() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = RoutedEngine.app()
        try await engine.load(base.appending(path: "hls/index.m3u8"))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.system)
        try await engine.load(base.appending(path: "channel.mkv"))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.demuxer)
        await engine.stop()
        await server.stop()
    }
}
