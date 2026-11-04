import Foundation
import Testing

@testable import AntennaCore

@Suite struct CatalogueFavoritesTests {
    @Test("0013/AC-8 favorites resolve to loaded channels")
    func resolution() throws {
        let x = Snapshot(channelID: "x", sourceID: nil, sortOrder: 1)
        let y = Snapshot(channelID: "y", sourceID: sourceA, sortOrder: 0)
        let wSnap = Snapshot(channelID: "w", sourceID: sourceB, sortOrder: 2)
        let zSnap = Snapshot(channelID: "z", sourceID: nil, sortOrder: 3)
        let inA = Channel.tagged([channel("x"), channel("y"), channel("w")], sourceID: sourceA)
        let inB = Channel.tagged([channel("x")], sourceID: sourceB)
        let catalogue = TestCatalogue(channels: inA + inB, groupOrder: [:], favorites: [zSnap, wSnap, x, y])
        let rows = catalogue.rows(in: .favorites)
        #expect(rows == [try #require(RowKey(inA[1])), try #require(RowKey(inA[0]))])
        #expect(catalogue.count(of: .favorites) == 2)
        #expect(catalogue.unresolvedFavorites == [wSnap, zSnap])
    }

    @Test("0013/AC-8 unresolved favorites with equal sortOrder order by channelID")
    func unresolvedOrder() {
        let late = Snapshot(channelID: "b", sourceID: nil, sortOrder: 1)
        let early = Snapshot(channelID: "a", sourceID: nil, sortOrder: 1)
        let catalogue = TestCatalogue(channels: [], groupOrder: [:], favorites: [late, early])
        #expect(catalogue.unresolvedFavorites == [early, late])
    }

    /// Channel c is favorited three times in source A's terms (nil, A, and a
    /// sync-race duplicate of A) and once for source B's copy. d once.
    static let snapshots = [
        Snapshot(channelID: "c", sourceID: nil, sortOrder: 5, recordToken: 1),
        Snapshot(channelID: "c", sourceID: sourceA, sortOrder: 2, recordToken: 2),
        Snapshot(channelID: "c", sourceID: sourceA, sortOrder: 2, recordToken: 3),
        Snapshot(channelID: "d", sourceID: sourceA, sortOrder: 3, recordToken: 4),
        Snapshot(channelID: "c", sourceID: sourceB, sortOrder: 9, recordToken: 5),
    ]
    static let inA = Channel.tagged([channel("c"), channel("d"), channel("e")], sourceID: sourceA)
    static let inB = Channel.tagged([channel("c")], sourceID: sourceB)

    @Test("0013/AC-9a one row per favorite channel, at its lowest sortOrder")
    func oneRowPerChannel() throws {
        let catalogue = TestCatalogue(channels: Self.inA + Self.inB, groupOrder: [:], favorites: Self.snapshots)
        let rows = catalogue.rows(in: .favorites)
        #expect(rows == [try #require(RowKey(Self.inA[0])), try #require(RowKey(Self.inA[1])), try #require(RowKey(Self.inB[0]))])
        #expect(catalogue.count(of: .favorites) == 3)
    }

    @Test("0013/AC-9b removal set covers every matching snapshot")
    func removalSet() {
        let catalogue = TestCatalogue(channels: Self.inA + Self.inB, groupOrder: [:], favorites: Self.snapshots)
        let s = Self.snapshots
        #expect(Set(catalogue.favoritesToRemove(for: Self.inA[0])) == [s[0], s[1], s[2]])
        #expect(catalogue.favoritesToRemove(for: Self.inA[0]).count == 3)
        #expect(Set(catalogue.favoritesToRemove(for: Self.inB[0])) == [s[0], s[4]])
        #expect(catalogue.favoritesToRemove(for: Self.inA[1]) == [s[3]])
        #expect(catalogue.favoritesToRemove(for: Self.inA[2]).isEmpty)
    }

    @Test("0013/AC-9c isFavorite matches a non-empty removal set")
    func favoritePredicate() {
        let catalogue = TestCatalogue(channels: Self.inA + Self.inB, groupOrder: [:], favorites: Self.snapshots)
        for channel in Self.inA + Self.inB {
            #expect(catalogue.isFavorite(channel) == !catalogue.favoritesToRemove(for: channel).isEmpty)
        }
        #expect((Self.inA + Self.inB).map(catalogue.isFavorite) == [true, true, false, true])
    }

