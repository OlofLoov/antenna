import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// Group rules on Live with scripted sources: locked groups, the playing
/// channel getting locked, and the group falling back.
@MainActor
@Suite struct LiveGroupLocksTests {
    let defaults: UserDefaults
    let home = SourceDescriptor(name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "live-group-locks-\(UUID().uuidString)"))
    }

    private func channel(_ id: String, group: String) -> Channel {
        Channel(id: id, name: id, streamURL: URL(fileURLWithPath: "/\(id).ts"), group: group)
    }

    private func model() async -> LiveModel {
        let channels = [channel("news", group: "News"), channel("film", group: "Movies")]
        let live = LiveModel(
            .init(
                engine: PlayerTestEngine(), load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true },
                programmes: UITestingLive.guide, recents: RecentsStore(defaults: defaults)))
        live.sourcesChanged([home])
        await live.settled()
        return live
    }

    @Test(
        "group-management/a-channel-that-gets-locked-stops-playing a locked playing channel is caught; leaving plays an open one"
    )
    func lockedWhilePlaying() async throws {
        let live = await model()
        let movies = CatalogueGroup.named(home.id, "Movies")
        let film = try #require(live.channels.first { $0.id == "film" })
        live.show(movies)
        live.tune(film)
        #expect(!live.playingIsLocked)

        live.rulesChanged(GroupRules(locked: [movies]))
        #expect(live.playingIsLocked)
        #expect(live.group == .all, "the current group falls back to one the user may open")

        live.leaveLockedChannel()
        #expect(live.playing?.id == "news")
        #expect(!live.playingIsLocked)
    }

    @Test("group-management/a-channel-that-gets-locked-stops-playing with every channel locked, leaving stops the player")
    func nothingLeft() async throws {
        let live = await model()
        live.tune(try #require(live.channels.first))
        live.rulesChanged(GroupRules(locked: [.named(home.id, "Movies"), .named(home.id, "News")]))
        live.leaveLockedChannel()
        #expect(live.playing == nil)
    }

    @Test("group-management/unlock-with-the-passcode an unlocked group shows once the locks open")
    func unlockedGroupShows() async {
        let live = await model()
        let movies = CatalogueGroup.named(home.id, "Movies")
        live.rulesChanged(GroupRules(locked: [movies]))
        #expect(live.catalogue.lockedGroups == [movies])
        live.unlocked(movies)
        #expect(live.group == .all)
        live.rulesChanged(GroupRules(locked: [movies], locksOpen: true))
        #expect(live.group == movies)
    }
}
