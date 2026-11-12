import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Shelf links in the shell, against a scripted loader, a recording engine
/// and a clock advanced by hand.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellShelfLinkTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let defaults: UserDefaults
    let model: ShellModel

    let sourceA = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let sourceB = SourceDescriptor(name: "B", kind: .m3u, url: URL(fileURLWithPath: "/b.m3u"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "shell-shelf-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        model = ShellModel(
            .init(
                engine: engine, load: { try await loader.load($0) }, hasLogin: { _ in true }, recents: RecentsStore(defaults: defaults),
                sleep: { try await clock.sleep($0) }, guide: nil))
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

    private func item(_ channel: Channel, in source: SourceDescriptor) throws -> UUID {
        try #require(TopShelfItemID.channel(Channel.tagged([channel], sourceID: source.id)[0]))
    }

    /// Launches remembering b7, with a link held as the shell starts.
    private func launch(link: UUID?) async {
        RecentsStore(defaults: defaults).write(LastChannelKey(sourceID: sourceB.id, channelID: Channel.fixture("b7").id))
        if let link { model.holdShelfItem(link) }
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceA.id) && loader.isWaiting(sourceB.id) }, "both sources loading")
    }

    @Test(
        "tvos-shell/play-or-resume-from-a-shelf-link a link at launch plays its channel once its source loads, never the last channel"
    )
    func atLaunch() async throws {
        let wanted = Channel.fixture("a104")
        await launch(link: try item(wanted, in: sourceA))
        loader.finish(sourceB.id, with: [.fixture("b7")])
        await settle()
        #expect(model.resolveShelfItem(titles: [], titlesPending: false) == .waiting)
        #expect(engine.loaded.isEmpty, "the last channel waits for the link")
        loader.finish(sourceA.id, with: [.fixture("a1"), wanted])
        await wait { model.channels.count == 3 }
        guard case .tuned = model.resolveShelfItem(titles: [], titlesPending: false) else {
            Issue.record("the link's channel did not tune")
            return
        }
        await wait({ engine.loaded == [wanted.streamURL] }, "the link's channel loads")
        await settle()
        #expect(engine.loaded == [wanted.streamURL], "one load in total")
        #expect(model.tab == .live)
    }

    @Test("tvos-shell/play-or-resume-from-a-shelf-link a link whose channel is gone is dropped and the launch goes on as usual")
    func goneAtLaunch() async throws {
        await launch(link: try item(.fixture("removed"), in: sourceA))
        loader.finish(sourceA.id, with: [.fixture("a1")])
        loader.finish(sourceB.id, with: [.fixture("b7")])
        await wait { model.channels.count == 2 }
        #expect(model.resolveShelfItem(titles: [], titlesPending: false) == .dropped)
        await wait({ engine.loaded == [Channel.fixture("b7").streamURL] }, "the last channel plays")
    }

    @Test("tvos-shell/play-or-resume-from-a-shelf-link a link whose source does not load within the deadline is dropped")
    func deadline() async throws {
        await launch(link: try item(.fixture("a1"), in: sourceA))
        loader.finish(sourceB.id, with: [.fixture("b7")])
        await settle()
        #expect(model.resolveShelfItem(titles: [], titlesPending: false) == .waiting)
        clock.advance(by: .seconds(10))
        await wait({ model.shelfItem == nil }, "the link is dropped")
        await wait({ engine.loaded == [Channel.fixture("b7").streamURL] }, "the launch goes on without it")
    }

    @Test("top-shelf/select-a-tile-to-watch a link while running plays the channel as going to Live does")
    func whileRunning() async throws {
        await launch(link: nil)
        loader.finish(sourceA.id, with: [.fixture("a1"), .fixture("a2")])
        loader.finish(sourceB.id, with: [.fixture("b7")])
        await wait({ engine.loaded == [Channel.fixture("b7").streamURL] }, "the last channel plays")
        _ = await model.select(.guide)
        model.settingsOpen = true
        model.holdShelfItem(try item(.fixture("a2"), in: sourceA))
        guard case .tuned = model.resolveShelfItem(titles: [], titlesPending: false) else {
            Issue.record("the channel did not tune")
            return
        }
        await wait({ model.tab == .live }, "Live shows")
        #expect(!model.settingsOpen)
        await wait({ engine.loaded.last == Channel.fixture("a2").streamURL }, "the channel plays")
    }

    @Test("top-shelf/select-a-tile-to-watch a title link hands back the title to resume")
    func title() async throws {
        await launch(link: nil)
        let movie = ShelfTitle(id: "xtream#h#vod#9", kind: .movie, sourceID: sourceB.id, name: "Dune")
        model.holdShelfItem(TopShelfItemID.title(movie))
        #expect(model.resolveShelfItem(titles: [], titlesPending: true) == .waiting, "titles still loading")
        #expect(model.resolveShelfItem(titles: [movie], titlesPending: false) == .resume(movie))
        #expect(model.shelfItem == nil)
    }

    @Test("top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was the add-favorites tile and damaged links are not kept")
    func inboxIgnores() throws {
        let inbox = TopShelfInbox()
        inbox.receive(TopShelfLink.empty.url)
        #expect(inbox.pending == nil)
        inbox.receive(try #require(URL(string: "antenna://topShelf/not-an-id")))
        #expect(inbox.pending == nil)
        let id = UUID()
        inbox.receive(TopShelfLink.item(id).url)
        #expect(inbox.take() == id)
        #expect(inbox.pending == nil, "a link is taken once")
    }

    @Test("top-shelf/the-paywall-and-setup-come-first a link while the paywall or setup shows is dropped")
    func gates() {
        let inbox = TopShelfInbox()
        let held = UUID()
        inbox.receive(TopShelfLink.item(held).url)
        inbox.gateShown()
        #expect(inbox.pending == nil, "a link waiting at launch goes when setup appears")
        inbox.receive(TopShelfLink.item(UUID()).url)
        #expect(inbox.pending == nil, "a link arriving under the paywall is dropped")
        inbox.gateHidden()
        inbox.receive(TopShelfLink.item(held).url)
        #expect(inbox.pending == held, "once the app is open links work again")
    }
}
