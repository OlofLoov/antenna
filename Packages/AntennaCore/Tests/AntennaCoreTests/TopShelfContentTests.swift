import Foundation
import Testing

@testable import AntennaCore

@Suite struct TopShelfContentTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func channel(_ id: String, _ name: String, source: UUID? = sourceA) -> Channel {
        Channel(
            id: id, name: name, streamURL: URL(fileURLWithPath: "/\(id)"), logoURL: URL(string: "http://user:pass@logos/\(id).png"),
            epgID: id, sourceID: source)
    }

    private func programme(_ channel: String, _ title: String, from start: TimeInterval, to stop: TimeInterval) -> Programme {
        Programme(channelID: channel, start: now.addingTimeInterval(start), stop: now.addingTimeInterval(stop), title: title)
    }

    private func item(_ name: String, kind: ShelfTitle.Kind = .movie, position: Double, at minutesAgo: Double) -> ContinueWatching.Item {
        let title = ShelfTitle(id: "xtream#h#\(kind == .movie ? "vod" : "series")#\(name)", kind: kind, sourceID: sourceA, name: name)
        let progress = WatchProgress(
            id: name, titleID: title.id, sourceID: sourceA, position: position, duration: 100,
            updatedAt: now.addingTimeInterval(-minutesAgo * 60))
        return ContinueWatching.Item(title: title, progress: progress, isNextEpisode: false)
    }

    private func content(_ snapshot: TopShelfSnapshot, at date: Date? = nil) -> TopShelfContent? {
        TopShelfContent.make(from: TopShelfSnapshot(data: try? snapshot.encoded()), now: date ?? now)
    }

    private func sections(_ content: TopShelfContent?) -> [TopShelfContent.Section] {
        guard case .sections(let sections) = content else { return [] }
        return sections
    }

    @Test("top-shelf/favorites-show-what-is-on-now favorites in order titled with the channel and the programme on now")
    func favoritesOnNow() throws {
        let snapshot = TopShelfSnapshot(
            favorites: [
                .init(channel: channel("b", "BBC One"), programmes: [programme("b", "News", from: -900, to: 2700)]),
                .init(channel: channel("a", "Arte"), programmes: [programme("a", "Opera", from: -1800, to: 1800)]),
            ], titles: [], unresolvedFavorites: 0, now: now)
        let rows = sections(content(snapshot))
        #expect(rows.map(\.id) == ["topShelf.section.favorites"])
        let tiles = try #require(rows.first).items
        #expect(tiles.map(\.title) == ["BBC One · News", "Arte · Opera"])
        #expect(tiles.map(\.progress) == [0.25, 0.5])
        #expect(tiles.first?.id == "topShelf.item.\(try #require(TopShelfItemID.channel(channel("b", "BBC One"))).uuidString.lowercased())")
    }

    @Test("top-shelf/favorites-show-what-is-on-now offline the titles advance through the 12 hours and then stop")
    func offline() throws {
        let snapshot = TopShelfSnapshot(
            favorites: [
                .init(
                    channel: channel("a", "Arte"),
                    programmes: [
                        programme("a", "Old", from: -7200, to: -3600), programme("a", "Now", from: -3600, to: 3600),
                        programme("a", "Later", from: 3600, to: 13 * 3600), programme("a", "Too late", from: 13 * 3600, to: 14 * 3600),
                    ])
            ], titles: [], unresolvedFavorites: 0, now: now)
        #expect(snapshot.favorites[0].programmes.map(\.title) == ["Now", "Later"])
        let later = sections(content(snapshot, at: now.addingTimeInterval(7200)))
        #expect(later.first?.items.first?.title == "Arte · Later")
        let past = sections(content(snapshot, at: now.addingTimeInterval(14 * 3600)))
        #expect(past.first?.items.first?.title == "Arte")
        #expect(past.first?.items.first?.progress == nil)
    }

    @Test("top-shelf/favorites-show-what-is-on-now at most 20 favorites, and channels without a source are left off")
    func manyFavorites() {
        let favorites = (0..<25).map { TopShelfSnapshot.FavoriteInput(channel: channel("c\($0)", "C\($0)"), programmes: []) }
        let unsourced = TopShelfSnapshot.FavoriteInput(channel: channel("x", "X", source: nil), programmes: [])
        let snapshot = TopShelfSnapshot(favorites: [unsourced] + favorites, titles: [], unresolvedFavorites: 0, now: now)
        #expect(snapshot.favorites.map(\.name) == (0..<20).map { "C\($0)" })
    }

    @Test("top-shelf/a-channel-with-no-guide-left-shows-its-name guide ending before now gives the name and no bar")
    func noGuideLeft() {
        let snapshot = TopShelfSnapshot(
            favorites: [.init(channel: channel("a", "Arte"), programmes: [programme("a", "Done", from: -3600, to: 0)])], titles: [],
            unresolvedFavorites: 0, now: now)
        let tile = sections(content(snapshot)).first?.items.first
        #expect(tile?.title == "Arte")
        #expect(tile?.progress == nil)
    }

    @Test("top-shelf/continue-watching-shows-titles-in-progress most recent first, episodes with their season and episode")
    func continueWatching() {
        let movie = item("Dune", position: 40, at: 60)
        let episode = item("Northern Lights", kind: .series, position: 25, at: 5)
        let snapshot = TopShelfSnapshot(
            favorites: [], titles: [.init(item: movie, detail: nil), .init(item: episode, detail: "S2 E4")], unresolvedFavorites: 0,
            now: now)
        let rows = sections(content(snapshot))
        #expect(rows.map(\.id) == ["topShelf.section.continueWatching"])
        #expect(rows.first?.title == "Continue watching")
        #expect(rows.first?.items.map(\.title) == ["Northern Lights · S2 E4", "Dune"])
        #expect(rows.first?.items.map(\.progress) == [0.25, 0.4])
    }

    @Test("top-shelf/continue-watching-shows-titles-in-progress the 10 most recent, finished and next episodes left out")
    func manyTitles() {
        var next = item("Next", kind: .series, position: 99, at: 0)
        next.isNextEpisode = true
        let finished = item("Finished", position: 99, at: 0)
        let titles = (0..<12).map { TopShelfSnapshot.TitleInput(item: item("T\($0)", position: 50, at: Double($0)), detail: nil) }
        let snapshot = TopShelfSnapshot(
            favorites: [], titles: [.init(item: next, detail: nil), .init(item: finished, detail: nil)] + titles.reversed(),
            unresolvedFavorites: 0, now: now)
        #expect(snapshot.titles.map(\.title) == (0..<10).map { "T\($0)" })
    }

    @Test("top-shelf/a-row-with-nothing-in-it-is-left-out one row with content shows alone, with no add-favorites tile")
    func oneRowEmpty() {
        let favoritesOnly = TopShelfSnapshot(
            favorites: [.init(channel: channel("a", "Arte"), programmes: [])], titles: [], unresolvedFavorites: 0, now: now)
        #expect(sections(content(favoritesOnly)).map(\.kind) == [.favorites])
        let titlesOnly = TopShelfSnapshot(
            favorites: [], titles: [.init(item: item("Dune", position: 40, at: 1), detail: nil)], unresolvedFavorites: 0, now: now)
        #expect(sections(content(titlesOnly)).map(\.kind) == [.continueWatching])
        let both = TopShelfSnapshot(
            favorites: [.init(channel: channel("a", "Arte"), programmes: [])],
            titles: [.init(item: item("Dune", position: 40, at: 1), detail: nil)], unresolvedFavorites: 3, now: now)
        #expect(sections(content(both)).map(\.kind) == [.favorites, .continueWatching])
    }

    @Test("top-shelf/an-empty-shelf-says-how-to-fill-it nothing to show gives one add-favorites tile that opens Antenna")
    func emptyShelf() {
        let expected = TopShelfContent.Item(
            id: "topShelf.emptyItem", title: "Add favorites in Antenna to see them here", tileFile: "empty.png", progress: nil, link: .empty
        )
        #expect(content(TopShelfSnapshot(favorites: [], titles: [], unresolvedFavorites: 0, now: now)) == .empty(expected))
        #expect(content(.cleared(now: now)) == .empty(expected), "a lapsed unlock clears the summary to the add-favorites tile")
    }

    @Test("top-shelf/an-empty-shelf-says-how-to-fill-it favorites still loading leave the shelf blank")
    func stillLoading() {
        #expect(content(TopShelfSnapshot(favorites: [], titles: [], unresolvedFavorites: 2, now: now)) == nil)
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app no snapshot, a damaged one or an older version gives a blank shelf")
    func damaged() throws {
        #expect(TopShelfContent.make(from: TopShelfSnapshot(data: nil), now: now) == nil)
        #expect(TopShelfSnapshot(data: Data("{\"version\":1".utf8)) == nil)
        #expect(TopShelfSnapshot(data: Data("[]".utf8)) == nil)
        var old = TopShelfSnapshot.cleared(now: now)
        old.version = 0
        #expect(TopShelfSnapshot(data: try old.encoded()) == nil)
        #expect(TopShelfSnapshot(data: Data(count: TopShelfSnapshot.byteLimit)) == nil)
        #expect(TopShelfSnapshot(data: try TopShelfSnapshot.cleared(now: now).encoded()) == .cleared(now: now))
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app the encoded snapshot stays under 256 KB")
    func sizeLimit() throws {
        let long = String(repeating: "x", count: 500)
        let programmes = (0..<200).map { programme("a", "\(long)\($0)", from: Double($0) * 60, to: Double($0 + 1) * 60) }
        let favorites = (0..<20).map { TopShelfSnapshot.FavoriteInput(channel: channel("c\($0)", "C\($0)"), programmes: programmes) }
        let data = try TopShelfSnapshot(favorites: favorites, titles: [], unresolvedFavorites: 0, now: now).encoded()
        #expect(data.count < TopShelfSnapshot.byteLimit)
        let read = try #require(TopShelfSnapshot(data: data))
        #expect(read.favorites.count == 20)
        #expect(read.favorites[0].programmes.first?.title == "\(long)0", "the programme on now is kept")
    }

    @Test("top-shelf/no-passwords-or-links-leave-the-app the summary holds no link, channel or title id, username or password")
    func noSecrets() throws {
        let m3u = channel("http://user:secret@host/live/user/secret/1.ts", "Sport")
        let movie = item("Dune", position: 40, at: 1)
        let snapshot = TopShelfSnapshot(
            favorites: [.init(channel: m3u, programmes: [programme(m3u.id, "Match", from: -60, to: 60)])],
            titles: [.init(item: movie, detail: nil)], unresolvedFavorites: 0, now: now)
        let text = String(decoding: try snapshot.encoded(), as: UTF8.self)
        for secret in ["://", "user", "secret", "host", "xtream#", "logos", m3u.id, movie.title.id, sourceA.uuidString] {
            #expect(!text.lowercased().contains(secret.lowercased()), "\(secret)")
        }
        #expect(text.contains("Sport") && text.contains("Match") && text.contains("Dune"))
    }
}
