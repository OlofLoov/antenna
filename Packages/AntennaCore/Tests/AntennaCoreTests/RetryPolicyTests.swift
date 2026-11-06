import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

/// Counts attempts and fails them as scripted.
private actor Attempts {
    private var failures: [PlaybackFailure]
    private(set) var count = 0

    init(_ failures: [PlaybackFailure]) {
        self.failures = failures
    }

    func next() throws -> Int {
        count += 1
        if !failures.isEmpty { throw failures.removeFirst() }
        return count
    }
}

@Suite struct TuneRetryTests {
    @Test(
        "playback-engine/a-channel-that-won-t-start-is-retried-briefly a busy server, server error or broken connection is tried 3 times",
        arguments: [PlaybackFailure.serverBusy, .serverError, .stoppedSendingData])
    func retriesThreeTimes(failure: PlaybackFailure) async {
        let sleeps = RecordedSleeps()
        let attempts = Attempts([failure, failure, failure, failure])
        await #expect(throws: failure) {
            try await RetryPolicy.tune.run(sleep: { await sleeps.sleep($0) }) { try await attempts.next() }
        }
        #expect(await attempts.count == 3)
        #expect(await sleeps.waits == [.milliseconds(500), .seconds(1)])
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a retry that succeeds plays")
    func succeedsOnRetry() async throws {
        let sleeps = RecordedSleeps()
        let attempts = Attempts([.serverBusy])
        let value = try await RetryPolicy.tune.run(sleep: { await sleeps.sleep($0) }) { try await attempts.next() }
        #expect(value == 2)
        #expect(await sleeps.waits == [.milliseconds(500)])
    }

    @Test(
        "playback-engine/a-channel-that-won-t-start-is-retried-briefly refusals, missing and unreadable streams fail at once",
        arguments: [
            PlaybackFailure.notAllowed, .notFound, .unreadable, .secureConnectionFailed, .offline, .loginNotOnDevice,
            .refused(status: 418), .cannotDecode(codec: "mpeg2video"),
        ])
    func failsAtOnce(failure: PlaybackFailure) async {
        let sleeps = RecordedSleeps()
        let attempts = Attempts([failure])
        await #expect(throws: failure) {
            try await RetryPolicy.tune.run(sleep: { await sleeps.sleep($0) }) { try await attempts.next() }
        }
        #expect(await attempts.count == 1)
        #expect(await sleeps.waits.isEmpty)
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a revoked password fails as not allowed without retry")
    func revokedPassword() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.always("/live/u/p/42.ts", .status(401))
        let session = PlaybackNetwork.makeSession()
        let url = base.appending(path: "live/u/p/42.ts")
        await #expect(throws: PlaybackFailure.notAllowed) {
            try await RetryPolicy.tune.run(sleep: { _ in }) { try await StreamProbe.run(url, session: session) }
        }
        #expect(await server.requests(for: "/live/u/p/42.ts").count == 1)
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly the server is asked again only for busy and error answers")
    func busyServerIsAskedAgain() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.script("/channel.ts", .status(503), .status(429))
        let session = PlaybackNetwork.makeSession()
        let url = base.appending(path: "channel.ts")
        let probe = try await RetryPolicy.tune.run(sleep: { _ in }) { try await StreamProbe.run(url, session: session) }
        #expect(probe.sniff == .mpegTS)
        #expect(await server.requests(for: "/channel.ts").count == 3)
    }

    @Test func cancellationDuringAWaitStops() async {
        let attempts = Attempts([.serverBusy, .serverBusy])
        let task = Task {
            try await RetryPolicy.tune.run(sleep: { try await Task.sleep(for: $0) }) { try await attempts.next() }
        }
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }
        #expect(await attempts.count <= 1)
    }
}

@Suite struct ReconnectBudgetTests {
    let start = ContinuousClock.now

