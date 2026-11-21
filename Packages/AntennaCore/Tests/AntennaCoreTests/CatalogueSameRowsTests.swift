import Foundation
import Testing

@testable import AntennaCore

/// A screen can tell that a group's rows did not change without comparing them.
@Suite struct CatalogueSameRowsTests {
    let source = UUID()

    private var catalogue: Catalogue<Int> {
        let channels = (0..<4).map {
            Channel(
                id: "c\($0)", name: "C\($0)", streamURL: URL(filePath: "/\($0).ts"), group: "News", sourceID: source, position: $0)
        }
        return Catalogue(channels: channels, groupOrder: [:], favorites: [])
    }

    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive new recents leave every other group the same")
    func recents() {
        let before = catalogue
        let after = before.replacingRecents([LastChannelKey(sourceID: source, channelID: "c1")])
        #expect(after.sameRows(in: .all, as: before))
        #expect(after.sameRows(in: .named(source, "News"), as: before))
        #expect(after.sameRows(in: .favorites, as: before))
        #expect(!after.sameRows(in: .recents, as: before))
    }

    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive new favorites change Favorites only")
    func favorites() {
        let before = catalogue
        let after = before.replacingFavorites([FavoriteSnapshot(channelID: "c2", sourceID: source, sortOrder: 0)])
        #expect(after.sameRows(in: .all, as: before))
        #expect(after.sameRows(in: .recents, as: before))
        #expect(!after.sameRows(in: .favorites, as: before))
    }

    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive new rules or a new build change every group")
    func rulesAndBuilds() {
        let before = catalogue
        #expect(!before.replacingRules(GroupRules(hidden: [.all])).sameRows(in: .all, as: before))
        #expect(!catalogue.sameRows(in: .all, as: before), "another build")
    }
}
