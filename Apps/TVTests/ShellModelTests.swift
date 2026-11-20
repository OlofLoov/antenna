import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The tvos-shell capability, the shell's launch tune and pause rules, against a scripted
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
                recents: RecentsStore(defaults: defaults),
                sleep: { try await clock.sleep($0) },
                guide: nil))
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults) }

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

    // The nightly Apple TV UI tests played b1 instead of a1 once tagging moved off the main actor.
    @Test("tvos-shell/back-to-the-last-channel-on-launch a source whose load returned first plays, however long its channels take to tag")
    func firstToLandWins() async {
        await launch()
        let many = (0..<50_000).map { Channel.fixture("a\($0)") }
        loader.finish(sourceA.id, with: many)
        loader.finish(sourceB.id, with: [.fixture("b1")])
        // Tagging 50 000 channels takes longer than the yields `wait` allows.
        let deadline = ContinuousClock.now + .seconds(20)
        while engine.loaded.isEmpty, ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(engine.loaded == [Channel.fixture("a0").streamURL])
    }
}

// MARK: tvos-shell/the-video-pauses-behind-movies-series-and-search

extension ShellModelTests {
    private func playingFirstChannel() async {
        await launch()
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await playing(.fixture("a1"))
    }

    /// Waits for the stop timer to ask for its sleep and checks it asks for 30 s.
    private func stopTimerStarted() async {
        await wait { clock.requested.last == .seconds(30) }
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search Movies pauses at once and Live resumes without a reload")
    func pauseBehindMovies() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        #expect(engine.pauses == 1, "no sound carries on behind Movies")
        #expect(engine.state == .paused)
        await stopTimerStarted()
        clock.advance(by: .seconds(29))
        await settle()
        #expect(engine.stops == 0)
        let plays = engine.plays

        _ = await model.select(.live)
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1, "resuming does not load the channel again")
        #expect(engine.state == .playing)
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search 30 seconds behind a tab stop the channel and Live tunes it again")
    func stopBehindMovies() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        await stopTimerStarted()
        clock.advance(by: .seconds(30))
        await wait { engine.stops == 1 }
        #expect(engine.state == .idle, "the provider's connection is free")

        _ = await model.select(.live)
        await wait { engine.loaded.count == 2 }
        #expect(engine.loaded.last == Channel.fixture("a1").streamURL)
        await wait { engine.state == .playing }
        #expect(model.tuned?.id == Channel.fixture("a1").id)
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search the timer runs on across Search and Series, and Guide tunes again")
    func stopAcrossContentTabs() async {
        await playingFirstChannel()
        _ = await model.select(.search)
        #expect(engine.pauses == 1)
        await stopTimerStarted()
        clock.advance(by: .seconds(20))
        _ = await model.select(.series)
        #expect(engine.pauses == 1, "moving between content tabs pauses nothing more")
        clock.advance(by: .seconds(10))
        await wait { engine.stops == 1 }

        _ = await model.select(.guide)
        await wait { engine.loaded.count == 2 }
        await wait { engine.state == .playing }
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search going back before 30 seconds stops nothing")
    func backBeforeDeadline() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        await stopTimerStarted()
        clock.advance(by: .seconds(10))
        _ = await model.select(.live)
        clock.advance(by: .seconds(30))
        await settle()
        #expect(engine.stops == 0)
        #expect(engine.loaded.count == 1)
        #expect(engine.state == .playing)
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search a movie that stopped the paused channel, then Guide, tunes it again")
    func movieStoppedPausedChannel() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        await engine.stop()
        _ = await model.select(.guide)
        await wait { engine.loaded.count == 2 }
        await wait { engine.state == .playing }
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search a channel the user paused stays paused and is not stopped")
    func userPauseStands() async {
        await playingFirstChannel()
        await engine.pause()
        _ = await model.select(.movies)
        #expect(engine.pauses == 1, "the shell pauses nothing more")
        await stopTimerStarted()
        clock.advance(by: .seconds(30))
        await settle()
        #expect(engine.stops == 0)
        let plays = engine.plays
        _ = await model.select(.live)
        #expect(engine.plays == plays)
        #expect(engine.state == .paused)
    }

    // Search, as a playlist without movies takes Movies away when it loads.
    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search a channel that finishes loading behind Search stays paused")
    func loadLandsBehindSearch() async {
        await launch()
        _ = await model.select(.search)
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await wait { engine.loaded.count == 1 }
        await settle()
        #expect(engine.plays == 0, "no sound starts behind Search")

        _ = await model.select(.live)
        await wait { engine.state == .playing }
        #expect(engine.loaded.count == 1)
    }

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search coming back from the background behind Movies plays nothing")
    func foregroundBehindMovies() async {
        await playingFirstChannel()
        _ = await model.select(.movies)
        let plays = engine.plays
        await model.becameActive()
        #expect(engine.plays == plays)
        #expect(engine.state == .paused)
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

    @Test("tvos-shell/back-to-the-last-channel-on-launch an M3U channel is remembered without its link")
    func m3uRemembered() async throws {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="news.uk",News
            http://panel:8080/live/alice/s3cr3t/1.ts
            #EXTINF:-1,Sport
            http://panel:8080/live/alice/s3cr3t/2.ts
            """
        let parsed = M3UParser().parse(text).channels
        await launch(remembering: parsed[1])
        loader.finish(sourceA.id, with: [.fixture("a1")])
        loader.finish(sourceB.id, with: parsed)
        await playing(parsed[1])
        await wait({ store.read()?.channelID == parsed[1].id }, "last channel written")
        let data = try #require(defaults.data(forKey: RecentsStore.lastChannelKey))
        let stored = String(decoding: data, as: UTF8.self)
        #expect(!stored.contains("alice") && !stored.contains("s3cr3t") && !stored.contains("panel"))
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch an unreadable stored value reads as nothing")
    func unreadable() {
        defaults.set(Data("not json".utf8), forKey: RecentsStore.lastChannelKey)
        #expect(store.read() == nil)
    }
}
