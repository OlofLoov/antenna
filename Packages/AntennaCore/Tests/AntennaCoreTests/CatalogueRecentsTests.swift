import Foundation
import Testing

@testable import AntennaCore

@Suite struct CatalogueRecentsTests {
    private let channels =
        Channel.tagged(
            [channel("a1", group: "Sport", number: 1), channel("a2", group: "News", number: 2), channel("a3")], sourceID: sourceA)
        + Channel.tagged(
            [channel("b1", group: "Kids", number: 3), channel("dup", number: 4), channel("dup", number: 5)], sourceID: sourceB)

    private func key(_ id: String, _ source: UUID) -> LastChannelKey {
        LastChannelKey(sourceID: source, channelID: id)
    }

    @Test("channel-catalogue/group-list-and-order Recents sits between Favorites and All channels")
    func order() throws {
        let catalogue = TestCatalogue(
            channels: channels, groupOrder: [:], favorites: [], recents: [key("b1", sourceB), key("a2", sourceA)])
        #expect(Array(catalogue.groups.prefix(3)) == [.favorites, .recents, .all])
        let without = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(Array(catalogue.groups.dropFirst(3)) == Array(without.groups.dropFirst(2)))
        let rows = catalogue.rows(in: .recents)
        #expect(rows.map(\.id) == ["b1", "a2"])
        #expect(catalogue.count(of: .recents) == 2)
        let b1 = try #require(rows.first)
        #expect(catalogue.position(of: b1, in: .recents)! == (1, 2))
    }

    @Test("channel-catalogue/group-list-and-order Recents is absent when no recent channel resolves")
    func absent() {
        let none = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
        #expect(!none.groups.contains(.recents))
        let unresolved = TestCatalogue(channels: channels, groupOrder: [:], favorites: [], recents: [key("gone", sourceA)])
        #expect(!unresolved.groups.contains(.recents))
        #expect(unresolved.rows(in: .recents).isEmpty)
    }

    @Test("channel-catalogue/recents-replaced-without-rebuild an id matching two channels does not resolve")
    func ambiguous() {
        let catalogue = TestCatalogue(channels: channels, groupOrder: [:], favorites: [])
            .replacingRecents([key("dup", sourceB), key("a1", sourceA), key("a1", sourceB)])
        #expect(catalogue.rows(in: .recents).map(\.id) == ["a1"])
    }

    @Test("channel-catalogue/recents-replaced-without-rebuild replacing recents keeps every other group, row and number")
    func replace() {
        let input = CatalogueFavoritesTests.ac14Input()
        let original = TestCatalogue(
            channels: input.channels, groupOrder: input.groupOrder, favorites: input.favorites, recents: [key("a10", sourceA)])
        let changed = [key("b7", sourceB), key("a10", sourceA), key("missing", sourceA)]
        let replaced = original.replacingRecents(changed)
        #expect(replaced.groups == original.groups)
        for group in original.groups where group != .recents {
            #expect(replaced.rows(in: group) == original.rows(in: group))
        }
        for key in original.rows(in: .all) where replaced.number(for: key) != original.number(for: key) {
            Issue.record("number changed")
        }
        #expect(replaced.rows(in: .recents).map(\.id) == ["b7", "a10"])
        #expect(replaced.replacingFavorites([]).rows(in: .recents) == replaced.rows(in: .recents), "favorites keep the recents")
        #expect(original.replacingRecents([]).groups.contains(.recents) == false)
    }

    /// Benchmark, not CI-gated. Run with `ANTENNA_BENCHMARKS=1 swift test`.
    @Test(
        "channel-catalogue/recents-replaced-without-rebuild replacing recents takes under 20 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"),
        .timeLimit(.minutes(1)))
    func replaceBenchmark() {
        let input = CatalogueFavoritesTests.ac14Input()
        let original = TestCatalogue(channels: input.channels, groupOrder: input.groupOrder, favorites: input.favorites)
        let recents = (0..<20).map { key("a\($0 * 1_000)", sourceA) }
        var replaced: TestCatalogue?
        let elapsed = ContinuousClock().measure { replaced = original.replacingRecents(recents) }
        #expect(replaced?.count(of: .recents) == 20)
        #expect(elapsed < .milliseconds(20))
    }
}
