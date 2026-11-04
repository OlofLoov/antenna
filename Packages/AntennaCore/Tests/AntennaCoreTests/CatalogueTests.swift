import Foundation
import Testing

@testable import AntennaCore

let sourceA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
let sourceB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()

/// An untagged channel for catalogue fixtures.
func channel(_ id: String, group: String? = nil, number: Int? = nil, name: String = "Channel") -> Channel {
    Channel(id: id, name: name, streamURL: URL(fileURLWithPath: "/\(id)"), group: group, number: number)
}

typealias TestCatalogue = Catalogue<Int>
typealias Snapshot = FavoriteSnapshot<Int>

@Suite struct CatalogueTests {
    @Test("0013/AC-1 tagging sets sourceID and 0-based position only")
    func tagging() throws {
        let other = UUID()
        var pretagged = channel("c", group: "News", number: 9)
        pretagged.sourceID = other
        pretagged.position = 7
        let input = [channel("a", group: "Sport", number: 104, name: "A"), channel("b"), pretagged]
        let tagged = Channel.tagged(input, sourceID: sourceA)
        #expect(tagged.map(\.sourceID) == [sourceA, sourceA, sourceA])
        #expect(tagged.map(\.position) == [0, 1, 2])
        let untagged = tagged.map { tagged in
            var copy = tagged
            copy.sourceID = nil
            copy.position = nil
            return copy
        }
        var expected = input
        expected[2].sourceID = nil
        expected[2].position = nil
        #expect(untagged == expected)
    }

    /// Source A: Sport, News, Ungrouped. Source B: Kids, Docs, Sport, Ungrouped ("  ").
    static func ac2Channels(_ counts: [Int] = [1, 1, 2, 1, 1, 1, 1]) -> [Channel] {
        func make(_ prefix: String, _ group: String?, _ count: Int) -> [Channel] {
            (0..<count).map { channel("\(prefix)\($0)", group: group) }
        }
        let inA = make("as", "Sport", counts[0]) + make("an", "News", counts[1]) + make("au", nil, counts[2])
        let inB =
            make("bk", "Kids", counts[4]) + make("bd", "Docs", counts[5]) + make("bs", "Sport", counts[3]) + make("bu", "  ", counts[6])
        return Channel.tagged(inA, sourceID: sourceA) + Channel.tagged(inB, sourceID: sourceB)
    }

    static let ac2GroupOrder = [sourceB: ["Sport", " ", "Kids", "Sport", "Radio"]]

