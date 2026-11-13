import Foundation
import Testing

@testable import AntennaCore

/// What one move in a channel list asks of the catalogue and the guide, timed
/// over a provider-sized catalogue: 50 000 channels in 400 groups, with group
/// rules, and a seven-day guide. The budgets are for a debug build on a CI
/// runner, with room for a slow one, and still fail a query that walks the
/// whole catalogue.
@Suite struct LiveBrowsingPerformanceTests {
    static let source = UUID()

    static let channels = Channel.tagged(
        (0..<50_000).map { index in
            Channel(
                id: "\(index)", name: "Channel \(index)", streamURL: URL(filePath: "/\(index)"), group: "G\(index % 400)",
                epgID: "ch\(index % 1_000)", number: index + 1)
        }, sourceID: source)

    static let rules: GroupRules = {
        let own = GroupRules.OwnGroup(
            id: UUID(), name: "Mine", members: (0..<200).map { GroupRules.Member(channelID: "\($0 * 7)", sourceID: source) })
        return GroupRules(
            hidden: Set((0..<20).map { CatalogueGroup.named(source, "G\($0)") }),
            locked: Set((20..<60).map { CatalogueGroup.named(source, "G\($0)") }),
            names: [.named(source, "G100"): "Sport"],
            order: Dictionary(uniqueKeysWithValues: (0..<400).map { (CatalogueGroup.named(source, "G\($0)"), 400 - $0) }),
            ownGroups: [own])
    }()

    static let favorites = (0..<300).map { FavoriteSnapshot<Int>(channelID: "\($0 * 13)", sourceID: source, sortOrder: $0) }

    /// The visible rows of a list: fourteen.
    static let visible = 14

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    // tv-channel-overlay/picking-a-group-shows-its-channels
    @Test("tv-channel-overlay/picking-a-group-shows-its-channels moving through 400 groups reads the catalogue in under 8 ms a move")
    func movingThroughGroups() {
        let catalogue = Catalogue<Int>(channels: Self.channels, groupOrder: [:], favorites: Self.favorites, rules: Self.rules)
        let groups = catalogue.groups
        #expect(groups.count > 300)
        var read = 0
        let elapsed = ContinuousClock().measure {
            for shown in groups {
                // The group column: every group's label and count, and whether it is the shown one.
                for group in catalogue.groups {
                    read += catalogue.count(of: group) + (group == shown ? 1 : 0)
                    read += catalogue.customName(of: group)?.count ?? 0
                }
                // The channel column: the shown group's rows, and the rows on screen.
                let rows = catalogue.rows(in: shown)
                for key in rows.prefix(Self.visible) {
                    read += catalogue.channel(for: key)?.name.count ?? 0
                    read += catalogue.channelNumber(for: key)?.major ?? 0
                    read += catalogue.position(of: key, in: shown)?.0 ?? 0
                }
            }
        }
        #expect(read > 0)
        let perMove = Self.seconds(elapsed) / Double(groups.count)
        #expect(perMove < 0.008, "a move took \(perMove * 1000) ms")
    }

    // tv-channel-overlay/every-group-with-its-size
    @Test("tv-channel-overlay/every-group-with-its-size changing a favorite costs under a tenth of indexing 50 000 channels")
    func favoriteWithoutIndexingAgain() {
        let clock = ContinuousClock()
        var catalogue = Catalogue<Int>(channels: [], groupOrder: [:], favorites: [])
        let build = clock.measure {
            catalogue = Catalogue<Int>(channels: Self.channels, groupOrder: [:], favorites: Self.favorites, rules: Self.rules)
        }
        let added = Self.favorites + [FavoriteSnapshot(channelID: "49999", sourceID: Self.source, sortOrder: 300)]
        var replaced = catalogue
        let favorite = clock.measure { replaced = catalogue.replacingFavorites(added) }
        #expect(replaced.count(of: .favorites) == catalogue.count(of: .favorites) + 1)
        #expect(replaced.revision != catalogue.revision)
        #expect(favorite < build / 10, "build took \(build), a favorite took \(favorite)")
    }

    // tv-channel-overlay/each-channel-shows-what-is-on
    @Test("tv-channel-overlay/each-channel-shows-what-is-on the rows on screen and the panel read a seven-day guide in under 5 ms")
    func guideForTheRowsOnScreen() {
        var programmes: [Programme] = []
        programmes.reserveCapacity(1_000 * 336)
        for channel in 0..<1_000 {
            for slot in 0..<336 {
                let start = guideTime(0, slot * 30)
                programmes.append(
                    Programme(channelID: "ch\(channel)", start: start, stop: start.addingTimeInterval(1800), title: "P\(slot)"))
            }
        }
        let index = GuideIndex(programmes: [Self.source: programmes])
        let catalogue = Catalogue<Int>(channels: Self.channels, groupOrder: [:], favorites: [])
        let now = guideTime(80, 10)
        var moves = 0
        var read = 0
        let elapsed = ContinuousClock().measure {
            for group in catalogue.groups.prefix(100) {
                moves += 1
                let rows = catalogue.rows(in: group).prefix(Self.visible).compactMap(catalogue.channel(for:))
                for channel in rows {
                    let line = GuideLine(
                        state: index.loadingState(for: channel),
                        current: index.key(for: channel).flatMap { index.current(for: $0, at: now) },
                        now: now)
                    read += line.text.count
                }
                if let first = rows.first, let key = index.key(for: first) {
                    read += index.next(for: key, after: now, count: 3).count
                }
            }
        }
        #expect(read > 0)
        let perMove = Self.seconds(elapsed) / Double(moves)
        #expect(perMove < 0.005, "a move took \(perMove * 1000) ms")
    }
}
