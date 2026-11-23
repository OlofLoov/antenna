import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The last channel started at launch from what was saved, before its
/// source's list loads, on iPhone, iPad and Mac, with sources held by hand.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct LiveLaunchChannelTests {
    let defaults: UserDefaults
    let launchDirectory = FileManager.default.temporaryDirectory.appending(path: "live-launch-tests-\(UUID().uuidString)")
    let home = SourceDescriptor(name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))
    let cabin = SourceDescriptor(
        name: "Cabin", kind: .xtream, url: URL(string: "http://cabin.example") ?? URL(fileURLWithPath: "/"), credentialKey: "cabin")
    let login = SavedChannel.Login(username: "alice", password: "s3cr3t-pass")

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "live-launch-tests-\(UUID().uuidString)"))
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults, launchDirectory: launchDirectory) }

    /// Answers each source from `playlists` once released; a source missing
    /// from it fails as offline.
    @MainActor final class Sources {
        var playlists: [UUID: [Channel]] = [:]
        var held: Set<UUID> = []
        private var waiting: [UUID: [CheckedContinuation<Void, Never>]] = [:]

        func load(_ id: UUID) async throws -> [Channel] {
            if held.contains(id) { await withCheckedContinuation { waiting[id, default: []].append($0) } }
            guard let channels = playlists[id] else { throw URLError(.notConnectedToInternet) }
            return channels
        }

        func release(_ id: UUID) {
            held.remove(id)
            waiting.removeValue(forKey: id)?.forEach { $0.resume() }
        }
    }

    private func film(_ link: String = "http://cabin.example/live/alice/s3cr3t-pass/1.ts") -> Channel {
        var channel = Channel(
            id: "film", name: "Film", streamURL: URL(string: link) ?? URL(fileURLWithPath: "/"), number: 5, hasCatchup: true,
            catchupDays: 7,
            sourceID: cabin.id)
        channel.position = 0
        return channel
    }

    private func news() -> Channel {
        Channel(id: "news", name: "News", streamURL: URL(fileURLWithPath: "/news.ts"))
    }

    /// Film saved for launch as the last channel.
    private func saveFilm() {
        store.write(LastChannelKey(sourceID: cabin.id, channelID: "film"))
        store.saveLaunch(film(), logins: [login])
    }

    private func model(_ sources: Sources, engine: PlayerTestEngine, hasLogin: Bool = true) -> LiveModel {
        var dependencies = LiveModel.Dependencies(
            engine: engine,
            load: { source in Playlist(channels: try await sources.load(source.id)) },
            hasLogin: { _ in hasLogin }, programmes: UITestingLive.guide, recents: store)
        let cabinID = cabin.id
        let login = login
        dependencies.launchLogins = { source in source.id == cabinID ? [login] : [] }
        return LiveModel(dependencies)
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

    /// Launches with Cabin held and Home loaded, and waits for Film to play.
    private func launch(_ sources: Sources, engine: PlayerTestEngine) async -> LiveModel {
        saveFilm()
        sources.playlists = [home.id: [news()]]
        sources.held = [cabin.id]
        let live = model(sources, engine: engine)
        live.appeared()
        live.screenRestored(onLive: true)
        live.sceneBecameActive()
        live.sourcesChanged([home, cabin])
        await wait({ engine.plays > 0 }, "the saved channel plays")
        return live
    }

    // MARK: session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads

    @Test("session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads Film plays while Cabin still loads")
    func startsBeforeTheList() async {
        let engine = PlayerTestEngine()
        let live = await launch(Sources(), engine: engine)
        #expect(live.playing?.id == "film")
        #expect(engine.loaded == [film().streamURL], "the login came back from the Keychain answer")
        #expect(live.sources.first { $0.id == cabin.id }?.state == .loading)
    }

    @Test("session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads nothing starts without the login")
    func noLogin() async {
        saveFilm()
        let sources = Sources()
        sources.held = [cabin.id]
        let engine = PlayerTestEngine()
        let live = model(sources, engine: engine, hasLogin: false)
        live.appeared()
        live.screenRestored(onLive: true)
        live.sceneBecameActive()
        live.sourcesChanged([home, cabin])
        await settle()
        #expect(live.playing == nil)
        #expect(engine.loaded.isEmpty)
    }

    @Test("session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads nothing starts before Live shows")
    func waitsForLive() async {
        saveFilm()
        let sources = Sources()
        sources.held = [cabin.id]
        let engine = PlayerTestEngine()
        let live = model(sources, engine: engine)
        live.sourcesChanged([home, cabin])
        await settle()
        #expect(engine.loaded.isEmpty)
        live.appeared()
        live.screenRestored(onLive: true)
        live.sceneBecameActive()
        await wait({ engine.plays > 0 })
        #expect(live.playing?.id == "film")
    }

    @Test("session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads a channel picked first wins")
    func pickedFirst() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        let live = await launch(sources, engine: engine)
        await live.settled(waitingOn: home.id)
        let picked = live.channels[0]
        live.pick(picked)
        sources.playlists[cabin.id] = [film()]
        sources.release(cabin.id)
        await wait({ live.sources.first { $0.id == cabin.id }?.state == .loaded(channels: 1) })
        await settle()
        #expect(live.playing?.id == picked.id)
    }

    // MARK: session-restore-and-recently-watched/the-fresh-list-decides

    @Test("session-restore-and-recently-watched/the-fresh-list-decides the same stream plays on with the list's details")
    func sameStream() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        let live = await launch(sources, engine: engine)
        #expect(live.playing?.hasCatchup == false, "catch-up is not saved")
        sources.playlists[cabin.id] = [film()]
        sources.release(cabin.id)
        await wait({ live.playing?.hasCatchup == true }, "the list's channel takes over")
        #expect(engine.loaded.count == 1, "no reload")
        #expect(live.player.subject?.channel.hasCatchup == true)
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a changed link tunes again")
    func changedLink() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        let live = await launch(sources, engine: engine)
        let moved = film("http://cabin2.example/live/alice/s3cr3t-pass/1.ts")
        sources.playlists[cabin.id] = [moved]
        sources.release(cabin.id)
        await wait({ engine.loaded.count == 2 })
        #expect(engine.loaded.last == moved.streamURL)
        #expect(live.playing?.streamURL == moved.streamURL)
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a channel the list lacks stops")
    func gone() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        let live = await launch(sources, engine: engine)
        sources.playlists[cabin.id] = [Channel(id: "other", name: "Other", streamURL: URL(fileURLWithPath: "/o.ts"))]
        sources.release(cabin.id)
        await wait({ live.playing == nil }, "the channel stops")
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a failed start tunes again from the list")
    func failedStart() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        engine.failNextLoad = .notFound
        saveFilm()
        sources.playlists = [home.id: [news()]]
        sources.held = [cabin.id]
        let live = model(sources, engine: engine)
        live.appeared()
        live.screenRestored(onLive: true)
        live.sceneBecameActive()
        live.sourcesChanged([home, cabin])
        await wait({ live.player.failure != nil }, "the saved stream fails")
        sources.playlists[cabin.id] = [film()]
        sources.release(cabin.id)
        await wait({ engine.loaded.count == 2 && engine.plays > 0 }, "tuned again")
        #expect(live.playing?.hasCatchup == true)
    }

    @Test("session-restore-and-recently-watched/the-fresh-list-decides a list that fails leaves the channel playing")
    func listFails() async {
        let sources = Sources()
        let engine = PlayerTestEngine()
        let live = await launch(sources, engine: engine)
        sources.release(cabin.id)
        await wait({ live.sources.first { $0.id == cabin.id }?.state == .offline })
        await settle()
        #expect(live.playing?.id == "film")
        #expect(engine.loaded.count == 1)
    }

    // MARK: session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login the file never holds the login")
    func fileHoldsNoLogin() async throws {
        let sources = Sources()
        sources.playlists = [home.id: [news()], cabin.id: [film()]]
        let live = model(sources, engine: PlayerTestEngine())
        live.sourcesChanged([home, cabin])
        await live.settled()
        live.pick(try #require(live.channels.first { $0.id == "film" }))
        await wait({ store.launch.read() != nil }, "saved after the stream loads")
        let text = String(decoding: try Data(contentsOf: store.launch.file), as: UTF8.self)
        #expect(text.contains("film"))
        #expect(!text.contains("alice") && !text.contains("s3cr3t"))
        #expect(defaults.dictionaryRepresentation().values.allSatisfy { !"\($0)".contains("s3cr3t") })
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a deleted source clears what was saved")
    func deletedSource() {
        saveFilm()
        #expect(store.readLaunch() != nil)
        RecentsStore.remove(source: cabin.id, from: defaults, launchDirectory: launchDirectory)
        #expect(store.launch.read() == nil)
    }

    @Test(
        "session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a saved channel that is not the last one is not used")
    func notTheLastChannel() {
        saveFilm()
        store.write(LastChannelKey(sourceID: home.id, channelID: "news"))
        #expect(store.readLaunch() == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a pruned profile loses its file")
    func prunedProfile() {
        let kids = UUID()
        let kidsStore = RecentsStore(defaults: defaults, profile: kids, launchDirectory: launchDirectory)
        kidsStore.saveLaunch(film(), logins: [login])
        saveFilm()
        LaunchChannelStore.prune(keeping: [Profile.mainID], in: launchDirectory)
        #expect(kidsStore.launch.read() == nil)
        #expect(store.launch.read() != nil)
    }
}

extension LiveModel {
    /// Waits for `source`'s load alone, for tests that hold another one.
    fileprivate func settled(waitingOn source: UUID) async {
        await loads[source]?.value
    }
}
