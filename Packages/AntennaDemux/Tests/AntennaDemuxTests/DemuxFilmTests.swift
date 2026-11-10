import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Films on the FFmpeg path: a saved time, skipping and the end, over a
/// server that takes byte ranges, and refusals where it cannot skip.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxFilmTests {
    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a film opens at its saved time")
    func opensAtSavedTime() async throws {
        let harness = try await FilmHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("channel.mkv"), options: PlaybackOptions(startPosition: .seconds(3)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { (position.values.last?.time ?? .zero) > .seconds(2) })
        #expect(abs((position.values.last?.time ?? .zero).inSeconds - 3) < 1.2)
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a saved time past the end starts at the beginning")
    func savedTimePastTheEnd() async throws {
        let harness = try await FilmHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("channel.mkv"), options: PlaybackOptions(startPosition: .seconds(60)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { position.values.last.map { $0.duration != nil } == true })
        #expect((position.values.last?.time ?? .seconds(99)) < .seconds(1.5))
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a skip lands within a second, past the end it finishes")
    func skipAndFinish() async throws {
        let harness = try await FilmHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("channel.mkv"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await harness.engine.seek(to: .seconds(4))
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { (position.values.last?.time ?? .zero) > .seconds(3) })
        #expect(abs((position.values.last?.time ?? .zero).inSeconds - 4) < 1.2)
        try await harness.engine.seek(to: .seconds(30))
        #expect(harness.engine.state == .ended)
        let asked = await harness.server.requests(for: "/channel.mkv").count
        try await Task.sleep(for: .milliseconds(400))
        #expect(await harness.server.requests(for: "/channel.mkv").count == asked)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect((position.values.last?.time ?? .seconds(99)) < .seconds(1.5))
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a film whose server cannot skip refuses, live TV too")
    func refusesWithoutRanges() async throws {
        let harness = try await FilmHarness()
        await harness.server.always("/channel.mkv", .ignoreRanges)
        try await harness.engine.load(harness.url("channel.mkv"), options: PlaybackOptions(startPosition: .seconds(3)))
        await #expect(throws: SeekRefusal.notSeekable) { try await harness.engine.seek(to: .seconds(2)) }
        try await harness.engine.load(harness.url("channel.ts"))
        await #expect(throws: SeekRefusal.live) { try await harness.engine.seek(to: .seconds(2)) }
        await harness.stop()
    }
}

/// A fixture server and an engine with no retry waits.
@MainActor
private struct FilmHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine

    init() async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine = DemuxEngine(sleep: { _ in }, log: { _ in })
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}
