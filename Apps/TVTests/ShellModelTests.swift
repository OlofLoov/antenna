import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Spec 0015, the shell's launch tune and pause rules, against a scripted
/// loader, a recording engine and a clock advanced by hand.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellModelTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let defaults: UserDefaults
    let model: ShellModel

    let sourceA = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let sourceB = SourceDescriptor(name: "B", kind: .m3u, url: URL(fileURLWithPath: "/b.m3u"))

    init() throws {
        let suite = "shell-tests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        let loader = loader
        let clock = clock
        model = ShellModel(
            .init(
                engine: engine,
                load: { try await loader.load($0) },
                hasLogin: { _ in true },
                lastChannel: LastChannelStore(defaults: defaults),
                sleep: { try await clock.sleep($0) },
                guide: nil))
    }

    private var store: LastChannelStore { LastChannelStore(defaults: defaults) }

    /// Yields until `condition` holds, failing after a few thousand turns.
    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    /// Lets queued tasks run when there is nothing to wait for.
    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    private func launch(remembering channel: Channel? = nil) async {
        if let channel { store.write(LastChannelKey(sourceID: sourceB.id, channelID: channel.id)) }
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceA.id) && loader.isWaiting(sourceB.id) }, "both sources loading")
    }

    private func playing(_ channel: Channel) async {
        await wait({ engine.loaded.last == channel.streamURL && engine.plays > 0 }, "\(channel.id) playing")
    }

    // MARK: tvos-shell/back-to-the-last-channel-on-launch

    @Test("tvos-shell/back-to-the-last-channel-on-launch the remembered channel plays once its source loads")
    func remembered() async {
        let wanted = Channel.fixture("b2")
        await launch(remembering: wanted)

        loader.finish(sourceA.id, with: [.fixture("a1")])
        await settle()
        #expect(engine.loaded.isEmpty, "the other source finishing first must not tune")

        loader.finish(sourceB.id, with: [.fixture("b1"), wanted])
        await playing(wanted)
        #expect(engine.loaded == [wanted.streamURL])
        await wait({ store.read() == LastChannelKey(sourceID: sourceB.id, channelID: wanted.id) }, "last channel written")
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch a remembered channel that is gone falls back to the first source to load")
    func rememberedGone() async {
        await launch(remembering: .fixture("gone"))

        loader.finish(sourceA.id, with: [.fixture("a1"), .fixture("a2")])
        await settle()
        #expect(engine.loaded.isEmpty)

        loader.finish(sourceB.id, with: [.fixture("b1")])
        await playing(.fixture("a1"))
        #expect(engine.loaded == [Channel.fixture("a1").streamURL])
        let written = LastChannelKey(sourceID: sourceA.id, channelID: Channel.fixture("a1").id)
        await wait({ store.read() == written }, "the channel that played is remembered")
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch after 10 seconds the first source to load plays and a late source changes nothing")
    func deadline() async {
        await launch(remembering: .fixture("b2"))
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await settle()

        clock.advance(by: .seconds(9))
        await settle()
        #expect(engine.loaded.isEmpty, "nothing tunes before the deadline")

        clock.advance(by: .seconds(1))
        await playing(.fixture("a1"))

        loader.finish(sourceB.id, with: [.fixture("b1"), .fixture("b2")])
        await settle()
        #expect(engine.loaded == [Channel.fixture("a1").streamURL])
    }

    // tvos-shell/back-to-the-last-channel-on-launch
    @Test("a remembered source that loads after 10 seconds plays its first channel, as the spec words it")
    func slowRememberedSource() async {
        await launch(remembering: .fixture("b2"))
        loader.finish(sourceA.id, with: [])
        clock.advance(by: .seconds(10))
        await settle()
        #expect(engine.loaded.isEmpty)

        loader.finish(sourceB.id, with: [.fixture("b1"), .fixture("b2")])
        await playing(.fixture("b1"))
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch with nothing remembered the first source to finish with channels plays")
    func nothingRemembered() async {
        await launch()
        loader.finish(sourceB.id, with: [])
        await settle()
        #expect(engine.loaded.isEmpty, "a source with no channels does not count")

        loader.finish(sourceA.id, with: [.fixture("a1")])
        await playing(.fixture("a1"))
    }

}

// MARK: tvos-shell/the-video-pauses-behind-movies-series-and-search

extension ShellModelTests {
    private func playingFirstChannel() async {
        await launch()
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await playing(.fixture("a1"))
    }

    /// Waits for the pause timer to ask for its sleep and checks it asks for 30 s.
    private func pauseTimerStarted() async {
        await wait { clock.requested.last == .seconds(30) }
    }

    // tvos-shell/the-video-pauses-behind-movies-series-and-search
    @Test("30 seconds behind Movies pause the video and Live resumes it without a reload")
    func pauseBehindMovies() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        await pauseTimerStarted()
        await settle()
        #expect(engine.pauses == 0, "nothing pauses when Movies opens")

        clock.advance(by: .seconds(29))
        await settle()
        #expect(engine.pauses == 0)

        clock.advance(by: .seconds(1))
        await wait { engine.pauses == 1 }
        let plays = engine.plays

        _ = await model.select(.live)
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1, "resuming does not load the channel again")
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search the timer runs on across Search and Series, and Guide resumes")
    func pauseAcrossContentTabs() async {
        await playingFirstChannel()
        _ = await model.select(.search)
        await pauseTimerStarted()
        clock.advance(by: .seconds(20))
        _ = await model.select(.series)
        clock.advance(by: .seconds(10))
        await wait { engine.pauses == 1 }

        _ = await model.select(.guide)
        #expect(engine.loaded.count == 1)
        #expect(engine.state == .playing)
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search going back before 30 seconds neither pauses nor plays")
    func backBeforeDeadline() async {
        await playingFirstChannel()
        let plays = engine.plays
        _ = await model.select(.movies)
        await pauseTimerStarted()
        clock.advance(by: .seconds(10))
        _ = await model.select(.live)
        clock.advance(by: .seconds(30))
        await settle()
        #expect(engine.pauses == 0)
        #expect(engine.plays == plays)
    }
}

// MARK: Edge cases

extension ShellModelTests {
    @Test("tvos-shell/sources-change-while-the-app-runs removing every source stops the video and shows the empty screen")
    func allSourcesRemoved() async {
        await launch()
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await playing(.fixture("a1"))

        model.sourcesChanged([])
        #expect(model.liveScreen == .empty)
        #expect(model.tuned == nil)
        await wait({ engine.stops == 1 }, "the engine stops")
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch coming back to the foreground plays the same channel without a reload")
    func foreground() async {
        await launch()
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await playing(.fixture("a1"))
        let plays = engine.plays

        await model.becameActive()
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1)
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch a channel whose id holds a link is not remembered")
    func linkIDsNotStored() {
        let channel = Channel(
            id: "news#http://host/a.ts", name: "News", streamURL: URL(fileURLWithPath: "/a.ts"), sourceID: UUID())
        #expect(LastChannelKey(channel) == nil)
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch an unreadable stored value reads as nothing")
    func unreadable() {
        defaults.set(Data("not json".utf8), forKey: LastChannelStore.defaultsKey)
        #expect(store.read() == nil)
    }
}
