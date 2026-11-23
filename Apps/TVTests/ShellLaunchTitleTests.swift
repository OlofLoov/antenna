import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The title watched last at launch on Apple TV: the last channel waits for
/// its page, plays when it gives way, and loads behind it once it opens.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellLaunchTitleTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let defaults: UserDefaults
    let model: ShellModel

    let sourceA = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let sourceB = SourceDescriptor(name: "B", kind: .xtream, url: URL(fileURLWithPath: "/b"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "shell-launch-title-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        model = ShellModel(
            .init(
                engine: engine, load: { try await loader.load($0) }, hasLogin: { _ in true }, recents: RecentsStore(defaults: defaults),
                sleep: { try await clock.sleep($0) }, guide: nil))
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults) }

    private var movie: LastWatched {
        LastWatched(title: LastWatched.Title(sourceID: sourceB.id, titleID: "xtream#b#vod#1", kind: .movie))
    }

    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    /// Remembers b7 and `watched`, then launches with both sources loaded.
    private func launch(watched: LastWatched?) async {
        let b7 = Channel.tagged([.fixture("b7")], sourceID: sourceB.id)[0]
        store.write(LastChannelKey(sourceID: sourceB.id, channelID: b7.id))
        if let watched { store.write(watched) }
        model.reopenLastTitle()
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceA.id) && loader.isWaiting(sourceB.id) }, "both sources loading")
        loader.finish(sourceA.id, with: [.fixture("a1")])
        loader.finish(sourceB.id, with: [.fixture("b7")])
        await settle()
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch the last channel waits while the title watched last waits for its page")
    func waitsForTheTitle() async {
        await launch(watched: movie)
        #expect(model.launchTitle.holds)
        #expect(model.tuned == nil, "nothing plays full screen while the page may open")
        #expect(engine.loaded.isEmpty)
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch a title that gives way lets the last channel play full screen")
    func titleGivesWay() async {
        await launch(watched: movie)
        model.launchTitle.drop()
        await wait({ model.tuned != nil }, "the last channel plays")
        #expect(model.tuned?.id == Channel.fixture("b7").id)
        #expect(model.tab == .live)
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch past 10 seconds the title gives way and the last channel plays")
    func deadline() async {
        await launch(watched: movie)
        clock.advance(by: .seconds(9))
        await settle()
        #expect(model.tuned == nil)
        clock.advance(by: .seconds(1))
        await wait({ model.tuned != nil }, "the last channel plays at 10 seconds")
        #expect(model.tuned?.id == Channel.fixture("b7").id)
        #expect(!model.launchTitle.holds)
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch once the page opens the last channel loads behind it, held")
    func behindThePage() async {
        await launch(watched: movie)
        await model.launchTitleOpened(in: .movies)
        #expect(model.tab == .movies)
        #expect(!model.launchTitle.holds)
        await wait({ !engine.loaded.isEmpty }, "the last channel loads")
        #expect(model.tuned?.id == Channel.fixture("b7").id)
        #expect(model.behindContent, "the channel is held behind Movies")
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch after a channel, or with a shelf link, nothing waits")
    func nothingWaits() async throws {
        store.write(LastWatched.live)
        model.reopenLastTitle()
        #expect(!model.launchTitle.holds, "a channel watched last launches as before")
        store.write(movie)
        model.holdShelfItem(try #require(TopShelfItemID.channel(Channel.tagged([.fixture("a1")], sourceID: sourceA.id)[0])))
        model.reopenLastTitle()
        #expect(!model.launchTitle.holds, "a shelf link wins over the title")
    }

    @Test("session-restore-and-recently-watched/a-title-that-cannot-open-gives-way choosing a tab first gives way")
    func choosingATab() async {
        await launch(watched: movie)
        model.choose(.guide)
        #expect(!model.launchTitle.holds)
        await wait({ model.tuned != nil }, "the launch tune goes ahead")
    }
}