    @Test("0013/AC-10 adding a favorite")
    func addFavorite() {
        let c = Channel.tagged([channel("c"), channel("loaded")], sourceID: sourceA)
        let existing = [
            Snapshot(channelID: "loaded", sourceID: sourceA, sortOrder: 1, recordToken: 1),
            Snapshot(channelID: "gone", sourceID: sourceB, sortOrder: 4, recordToken: 2),
        ]
        let catalogue = TestCatalogue(channels: c, groupOrder: [:], favorites: existing)
        #expect(catalogue.isFavorite(c[0]) == false)
        #expect(catalogue.addFavorite(c[0]) == Snapshot(channelID: "c", sourceID: sourceA, sortOrder: 5, recordToken: nil))
        #expect(catalogue.addFavorite(c[1]) == nil)
        let empty = TestCatalogue(channels: c, groupOrder: [:], favorites: [])
        #expect(empty.addFavorite(c[0])?.sortOrder == 0)
    }

    /// 50 000 channels in 400 groups over two sources, a third of them
    /// unnumbered, and 100 favorites.
    struct Input {
        let channels: [Channel]
        let groupOrder: [UUID: [String]]
        let favorites: [Snapshot]
    }

    static func ac14Input() -> Input {
        func source(_ prefix: String, _ id: UUID) -> [Channel] {
            Channel.tagged(
                (0..<25_000).map { i in
                    channel("\(prefix)\(i)", group: "G\(i % 200)", number: i.isMultiple(of: 3) ? nil : 1 + i % 5_000)
                }, sourceID: id)
        }
        let groups = (0..<200).reversed().map { "G\($0)" }
        let favorites = (0..<100).map { i in
            let even = i.isMultiple(of: 2)
            let source = i % 4 == 1 ? nil : (even ? sourceA : sourceB)
            return Snapshot(channelID: "\(even ? "a" : "b")\(i * 250)", sourceID: source, sortOrder: 100 - i)
        }
        return Input(
            channels: source("a", sourceA) + source("b", sourceB), groupOrder: [sourceA: groups, sourceB: groups], favorites: favorites)
    }

    /// Benchmark, not CI-gated. Run with `ANTENNA_BENCHMARKS=1 swift test`.
    /// Reference machine: Apple M1, 16 GB, debug build.
    @Test(
        "0013/AC-14 50,000 channels build within 200 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"),
        .timeLimit(.minutes(1)))
    func buildBenchmark() {
        let input = Self.ac14Input()
        let clock = ContinuousClock()
        var catalogue: TestCatalogue?
        let elapsed = clock.measure {
            catalogue = TestCatalogue(channels: input.channels, groupOrder: input.groupOrder, favorites: input.favorites)
        }
        #expect(catalogue?.count(of: .all) == 50_000)
        #expect(catalogue?.groups.count == 402)
        #expect(catalogue?.count(of: .favorites) == 100)
        #expect(elapsed < .milliseconds(200))
    }

    @Test("0013/AC-19 replacing favorites keeps every other group and number")
    func replaceFavorites() throws {
        let input = Self.ac14Input()
        let original = TestCatalogue(channels: input.channels, groupOrder: input.groupOrder, favorites: input.favorites)
        let changed = [
            Snapshot(channelID: "a1", sourceID: sourceA, sortOrder: 0), Snapshot(channelID: "missing", sourceID: nil, sortOrder: 1),
        ]
        let replaced = original.replacingFavorites(changed)
        #expect(replaced.groups == original.groups)
        for group in original.groups where group != .favorites {
            #expect(replaced.rows(in: group) == original.rows(in: group))
        }
        for key in original.rows(in: .all) where replaced.number(for: key) != original.number(for: key) {
            Issue.record("number changed")
        }
        let a1 = input.channels[1]
        let favorite = try #require(RowKey(a1))
        #expect(replaced.rows(in: .favorites) == [favorite])
        #expect(replaced.isFavorite(a1))
        #expect(replaced.favoritesToRemove(for: a1) == [changed[0]])
        #expect(replaced.unresolvedFavorites == [changed[1]])
        #expect(!replaced.isFavorite(input.channels[0]))
        #expect(original.isFavorite(input.channels[0]))
    }

    /// Benchmark, not CI-gated. Run with `ANTENNA_BENCHMARKS=1 swift test`.
    /// Reference machine: Apple M1, 16 GB, debug build.
    @Test(
        "0013/AC-19 replacing favorites takes under 20 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"),
        .timeLimit(.minutes(1)))
    func replaceBenchmark() {
        let input = Self.ac14Input()
        let original = TestCatalogue(channels: input.channels, groupOrder: input.groupOrder, favorites: input.favorites)
        let changed = Array(input.favorites.dropFirst(10))
        var replaced: TestCatalogue?
        let elapsed = ContinuousClock().measure { replaced = original.replacingFavorites(changed) }
        #expect(replaced?.count(of: .favorites) == 90)
        #expect(elapsed < .milliseconds(20))
    }
}
