import Foundation
import Testing

@testable import AntennaCore

/// The MPEG-TS link takes over when a channel's HLS link for AirPlay does not start.
@Suite(.timeLimit(.minutes(1))) struct RoutedFallbackTests {
    let log = EngineLog()
    let system: FakeEngine
    let demuxer: FakeEngine
    let routed: RoutedEngine
    static let fallback = StreamFallback(url: .test("http://panel/live/u/p/42.ts"), source: AirPlayHLSTests.source)
    static let options = PlaybackOptions(fallback: fallback)

    init() {
        system = FakeEngine("system", log: log)
        demuxer = FakeEngine("demuxer", log: log)
        routed = RoutedEngine(system: system, demuxer: demuxer)
    }

    /// The fallback the routed engine names now.
    private func lastFallback() async -> StreamFallback? {
        var fallbacks = await routed.fallbacks().makeAsyncIterator()
        guard let current = await fallbacks.next() else { return nil }
        return current
    }

    private func failures(_ states: Collected<PlaybackState>) async -> [PlaybackState] {
        await states.values.filter { if case .failed = $0 { true } else { false } }
    }

    private func watch() -> (Collected<PlaybackState>, Task<Void, Never>) {
        let seen = Collected<PlaybackState>()
        let routed = routed
        let task = Task { for await state in await routed.states() { await seen.add(state) } }
        return (seen, task)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: a refused HLS address plays as MPEG-TS with no error")
    func refusedHLSFallsBack() async throws {
        let (seen, watcher) = watch()
        defer { watcher.cancel() }
        await system.script(.failure(PlaybackFailure.notFound))
        try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        await routed.play()
        #expect(await eventually { await routed.state == .playing })
        #expect(await log.entries == ["system.load 42.m3u8", "system.stop", "demuxer.load 42.ts", "demuxer.play"])
        #expect(await routed.activeEngine === demuxer)
        #expect(await routed.loadedExtension == "ts")
        #expect(await eventually { await lastFallback() == Self.fallback })
        try await Task.sleep(for: .milliseconds(50))
        #expect(await failures(seen).isEmpty)
    }

    @Test(
        "playback-engine/a-source-whose-hls-failed-cannot-airplay: HLS that fails after it opened, before it played, falls back")
    func failureAfterLoadFallsBack() async throws {
        let (seen, watcher) = watch()
        defer { watcher.cancel() }
        try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        await system.send(.failed(.unreadable))
        #expect(await eventually { await log.entries.contains("demuxer.load 42.ts") })
        await routed.play()
        #expect(await eventually { await routed.state == .playing })
        #expect(await routed.activeEngine === demuxer)
        #expect(await eventually { await lastFallback() == Self.fallback })
        #expect(await failures(seen).isEmpty)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: a stream that played and then fails is not moved")
    func failureAfterPlayingIsReported() async throws {
        let (seen, watcher) = watch()
        defer { watcher.cancel() }
        try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        await routed.play()
        #expect(await eventually { await routed.state == .playing })
        await system.send(.failed(.stoppedSendingData))
        #expect(await eventually { await failures(seen) == [.failed(.stoppedSendingData)] })
        #expect(await !log.entries.contains("demuxer.load 42.ts"))
        #expect(await lastFallback() == nil)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: offline and a missing login fail as they are")
    func offlineIsNotMoved() async throws {
        await system.script(.failure(PlaybackFailure.offline))
        await #expect(throws: PlaybackFailure.offline) {
            try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        }
        await system.script(.failure(PlaybackFailure.loginNotOnDevice))
        await #expect(throws: PlaybackFailure.loginNotOnDevice) {
            try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        }
        #expect(await !log.entries.contains("demuxer.load 42.ts"))
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: when MPEG-TS fails too, its failure shows")
    func bothFail() async throws {
        await system.script(.failure(PlaybackFailure.notFound))
        await demuxer.script(.failure(PlaybackFailure.notAllowed))
        await #expect(throws: PlaybackFailure.notAllowed) {
            try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        }
        #expect(await routed.state == .failed(.notAllowed))
        try await Task.sleep(for: .milliseconds(50))
        #expect(await lastFallback() == nil)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: one engine for both routes hides the HLS failure too")
    func sharedEngineHidesTheFailure() async throws {
        let shared = FakeEngine("shared", log: log)
        let routed = RoutedEngine(system: shared, demuxer: shared)
        let seen = Collected<PlaybackState>()
        let watcher = Task { for await state in await routed.states() { await seen.add(state) } }
        defer { watcher.cancel() }
        await shared.script(.failure(PlaybackFailure.serverError))
        try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        await routed.play()
        #expect(await eventually { await seen.last == .playing })
        #expect(await log.entries == ["shared.load 42.m3u8", "shared.load 42.ts", "shared.play"])
        #expect(await failures(seen).isEmpty)
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly a newer load drops the fallback of the older one")
    func newerLoadDropsTheFallback() async throws {
        try await routed.load(.test("http://panel/live/u/p/42.m3u8"), options: Self.options)
        try await routed.load(.test("http://panel/live/u/p/43.m3u8"))
        await system.send(.failed(.unreadable))
        try await Task.sleep(for: .milliseconds(50))
        #expect(await !log.entries.contains("demuxer.load 42.ts"))
        #expect(await routed.state == .failed(.unreadable))
    }
}
