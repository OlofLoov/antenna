import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Where the channel overlay opens and how it follows a changing catalogue.
@MainActor
@Suite struct ChannelOverlayModelTests {
    let home = UUID()
    let cabin = UUID()
    let model = ChannelOverlayModel()

    private func channel(_ id: String, group: String?) -> Channel {
        Channel(id: id, name: "Channel \(id)", streamURL: URL(fileURLWithPath: "/\(id).ts"), group: group)
    }

    /// Home has Sport (s1, s2) and News (n1); Cabin has Sport (c1).
    private func catalogue(dropping: Set<String> = [], favorites: [String] = []) -> Catalogue<Int> {
        let homeChannels = [channel("s1", group: "Sport"), channel("s2", group: "Sport"), channel("n1", group: "News")]
            .filter { !dropping.contains($0.id) }
        let channels = Channel.tagged(homeChannels, sourceID: home) + Channel.tagged([channel("c1", group: "Sport")], sourceID: cabin)
        let snapshots = favorites.enumerated().map { FavoriteSnapshot<Int>(channelID: $1, sourceID: nil, sortOrder: $0) }
        return Catalogue(channels: channels, groupOrder: [:], favorites: snapshots)
    }

    private func tagged(_ id: String, in catalogue: Catalogue<Int>) throws -> Channel {
        let key = try #require(catalogue.rows(in: .all).first { $0.id == id })
        return try #require(catalogue.channel(for: key))
    }

    @Test("tv-channel-overlay/it-opens-where-the-user-left-off the playing channel is in the last group")
    func opensOnThePlayingChannel() throws {
        let all = catalogue()
        let playing = try tagged("s2", in: all)
        model.tuned(from: .named(home, "Sport"))
        #expect(model.open(all, playing: playing) == .channel(try #require(RowKey(playing))))
        #expect(model.group == .named(home, "Sport"))
    }

    @Test("tv-channel-overlay/it-opens-where-the-user-left-off the playing channel is not in the last group")
    func opensOnTheFirstChannel() throws {
        let all = catalogue()
        model.tuned(from: .named(home, "News"))
        let target = model.open(all, playing: try tagged("s1", in: all))
        #expect(model.group == .named(home, "News"))
        #expect(target == .channel(try #require(RowKey(try tagged("n1", in: all)))))
    }

    @Test("tv-channel-overlay/it-opens-where-the-user-left-off a cold launch opens the playing channel's own group")
    func coldLaunch() throws {
        let all = catalogue()
        let playing = try tagged("c1", in: all)
        #expect(model.open(all, playing: playing) == .channel(try #require(RowKey(playing))))
        #expect(model.group == .named(cabin, "Sport"), "the same group name in another source is a different group")
    }

    @Test("tv-channel-overlay/it-opens-where-the-user-left-off the playing channel is gone")
    func playingIsGone() throws {
        let before = catalogue()
        let playing = try tagged("s2", in: before)
        model.tuned(from: .named(home, "Sport"))
        let after = catalogue(dropping: ["s2"])
        let target = model.open(after, playing: playing)
        #expect(model.group == .all)
        #expect(target == .channel(try #require(after.rows(in: .all).first)))
    }

    @Test("tv-channel-overlay/it-opens-where-the-user-left-off no channels at all puts focus on All channels")
    func noChannels() {
        let empty = Catalogue<Int>(channels: [], groupOrder: [:], favorites: [])
        #expect(model.open(empty, playing: nil) == .group(.all))
    }

    @Test("tv-channel-overlay/every-group-with-its-size groups in order, each counted, the same name twice")
    func groupsAndCounts() {
        let all = catalogue(favorites: ["n1"])
        #expect(all.groups == [.favorites, .all, .named(home, "Sport"), .named(home, "News"), .named(cabin, "Sport")])
        #expect(all.groups.map(all.count(of:)) == [1, 4, 2, 1, 1])
        #expect(all.groups.map(\.label) == ["Favorites", "All channels", "Sport", "News", "Sport"])
        #expect(CatalogueGroup.favorites.order == "Your order")
        #expect(CatalogueGroup.named(home, "Sport").order == "Sorted by number")
    }

    @Test("tv-channel-overlay/every-group-with-its-size changes while open keep the highlight or fall back")
    func changesWhileOpen() throws {
        let before = catalogue()
        let s2 = try #require(RowKey(try tagged("s2", in: before)))
        _ = model.open(before, playing: try tagged("s2", in: before))
        #expect(
            model.catalogueChanged(catalogue(favorites: ["n1"]), focused: .channel(s2)) == .channel(s2),
            "the same channel stays highlighted")
        let without = catalogue(dropping: ["s2"])
        let first = try #require(without.rows(in: .named(home, "Sport")).first)
        #expect(model.catalogueChanged(without, focused: .channel(s2)) == .channel(first), "else the group's first channel")
        let noSport = catalogue(dropping: ["s1", "s2"])
        let moved = model.catalogueChanged(noSport, focused: .channel(s2))
        #expect(model.group == .all, "a group that is gone shows All channels")
        #expect(moved == .channel(try #require(noSport.rows(in: .all).first)))
    }

    @Test("tv-channel-overlay/picking-a-group-shows-its-channels moving to a group and entering its channels")
    func entry() throws {
        let all = catalogue()
        let playing = try tagged("s2", in: all)
        model.show(.named(home, "Sport"))
        #expect(model.entry(all, playing: playing) == RowKey(playing))
        model.show(.named(home, "News"))
        #expect(model.entry(all, playing: playing) == RowKey(try tagged("n1", in: all)))
        model.show(.favorites)
        #expect(model.entry(all, playing: playing) == nil, "an empty group leaves focus where it is")
    }

    @Test("tv-channel-overlay/empty-groups-tell-the-user-what-to-do the empty Favorites and All channels lines")
    func emptyText() {
        let all = catalogue()
        model.show(.favorites)
        #expect(model.emptyText(all) == "No favorites yet. Press the star on a channel to add it.")
        model.show(.all)
        #expect(model.emptyText(all) == nil)
        let empty = Catalogue<Int>(channels: [], groupOrder: [:], favorites: [])
        _ = model.open(empty, playing: nil)
        #expect(model.group == .all)
        #expect(model.emptyText(empty) == "No channels yet. Add a source in Settings.")
        #expect(model.group.label == "All channels")
        #expect(model.group.order == "Sorted by number")
    }

    @Test("tv-channel-overlay/now-and-next-for-the-highlighted-channel the panel follows the highlighted row of the shown group")
    func panelRow() throws {
        let all = catalogue()
        let playing = try tagged("s1", in: all)
        _ = model.open(all, playing: playing)
        #expect(model.panelRow(all) == RowKey(playing))
        let s2 = try #require(RowKey(try tagged("s2", in: all)))
        model.highlight(s2)
        #expect(model.panelRow(all) == s2)
        model.show(.favorites)
        #expect(model.panelRow(all) == nil, "an empty group leaves the panel empty")
    }
}
