import AntennaCore
import Foundation
import Testing

/// Narrowing a group by name or number, with Search's matching rules.
@Suite struct ChannelFilterTests {
    let source = UUID()

    private func catalogue(_ entries: [(name: String, number: Int)]) -> Catalogue<Int> {
        let channels = entries.map { entry in
            Channel(id: entry.name, name: entry.name, streamURL: URL(filePath: "/\(entry.number)"), group: "Sport", number: entry.number)
        }
        return Catalogue(channels: Channel.tagged(channels, sourceID: source), groupOrder: [:], favorites: [])
    }

    private func names(_ catalogue: Catalogue<Int>, _ group: CatalogueGroup, _ query: String) -> [String] {
        catalogue.rows(in: group, matching: ChannelFilter(query)).compactMap { catalogue.channel(for: $0)?.name }
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list case and accents are ignored and every word must match")
    func words() {
        let sport = catalogue([("Sport One", 104), ("Équipe Sport", 105), ("Arena HD", 106), ("Sport Two HD", 107)])
        #expect(names(sport, .all, "sport") == ["Sport One", "Équipe Sport", "Sport Two HD"])
        #expect(names(sport, .all, "EQUIPE") == ["Équipe Sport"])
        #expect(names(sport, .all, "  hd   sport ") == ["Sport Two HD"], "every word, in any order, spaces collapsed")
        #expect(names(sport, .all, "port tw") == ["Sport Two HD"], "words match inside the name")
        #expect(names(sport, .all, "news").isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list digits match the start of the number or the name as text")
    func digits() {
        let sport = catalogue([("Sport One", 104), ("Sport Two", 105), ("Channel 4", 214), ("Arena", 1040)])
        #expect(names(sport, .all, "10") == ["Sport One", "Sport Two", "Arena"])
        #expect(names(sport, .all, "0104") == ["Sport One", "Arena"], "leading zeros ignored")
        #expect(names(sport, .all, "4") == ["Channel 4"], "a number that does not start with 4, a name that holds it")
        #expect(names(sport, .all, "000").isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list a cleared filter brings back the whole group")
    func cleared() {
        let sport = catalogue([("Sport One", 104), ("Sport Two", 105)])
        #expect(names(sport, .all, "") == ["Sport One", "Sport Two"])
        #expect(names(sport, .all, "   ") == ["Sport One", "Sport Two"])
        #expect(ChannelFilter(" ").isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list only the open group is narrowed, in its order")
    func openGroupOnly() {
        let channels =
            Channel.tagged(
                [
                    Channel(id: "a", name: "News One", streamURL: URL(filePath: "/a"), group: "News", number: 2),
                    Channel(id: "b", name: "Sport News", streamURL: URL(filePath: "/b"), group: "Sport", number: 1),
                ], sourceID: source)
        let both = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: [])
        #expect(names(both, .named(source, "News"), "news") == ["News One"])
        #expect(names(both, .all, "news") == ["Sport News", "News One"])
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list a query is cut at 100 characters")
    func long() {
        #expect(ChannelFilter(String(repeating: "a", count: 150)).tokens == [String(repeating: "a", count: 100)])
    }
}
