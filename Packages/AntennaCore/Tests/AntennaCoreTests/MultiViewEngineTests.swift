import AntennaCore
import Foundation
import Testing

/// What multi-view needs from the engines: trading players with no reload,
/// a busy decoder that is never retried, and a provider's stream limit
/// that fails at once while another tile plays from the same source.
@Suite(.timeLimit(.minutes(1))) struct MultiViewEngineTests {
    @Test("multi-view/leave-multi-view two routed engines trade their players with no reload")
    func exchange() async throws {
        let log = EngineLog()
        let shellSystem = FakeEngine("shell.system", log: log)
        let shellDemuxer = FakeEngine("shell.demuxer", log: log)
        let tileSystem = FakeEngine("tile.system", log: log)
        let tileDemuxer = FakeEngine("tile.demuxer", log: log)
        let shell = RoutedEngine(system: shellSystem, demuxer: shellDemuxer)
        let tile = RoutedEngine(system: tileSystem, demuxer: tileDemuxer)
        try await tile.load(.test("http://x/2.ts"))
        await tile.play()
        let states = await shell.states()
        await shell.exchange(with: tile)
        #expect(shell.demuxer === tileDemuxer)
        #expect(tile.demuxer === shellDemuxer)
        #expect(await shell.activeEngine === tileDemuxer)
        #expect(await shell.state == .playing)
        #expect(await tile.state == .idle)
        #expect(await log.entries == ["tile.demuxer.load 2.ts", "tile.demuxer.play"])
        var seen: [PlaybackState] = []
        for await state in states {
            seen.append(state)
            if state == .playing { break }
        }
        #expect(seen.last == .playing)
        await tileDemuxer.send(.buffering)
        #expect(await eventually { await shell.states().first { _ in true } == .buffering })
    }

    @Test("multi-view/a-tile-that-fails-says-why a busy decoder is never retried")
    func decoderNotRetried() {
        #expect(!RetryPolicy.tune.retries(.noDecoderFree))
        #expect(!RetryPolicy.drop.retries(.noDecoderFree))
    }

    @Test(
        "multi-view/a-tile-that-fails-says-why with another tile on the same source a busy server or server error fails at once",
        arguments: [PlaybackFailure.serverBusy, .serverError])
    func refusalsFinal(failure: PlaybackFailure) {
        #expect(RetryPolicy.tune.retries(failure))
        #expect(!RetryPolicy.tune.refusals(final: true).retries(failure))
        #expect(RetryPolicy.tune.refusals(final: true).retries(.stoppedSendingData))
        var budget = ReconnectBudget()
        budget.refusalsAreFinal = true
        #expect(budget.dropped(failure, at: .now) == nil)
        #expect(budget.dropped(.timedOut, at: .now) != nil)
        budget.refusalsAreFinal = false
        #expect(budget.dropped(failure, at: .now) != nil)
    }
}
