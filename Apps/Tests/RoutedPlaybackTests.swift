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

    @Test("playback-engine/every-common-stream-type-plays an hev1 MP4 plays on the demuxing engine", .progressiveHTTP)
    func undecodableFilePlaysOnDemuxer() async throws {
        try await playsOnDemuxer(path: "hev1.mp4", fixture: nil)
    }

    @Test("playback-engine/every-common-stream-type-plays raw MPEG-TS at an HLS address plays on the demuxing engine")
    func transportStreamAtHLSAddressPlaysOnDemuxer() async throws {
        try await playsOnDemuxer(path: "live/u/p/1.m3u8", fixture: "channel.ts")
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls an Xtream channel's HLS link plays on Apple's player")
    func xtreamHLSPlaysOnTheSystemPlayer() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.alias("/live/u/p/5.m3u8", to: "hls/index.m3u8")
        await server.alias("/live/u/p/5.ts", to: "channel.ts")
        let engine = RoutedEngine.app()
        let fallback = StreamFallback(url: base.appending(path: "live/u/p/5.ts"), source: UUID())
        try await engine.load(base.appending(path: "live/u/p/5.m3u8"), options: PlaybackOptions(isLive: true, fallback: fallback))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.system)
        #expect(await server.requests(for: "/live/u/p/5.ts").isEmpty)
        var fallbacks = await engine.fallbacks().makeAsyncIterator()
        #expect(await fallbacks.next() == .some(nil))
        await engine.stop()
        await server.stop()
    }

    @Test(
        "playback-engine/a-source-whose-hls-failed-cannot-airplay an Xtream channel whose HLS is refused plays on as MPEG-TS",
        arguments: [FixtureServer.Behavior.status(404), .status(403), .body(Data("<html></html>".utf8), contentType: "text/html")])
    func refusedHLSFallsBackToTheDemuxer(refusal: FixtureServer.Behavior) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.always("/live/u/p/6.m3u8", refusal)
        await server.alias("/live/u/p/6.ts", to: "channel.ts")
        let engine = RoutedEngine.app()
        let fallback = StreamFallback(url: base.appending(path: "live/u/p/6.ts"), source: UUID())
        try await engine.load(base.appending(path: "live/u/p/6.m3u8"), options: PlaybackOptions(isLive: true, fallback: fallback))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.demuxer)
        #expect(await engine.loadedExtension == "ts")
        var fallbacks = await engine.fallbacks().makeAsyncIterator()
        #expect(await fallbacks.next() == .some(fallback))
        await engine.stop()
        await server.stop()
    }

    private func playsOnDemuxer(path: String, fixture: String?) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        if let fixture {
            let body = try Data(contentsOf: server.root.appending(path: fixture))
            await server.always("/\(path)", .body(body, contentType: "application/octet-stream"))
        }
        let engine = RoutedEngine.app()
        try await engine.load(base.appending(path: path))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(await engine.activeEngine === engine.demuxer)
        await engine.stop()
        await server.stop()
    }
}
