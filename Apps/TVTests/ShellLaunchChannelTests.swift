import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The last channel started at launch on Apple TV from what was saved,
/// before its source's list loads, against a scripted loader.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellLaunchChannelTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let defaults: UserDefaults
    let launchDirectory = FileManager.default.temporaryDirectory.appending(path: "shell-launch-tests-\(UUID().uuidString)")
    let model: ShellModel
    let login = SavedChannel.Login(username: "alice", password: "s3cr3t-pass")

    let sourceA = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let sourceB = SourceDescriptor(
        name: "B", kind: .xtream, url: URL(string: "http://b.example") ?? URL(fileURLWithPath: "/"), credentialKey: "b")

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "shell-launch-tests-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        var dependencies = ShellModel.Dependencies(
            engine: engine,
            load: { try await loader.load($0) },
            hasLogin: { _ in true },
            recents: RecentsStore(defaults: defaults, launchDirectory: launchDirectory),
            sleep: { try await clock.sleep($0) },
            guide: nil)
        let sourceB = sourceB.id
        let login = login
        dependencies.launchLogins = { $0.id == sourceB ? [login] : [] }
        model = ShellModel(dependencies)
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults, launchDirectory: launchDirectory) }

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

    private func news(_ link: String = "http://b.example/live/alice/s3cr3t-pass/7.ts") -> Channel {
        Channel(
            id: "news", name: "News", streamURL: URL(string: link) ?? URL(fileURLWithPath: "/"), number: 7, hasCatchup: true,
            sourceID: sourceB.id)
    }

    /// News saved for launch on source B, then launch with both sources loading.
    private func launch() async {
        store.write(LastChannelKey(sourceID: sourceB.id, channelID: "news"))
        store.saveLaunch(news(), logins: [login])
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceA.id) && loader.isWaiting(sourceB.id) }, "both sources loading")
    }

    // MARK: session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads

    @Test("tvos-shell/back-to-the-last-channel-on-launch the saved channel plays before its source loads, past the 10 seconds")
    func startsBeforeTheList() async {
        await launch()
        await wait({ engine.plays > 0 }, "the saved channel plays")
        #expect(engine.loaded == [news().streamURL])
        #expect(model.tuned?.id == "news")
        clock.advance(by: .seconds(11))
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await settle()
        #expect(engine.loaded.count == 1, "neither the deadline nor another source changes the channel")
    }

    @Test(
        "session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads a source whose channels are not saved waits"
    )
    func notSaved() async {
        store.write(LastChannelKey(sourceID: sourceB.id, channelID: "news"))
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceB.id) })
        await settle()
        #expect(engine.loaded.isEmpty)
        loader.finish(sourceB.id, with: [news()])
        await wait({ engine.plays > 0 })
        #expect(model.tuned?.id == "news")
    }

    // MARK: session-restore-and-recently-watched/the-fresh-list-decides

    @Test("session-restore-and-recently-watched/the-fresh-list-decides the same stream plays on with the list's details")
    func sameStream() async {
        await launch()
        await wait({ engine.plays > 0 })
        loader.finish(sourceB.id, with: [news()])
        await wait({ model.tuned?.hasCatchup == true }, "the list's channel takes over")
        #expect(engine.loaded.count == 1, "no reload")
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a changed link tunes again")
    func changedLink() async {
        await launch()
        await wait({ engine.plays > 0 })
        let moved = news("http://b2.example/live/alice/s3cr3t-pass/7.ts")
        loader.finish(sourceB.id, with: [moved])
        await wait({ engine.loaded.count == 2 })
        #expect(engine.loaded.last == moved.streamURL)
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides on Apple TV a channel the list lacks gives way to the first channel")
    func gone() async {
        await launch()
        await wait({ engine.plays > 0 })
        loader.finish(sourceA.id, with: [.fixture("a1")])
        await settle()
        loader.finish(sourceB.id, with: [.fixture("b1")])
        await wait({ engine.loaded.last == Channel.fixture("a1").streamURL }, "the first source's first channel plays")
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a failed start tunes again from the list")
    func failedStart() async {
        engine.failLoads = true
        await launch()
        await wait({ model.player.failure != nil })
        engine.failLoads = false
        loader.finish(sourceB.id, with: [news()])
        await wait({ engine.loaded.count == 2 && engine.plays > 0 })
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a list that fails leaves the channel playing")
    func listFails() async {
        await launch()
        await wait({ engine.plays > 0 })
        loader.fail(sourceB.id, with: URLError(.notConnectedToInternet))
        await settle()
        #expect(model.tuned?.id == "news")
        #expect(engine.loaded.count == 1)
    }

    // MARK: session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login the file never holds the login")
    func fileHoldsNoLogin() async throws {
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceB.id) })
        loader.finish(sourceB.id, with: [news()])
        await wait({ engine.plays > 0 })
        await wait({ store.launch.read() != nil }, "saved after the stream loads")
        let text = String(decoding: try Data(contentsOf: store.launch.file), as: UTF8.self)
        #expect(text.contains("news"))
        #expect(!text.contains("alice") && !text.contains("s3cr3t"))
    }
}