    @Test("0013/AC-2 group list and order")
    func groupOrder() {
        let catalogue = TestCatalogue(channels: Self.ac2Channels(), groupOrder: Self.ac2GroupOrder, favorites: [])
        #expect(
            catalogue.groups == [
                .favorites, .all,
                .named(sourceA, "Sport"), .named(sourceA, "News"), .ungrouped(sourceA),
                .named(sourceB, "Sport"), .named(sourceB, "Kids"), .named(sourceB, "Docs"), .ungrouped(sourceB),
            ])
        let noUngrouped = TestCatalogue(
            channels: Channel.tagged([channel("x", group: "Sport")], sourceID: sourceA), groupOrder: [:], favorites: [])
        #expect(noUngrouped.groups == [.favorites, .all, .named(sourceA, "Sport")])
    }

    @Test("0013/AC-3 group counts match rows")
    func groupCounts() {
        let channels = Self.ac2Channels([3, 4, 2, 5, 6, 1, 1])
        let favorites = [
            Snapshot(channelID: "as0", sourceID: sourceA, sortOrder: 0), Snapshot(channelID: "bk1", sourceID: nil, sortOrder: 1),
        ]
        let catalogue = TestCatalogue(channels: channels, groupOrder: Self.ac2GroupOrder, favorites: favorites)
        let expected: [CatalogueGroup: Int] = [
            .favorites: 2, .all: 22,
            .named(sourceA, "Sport"): 3, .named(sourceA, "News"): 4, .ungrouped(sourceA): 2,
            .named(sourceB, "Sport"): 5, .named(sourceB, "Kids"): 6, .named(sourceB, "Docs"): 1, .ungrouped(sourceB): 1,
        ]
        for group in catalogue.groups {
            #expect(catalogue.count(of: group) == expected[group])
            #expect(catalogue.count(of: group) == catalogue.rows(in: group).count)
        }
    }

    @Test("0013/AC-4 provider numbers pass through")
    func providerNumbers() throws {
        let channels = Channel.tagged([channel("a", number: 104), channel("b", number: 7)], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(try channels.map { catalogue.number(for: try #require(RowKey($0))) } == [104, 7])
    }

    @Test("0013/AC-5a unnumbered channels count on from the highest provider number")
    func numberFallback() throws {
        let inA = Channel.tagged(
            [channel("a0"), channel("a1", number: 300), channel("a2", number: 0), channel("a3", number: 12)], sourceID: sourceA)
        let inB = Channel.tagged([channel("b0", number: -3), channel("b1", number: 100_000), channel("b2")], sourceID: sourceB)
        let build = { TestCatalogue(channels: inA + inB, groupOrder: [:], favorites: []) }
        let first = build()
        let numbers = try (inA + inB).map { first.number(for: try #require(RowKey($0))) }
        #expect(numbers == [301, 300, 302, 12, 303, 304, 305])
        let second = build()
        #expect(try (inA + inB).map { second.number(for: try #require(RowKey($0))) } == numbers)
    }

    @Test("0013/AC-5b with no provider numbers in range, fallback starts at 1")
    func numberFallbackBase() throws {
        let inA = Channel.tagged([channel("a0"), channel("a1", number: 0)], sourceID: sourceA)
        let inB = Channel.tagged([channel("b0", number: 100_000), channel("b1")], sourceID: sourceB)
        let catalogue = TestCatalogue(channels: inA + inB, groupOrder: [:], favorites: [])
        #expect(try (inA + inB).map { catalogue.number(for: try #require(RowKey($0))) } == [1, 2, 3, 4])
    }

    /// Positions 0, 2 and 9 in source A, numbered 3, 5 and 5, all in Sport.
    static func ac6Channels() -> [Channel] {
        var list = (0..<10).map { channel("f\($0)", group: "Filler", number: 50 + $0) }
        list[0] = channel("three", group: "Sport", number: 3)
        list[9] = channel("five-9", group: "Sport", number: 5)
        list[2] = channel("five-2", group: "Sport", number: 5)
        return Channel.tagged(list, sourceID: sourceA)
    }

    @Test("0013/AC-6a group rows sort by number then position")
    func sortInGroup() {
        let catalogue = TestCatalogue(channels: Self.ac6Channels(), groupOrder: [:], favorites: [])
        #expect(catalogue.rows(in: .named(sourceA, "Sport")).map(\.id) == ["three", "five-2", "five-9"])
    }

    @Test("0013/AC-6a a lower number sorts ahead of an earlier position")
    func sortInGroupByNumber() {
        let channels = Channel.tagged(
            [channel("nine", group: "Sport", number: 9), channel("two", group: "Sport", number: 2), channel("one")],
            sourceID: sourceA)
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(catalogue.rows(in: .named(sourceA, "Sport")).map(\.id) == ["two", "nine"])
    }

    @Test("0013/AC-6b All channels sorts by number, source, then position")
    func allOrder() {
        let inB = Channel.tagged([channel("b-five", group: "Other", number: 5)], sourceID: sourceB)
        let catalogue = TestCatalogue(channels: Self.ac6Channels() + inB, groupOrder: [:], favorites: [])
        #expect(catalogue.rows(in: .all).prefix(4).map(\.id) == ["three", "five-2", "five-9", "b-five"])
    }

    @Test(
        "0013/AC-7 initials",
        arguments: [
            ("Sport One", "SO"), ("Eurosport 1", "E1"), ("BBC - One", "BO"), ("Arena HD", "AH"),
            ("a b c d e", "ABCD"), ("news24", "NEWS"), ("24/7", "247"), ("** HD **", "HD"),
            ("", "?"), ("- * -", "?"),
        ])
    func initials(name: String, expected: String) {
        #expect(Channel.initials(for: name) == expected)
    }

    @Test("0013/AC-11a equal ids get distinct keys and are all listed")
    func equalIDs() throws {
        let inA = Channel.tagged([channel("same"), channel("same")], sourceID: sourceA)
        let inB = Channel.tagged([channel("same")], sourceID: sourceB)
        let catalogue = TestCatalogue(channels: inA + inB, groupOrder: [:], favorites: [])
        let keys = try (inA + inB).map { try #require(RowKey($0)) }
        #expect(Set(keys).count == 3)
        #expect(Set(catalogue.rows(in: .all)) == Set(keys))
    }

    @Test("0013/AC-11b two builds from one input are identical")
    func deterministic() {
        let favorites = [
            Snapshot(channelID: "as0", sourceID: nil, sortOrder: 0), Snapshot(channelID: "bs0", sourceID: sourceB, sortOrder: 0),
        ]
        let build = { TestCatalogue(channels: Self.ac2Channels(), groupOrder: Self.ac2GroupOrder, favorites: favorites) }
        let first = build()
        let second = build()
        #expect(first.groups == second.groups)
        for group in first.groups {
            #expect(first.rows(in: group) == second.rows(in: group))
        }
    }

    @Test("0013/AC-12 digit prefix match")
    func digitMatch() throws {
        let inA = Channel.tagged([1, 10, 104, 1040].map { (number: Int) in channel("a\(number)", number: number) }, sourceID: sourceA)
        let inB = Channel.tagged([channel("b104", number: 104)], sourceID: sourceB)
        let catalogue = TestCatalogue(channels: inA + inB, groupOrder: [:], favorites: [])
        let keys = try inA.map { try #require(RowKey($0)) }
        #expect(catalogue.match(digits: "1") == keys[0])
        #expect(catalogue.match(digits: "10") == keys[1])
        #expect(catalogue.match(digits: "104") == keys[2])
        #expect(catalogue.match(digits: "0104") == keys[2])
        #expect(catalogue.match(digits: "0") == nil)
        #expect(catalogue.match(digits: "") == nil)
        #expect(catalogue.match(digits: "1a") == nil)
        #expect(catalogue.match(digits: "١") == nil)
        #expect(catalogue.match(digits: "2") == nil)
        #expect(catalogue.match(digits: "10400") == nil)
    }

    @Test("0013/AC-12 a prefix with no exact number matches the lowest longer number")
    func digitMatchLonger() throws {
        let inA = Channel.tagged(
            [channel("x", group: "G", number: 1041), channel("y", group: "H", number: 1040), channel("z", number: 20)], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: inA, groupOrder: [:], favorites: [])
        #expect(catalogue.match(digits: "104") == RowKey(inA[1]))
    }

    @Test("0013/AC-13 1-based position in group")
    func positionInGroup() throws {
        let sport = (1...42).map { (number: Int) in channel("s\(number)", group: "Sport", number: number) }
        let channels = Channel.tagged(sport + [channel("n", group: "News", number: 100)], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        let group = CatalogueGroup.named(sourceA, "Sport")
        let fourth = catalogue.rows(in: group)[3]
        #expect(catalogue.position(of: fourth, in: group).map { [$0.0, $0.1] } == [4, 42])
        #expect(catalogue.position(of: fourth, in: .all).map { [$0.0, $0.1] } == [4, 43])
        #expect(catalogue.position(of: try #require(RowKey(channels[42])), in: group) == nil)
        #expect(catalogue.position(of: fourth, in: .favorites) == nil)
    }

    @Test("0013/AC-15 row-key lookup falls back to a unique source and id")
    func rowKeyLookup() throws {
        let original = Channel.tagged([channel("x", name: "X"), channel("dup"), channel("dup")], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: original, groupOrder: [:], favorites: [])
        let key = try #require(RowKey(original[0]))
        #expect(catalogue.channel(for: key) == original[0])

        let moved = Channel.tagged([channel("new"), channel("x", name: "X")], sourceID: sourceA)
        let reloaded = TestCatalogue(channels: moved, groupOrder: [:], favorites: [])
        #expect(reloaded.channel(for: key) == moved[1])

        var stale = original[1]
        stale.position = 9
        #expect(catalogue.channel(for: try #require(RowKey(stale))) == nil)
        var otherSource = original[0]
        otherSource.sourceID = sourceB
        #expect(catalogue.channel(for: try #require(RowKey(otherSource))) == nil)
    }

    @Test("0013/AC-16 source group of a channel")
    func sourceGroup() {
        let channels = Channel.tagged([channel("u"), channel("s", group: "Sport")], sourceID: sourceA)
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(channels.map { catalogue.sourceGroup(of: $0) } == [.ungrouped(sourceA), .named(sourceA, "Sport")])
    }

    @Test("0013/AC-17 empty catalogue")
    func emptyCatalogue() {
        let favorites = [Snapshot(channelID: "b", sourceID: nil, sortOrder: 1), Snapshot(channelID: "a", sourceID: sourceA, sortOrder: 0)]
        let catalogue = TestCatalogue(channels: [], groupOrder: [:], favorites: favorites)
        #expect(catalogue.groups == [.favorites, .all])
        #expect(catalogue.count(of: .favorites) == 0)
        #expect(catalogue.count(of: .all) == 0)
        #expect(catalogue.match(digits: "1") == nil)
        let key = RowKey(Channel.tagged([channel("a")], sourceID: sourceA)[0])
        #expect(key.flatMap { catalogue.position(of: $0, in: .all) } == nil)
        #expect(key.flatMap { catalogue.channel(for: $0) } == nil)
        #expect(catalogue.unresolvedFavorites == [favorites[1], favorites[0]])
    }

    @Test("0013/AC-18 untagged channels are dropped")
    func untaggedDropped() {
        let untagged = channel("loose", group: "Sport", number: 1)
        let channels = Channel.tagged([channel("a", group: "Sport"), channel("b")], sourceID: sourceA) + [untagged]
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(catalogue.count(of: .all) == 2)
        for group in catalogue.groups {
            #expect(!catalogue.rows(in: group).contains { $0.id == "loose" })
        }
        #expect(RowKey(untagged) == nil)
        #expect(catalogue.sourceGroup(of: untagged) == nil)
    }

    @Test("0013/AC-20 unknown group is empty")
    func unknownGroup() {
        let catalogue = TestCatalogue(channels: Self.ac2Channels(), groupOrder: [:], favorites: [])
        for group in [CatalogueGroup.named(UUID(), "X"), .ungrouped(UUID()), .named(sourceA, "Nope")] {
            #expect(catalogue.count(of: group) == 0)
            #expect(catalogue.rows(in: group).isEmpty)
        }
    }
}