    @Test("playback-engine/a-dropped-channel-reconnects numbered attempts up to 8 over about 45 seconds")
    func eightAttempts() {
        var budget = ReconnectBudget()
        var attempts: [Int] = []
        var total = Duration.zero
        var now = start
        while let next = budget.dropped(.stoppedSendingData, at: now) {
            attempts.append(next.attempt)
            total += next.delay
            now += next.delay
        }
        #expect(attempts == Array(1...8))
        #expect(budget.maxAttempts == 8)
        #expect(total >= .seconds(40) && total <= .seconds(50))
    }

    @Test("playback-engine/a-dropped-channel-reconnects the count starts over after a minute of steady play")
    func resetsAfterSteadyPlay() {
        var budget = ReconnectBudget()
        _ = budget.dropped(.timedOut, at: start)
        _ = budget.dropped(.timedOut, at: start + .seconds(1))
        budget.playing(at: start + .seconds(2))
        #expect(budget.dropped(.timedOut, at: start + .seconds(30))?.attempt == 3)
        budget.playing(at: start + .seconds(31))
        #expect(budget.dropped(.timedOut, at: start + .seconds(91))?.attempt == 1)
    }

    @Test(
        "playback-engine/a-dropped-channel-reconnects losing the internet and server trouble are retried",
        arguments: [PlaybackFailure.offline, .unreachable, .timedOut, .stoppedSendingData, .serverBusy, .serverError])
    func retriedReasons(failure: PlaybackFailure) {
        var budget = ReconnectBudget()
        #expect(budget.dropped(failure, at: start)?.attempt == 1)
    }

    @Test(
        "playback-engine/a-dropped-channel-reconnects a refusal after playing fails with that reason",
        arguments: [PlaybackFailure.notAllowed, .notFound, .unreadable, .secureConnectionFailed])
    func notRetriedReasons(failure: PlaybackFailure) {
        var budget = ReconnectBudget()
        #expect(budget.dropped(failure, at: start) == nil)
    }

    @Test func stallBudgetAndSteadyPlayAreTheDesignNumbers() {
        #expect(RetryPolicy.stallBudget == .seconds(10))
        #expect(RetryPolicy.steadyPlay == .seconds(60))
        #expect(PlaybackNetwork.connectTimeout == .seconds(8))
    }
}

@Suite(.timeLimit(.minutes(1))) struct StreamProbeTests {
    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason server answers map to one reason",
        arguments: [
            (401, PlaybackFailure.notAllowed), (403, .notAllowed), (404, .notFound), (429, .serverBusy), (500, .serverError),
            (503, .serverError), (509, .serverError), (418, .refused(status: 418)),
        ])
    func statuses(status: Int, reason: PlaybackFailure) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.always("/channel.ts", .status(status))
        await #expect(throws: reason) {
            try await StreamProbe.run(base.appending(path: "channel.ts"), session: PlaybackNetwork.makeSession())
        }
    }

    @Test func readsTheHeadAndRanges() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        let session = PlaybackNetwork.makeSession()
        let film = try await StreamProbe.run(base.appending(path: "film.mp4"), session: session)
        #expect(film.acceptsRanges)
        #expect(film.status == 206)
        #expect(film.contentType == "video/mp4")
        let size = try Data(contentsOf: server.root.appending(path: "film.mp4")).count
        #expect(film.length == size)
        await server.always("/film.mp4", .ignoreRanges)
        let noRanges = try await StreamProbe.run(base.appending(path: "film.mp4"), session: session)
        #expect(!noRanges.acceptsRanges)
        #expect(noRanges.length == size)
        let hls = try await StreamProbe.run(base.appending(path: "hls/index.m3u8"), session: session)
        #expect(hls.sniff == .hls)
    }

    @Test func aRefusedConnectionIsAReason() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.always("/channel.ts", .refuse)
        await #expect(throws: PlaybackFailure.stoppedSendingData) {
            try await StreamProbe.run(base.appending(path: "channel.ts"), session: PlaybackNetwork.makeSession())
        }
    }
}
