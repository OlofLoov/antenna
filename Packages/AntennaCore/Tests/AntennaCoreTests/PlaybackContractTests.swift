import AntennaCore
import Foundation
import Testing

/// An engine that records the options each load got.
private final class OptionsRecorder: PlaybackEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [PlaybackOptions] = []

    var loads: [PlaybackOptions] { lock.withLock { recorded } }

    var state: PlaybackState { .idle }
    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }
    func load(_ url: URL, options: PlaybackOptions) async throws { lock.withLock { recorded.append(options) } }
    func play() async {}
    func pause() async {}
    func stop() async {}
    func seek(to time: Duration) async throws { throw SeekRefusal.live }
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { Broadcast(PlaybackState.idle).stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
    func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
    func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}

@Suite struct PlaybackContractTests {
    @Test func loadWithoutOptionsForwardsDefaults() async throws {
        let engine = OptionsRecorder()
        try await engine.load(try #require(URL(string: "http://x/a.ts")))
        #expect(engine.loads == [PlaybackOptions()])
        #expect(PlaybackOptions().isLive == nil)
        #expect(PlaybackOptions().startPosition == nil)
    }
}

@Suite(.timeLimit(.minutes(1))) struct BroadcastTests {
    @Test func aNewSubscriberGetsTheCurrentValueFirst() async {
        let broadcast = Broadcast(PlaybackState.idle)
        broadcast.send(.loading)
        var iterator = broadcast.stream().makeAsyncIterator()
        #expect(await iterator.next() == .loading)
    }

    @Test func everySubscriberGetsEveryValue() async {
        let broadcast = Broadcast(0)
        var first = broadcast.stream().makeAsyncIterator()
        var second = broadcast.stream().makeAsyncIterator()
        broadcast.send(1)
        broadcast.send(2)
        #expect(await first.next() == 0)
        #expect(await first.next() == 1)
        #expect(await first.next() == 2)
        #expect(await second.next() == 0)
        #expect(await second.next() == 1)
        #expect(await second.next() == 2)
    }

    @Test func sendIfChangedSkipsRepeats() async {
        let broadcast = Broadcast(PlaybackState.idle)
        var iterator = broadcast.stream().makeAsyncIterator()
        broadcast.sendIfChanged(.idle)
        broadcast.sendIfChanged(.playing)
        broadcast.sendIfChanged(.playing)
        broadcast.send(.paused)
        #expect(await iterator.next() == .idle)
        #expect(await iterator.next() == .playing)
        #expect(await iterator.next() == .paused)
    }

    @Test func streamsEndWhenTheBroadcastGoesAway() async {
        var broadcast: Broadcast<Int>? = Broadcast(0)
        guard let stream = broadcast?.stream() else { return }
        broadcast = nil
        var values: [Int] = []
        for await value in stream { values.append(value) }
        #expect(values == [0])
    }
}
