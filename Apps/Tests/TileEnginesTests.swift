import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

/// Records every mute and unmute by the engine that makes the sound, the
/// one inside a routed engine, and counts how many can be heard at once.
@MainActor
private final class MuteLog {
    private(set) var unmuted: Set<ObjectIdentifier> = []
    private(set) var mostHeard = 0
    private(set) var changes = 0

    private func inner(_ engine: any PlaybackEngine) -> ObjectIdentifier {
        ObjectIdentifier((engine as? RoutedEngine)?.demuxer ?? engine)
    }

    func set(_ engine: any PlaybackEngine, _ muted: Bool) {
        if muted {
            unmuted.remove(inner(engine))
        } else {
            unmuted.insert(inner(engine))
        }
        changes += 1
        mostHeard = max(mostHeard, unmuted.count)
    }

    func isHeard(_ engine: any PlaybackEngine) -> Bool {
        unmuted.contains(inner(engine))
    }
}

@MainActor
private final class Made {
    var engines: [PlayerTestEngine] = []
}

@MainActor
private func channel(_ position: Int, source: UUID) -> Channel {
    Channel(
        id: "c\(position)", name: "C\(position)", streamURL: URL(fileURLWithPath: "/c\(position).ts"), sourceID: source, position: position)
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct TileEnginesTests {
    let source = UUID()

    private func tiles(_ log: MuteLog, made: @escaping (PlayerTestEngine) -> Void = { _ in }) -> TileEngines {
        let single = RoutedEngine(system: PlayerTestEngine(), demuxer: PlayerTestEngine())
        log.set(single, false)
        return TileEngines(
            single: single,
            dependencies: .init(
                make: {
                    let fake = PlayerTestEngine()
                    made(fake)
                    return RoutedEngine(system: fake, demuxer: fake)
                },
                mute: { log.set($0, $1) }, playback: { _, _ in }, refusalsFinal: { _, _ in }, lifecycle: { _ in nil }))
    }

    @Test("multi-view/sound-follows-the-highlighted-tile switching sound between two fake engines never has both unmuted")
    func neverTwoHeard() async throws {
        let log = MuteLog()
        let engines = tiles(log)
        let channels = (1...4).map { channel($0, source: source) }
        let keys = channels.compactMap(RowKey.init)
        let find: (RowKey) -> Channel? = { key in channels.first { RowKey($0) == key } }
        let started = try #require(MultiViewSession.start(playing: keys[0], adding: keys[1], cap: MultiViewCap(limit: 4)))
        var session = started.0
        let start = started.1
        await engines.run(start, channel: find)
        for step in 0..<20 {
            await engines.run(session.select(step.isMultiple(of: 2) ? 1 : 2), channel: find)
        }
        await engines.run(session.add(keys[2]), channel: find)
        await engines.run(session.select(1), channel: find)
        #expect(log.mostHeard == 1)
        #expect(log.changes > 40)
        let first = try #require(engines.engines[1])
        #expect(log.isHeard(first))
    }

    @Test("multi-view/start-multi-view-on-apple-tv the playing channel moves into tile 1 with no reload")
    func adoptKeepsPlaying() async throws {
        let log = MuteLog()
        let playing = PlayerTestEngine()
        let single = RoutedEngine(system: playing, demuxer: playing)
        try await single.load(URL(fileURLWithPath: "/c1.ts"))
        await single.play()
        let engines = TileEngines(
            single: single,
            dependencies: .init(
                make: {
                    let fake = PlayerTestEngine()
                    return RoutedEngine(system: fake, demuxer: fake)
                }, mute: { log.set($0, $1) }, playback: { _, _ in }, refusalsFinal: { _, _ in }, lifecycle: { _ in nil }))
        let channels = (1...2).map { channel($0, source: source) }
        let keys = channels.compactMap(RowKey.init)
        let started = try #require(MultiViewSession.start(playing: keys[0], adding: keys[1], cap: MultiViewCap(limit: 4)))
        var session = started.0
        let start = started.1
        await engines.run(start, channel: { key in channels.first { RowKey($0) == key } })
        let first = try #require(engines.engines[1])
        #expect(first.demuxer === playing)
        #expect(await first.state == .playing)
        #expect(playing.loaded.count == 1)
        #expect(await single.state == .idle)
        await engines.run(session.leave(), channel: { _ in nil })
        #expect(single.demuxer !== playing)
        #expect(session.leave().isEmpty)
    }

    @Test("multi-view/leave-multi-view the kept tile's player becomes the single player with no reload")
    func keepHandsBack() async throws {
        let log = MuteLog()
        let made = Made()
        let engines = tiles(log) { made.engines.append($0) }
        let channels = (1...3).map { channel($0, source: source) }
        let keys = channels.compactMap(RowKey.init)
        let find: (RowKey) -> Channel? = { key in channels.first { RowKey($0) == key } }
        let started = try #require(MultiViewSession.start(playing: keys[0], adding: keys[1], cap: MultiViewCap(limit: 4)))
        var session = started.0
        let start = started.1
        await engines.run(start, channel: find)
        await engines.run(session.add(keys[2]), channel: find)
        await engines.run(session.select(2), channel: find)
        #expect(await eventually { made.engines.count == 3 && made.engines[1].loaded.count == 1 })
        // The first engine made went to the single player when tile 1 took its place.
        let kept = made.engines[1]
        await engines.run(session.leave(), channel: find)
        #expect(engines.single.demuxer === kept)
        #expect(kept.loaded.count == 1)
        #expect(engines.engines.isEmpty)
        #expect(log.isHeard(engines.single))
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct TilePlaybackTests {
    @Test("multi-view/start-multi-view-on-apple-tv an HLS tile stays at 1080p and leaves the TV's mode alone while it plays")
    func tileSettingsReadBack() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = RoutedEngine.app()
        engine.setPlayback(.tile)
        engine.setMuted(true)
        try await engine.load(base.appending(path: "hls/index.m3u8"))
        await engine.play()
        #expect(await eventually { await engine.state == .playing })
        #expect(engine.playback == .tile)
        #expect(engine.isMuted)
        let item = AVPlayerEngine.resolve(engine)?.player.currentItem
        #expect(item?.preferredMaximumResolution == CGSize(width: 1920, height: 1080))
        engine.setPlayback(.single)
        #expect(item?.preferredMaximumResolution == .zero)
        #expect(engine.playback == .single)
        await engine.stop()
        await server.stop()
    }
}
