import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// Reopening Live where the user left it on iPhone, iPad and Mac, with a
/// stored session and scripted sources.
@MainActor
@Suite struct LiveRestoreTests {
    let defaults: UserDefaults
    let home = SourceDescriptor(name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))
    let cabin = SourceDescriptor(name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "live-restore-tests-\(UUID().uuidString)"))
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults) }

    /// Answers each source from `playlists`; a source missing from it fails as offline.
    @MainActor final class Sources {
        var playlists: [UUID: [Channel]] = [:]
    }

    private func channel(_ id: String, group: String? = nil) -> Channel {
        Channel(id: id, name: id, streamURL: URL(fileURLWithPath: "/\(id).ts"), group: group)
    }

    private func model(_ sources: Sources, engine: PlayerTestEngine = PlayerTestEngine()) -> LiveModel {
        LiveModel(
            .init(
                engine: engine,
                load: { source in
                    guard let channels = sources.playlists[source.id] else { throw URLError(.notConnectedToInternet) }
                    return Playlist(channels: channels)
                },
                hasLogin: { _ in true }, programmes: UITestingLive.guide, recents: store))
    }

    // MARK: session-restore-and-recently-watched/reopen-on-the-same-tab-and-group

    @Test("session-restore-and-recently-watched/reopen-on-the-same-tab-and-group the picked group and tab come back")
    func groupAndTab() async {
        store.write(LiveSession(tab: .guide, group: .named(cabin.id, "Films")))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a")], cabin.id: [channel("film", group: "Films")]]
        let live = model(sources)
        #expect(live.restoredTab == .guide)
        live.sourcesChanged([home, cabin])
        await live.settled()
        #expect(live.group == .named(cabin.id, "Films"))
    }

    @Test("session-restore-and-recently-watched/reopen-on-the-same-tab-and-group Search and Settings open Live")
    func tabsNotRestored() {
        for tab in [LiveSession.Tab.search, .settings] {
            store.write(LiveSession(tab: tab))
            #expect(model(Sources()).restoredTab == .live)
        }
    }

    @Test(
        "session-restore-and-recently-watched/reopen-on-the-same-tab-and-group a group still loading is selected when it arrives"
    )
    func lateGroup() async {
        store.write(LiveSession(group: .named(cabin.id, "Films")))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a", group: "News")]]
        let live = model(sources)
        live.sourcesChanged([home, cabin])
        await live.settled()
        #expect(live.group == .all, "the missing group shows All channels")

        sources.playlists[cabin.id] = [channel("film", group: "Films")]
        live.retry()
        await live.settled()
        #expect(live.group == .named(cabin.id, "Films"), "the group arrived and is selected")
    }

    @Test("session-restore-and-recently-watched/reopen-on-the-same-tab-and-group a group the user picked meanwhile stays")
    func pickedMeanwhile() async {
        store.write(LiveSession(group: .named(cabin.id, "Films")))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a", group: "News")]]
        let live = model(sources)
        live.sourcesChanged([home, cabin])
        await live.settled()
        live.show(.named(home.id, "News"))
        sources.playlists[cabin.id] = [channel("film", group: "Films")]
        live.retry()
        await live.settled()
        #expect(live.group == .named(home.id, "News"))
        #expect(store.session.group?.group == .named(home.id, "News"))
    }

    @Test("session-restore-and-recently-watched/reopen-on-the-same-tab-and-group a group the app falls back to is not stored")
    func fallbackNotStored() {
        let live = model(Sources())
        live.show(.named(home.id, "News"))
        live.show(.all, picked: false)
        #expect(store.session.group?.group == .named(home.id, "News"))
    }

    // MARK: session-restore-and-recently-watched/the-last-channel-plays-again

    @Test("session-restore-and-recently-watched/the-last-channel-plays-again the channel plays once Live shows and its source loads")
    func replays() async {
        store.write(LastChannelKey(sourceID: cabin.id, channelID: "film"))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a")], cabin.id: [channel("film")]]
        let engine = PlayerTestEngine()
        let live = model(sources, engine: engine)
        live.sourcesChanged([home, cabin])
        await live.settled()
        #expect(live.playing == nil, "nothing plays before Live shows")
        live.appeared()
        #expect(live.playing?.id == "film")
    }

    @Test("session-restore-and-recently-watched/the-last-channel-plays-again offline at launch, the channel plays after a retry")
    func offline() async {
        store.write(LastChannelKey(sourceID: cabin.id, channelID: "film"))
        let sources = Sources()
        let live = model(sources)
        live.appeared()
        live.sourcesChanged([home, cabin])
        await live.settled()
        #expect(live.playing == nil)
        sources.playlists = [home.id: [channel("a")], cabin.id: [channel("film")]]
        live.retry()
        await live.settled()
        #expect(live.playing?.id == "film")
    }

    @Test("session-restore-and-recently-watched/the-last-channel-plays-again a channel the user picked first wins")
    func userPickedFirst() async {
        store.write(LastChannelKey(sourceID: cabin.id, channelID: "film"))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a")]]
        let live = model(sources)
        live.appeared()
        live.sourcesChanged([home, cabin])
        await live.settled()
        let picked = live.channels[0]
        live.pick(picked)
        sources.playlists[cabin.id] = [channel("film")]
        live.retry()
        await live.settled()
        #expect(live.playing == picked)
    }

    @Test("session-restore-and-recently-watched/the-last-channel-plays-again a channel that is gone plays nothing")
    func gone() async {
        store.write(LastChannelKey(sourceID: cabin.id, channelID: "gone"))
        let sources = Sources()
        sources.playlists = [home.id: [channel("a")], cabin.id: [channel("film")]]
        let live = model(sources)
        live.appeared()
        live.sourcesChanged([home, cabin])
        await live.settled()
        #expect(live.playing == nil)
    }
}
