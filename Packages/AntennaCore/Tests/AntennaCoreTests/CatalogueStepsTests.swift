import Foundation
import Testing

@testable import AntennaCore

@Suite struct CatalogueStepsTests {
    private let catalogue = TestCatalogue(
        channels: Channel.tagged([channel("a1"), channel("a2"), channel("a3")], sourceID: sourceA)
            + Channel.tagged([channel("b1")], sourceID: sourceB),
        groupOrder: [:], favorites: [],
        recents: [LastChannelKey(sourceID: sourceA, channelID: "a2"), LastChannelKey(sourceID: sourceB, channelID: "b1")])

    private func key(_ id: String) throws -> RowKey {
        try #require(catalogue.rows(in: .all).first { $0.id == id })
    }

    @Test("live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel steps wrap round at either end")
    func wraps() throws {
        let rows = catalogue.rows(in: .all)
        #expect(catalogue.neighbor(of: try key("a1"), in: rows, by: 1)?.id == "a2")
        #expect(catalogue.neighbor(of: try key("a1"), in: rows, by: -1)?.id == "b1")
        #expect(catalogue.neighbor(of: try key("b1"), in: rows, by: 1)?.id == "a1")
    }

    @Test("live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel a list of one or without the channel gives nothing")
    func nothing() throws {
        #expect(catalogue.neighbor(of: try key("a1"), in: [try key("a1")], by: 1) == nil)
        #expect(catalogue.neighbor(of: try key("a1"), in: [try key("a2"), try key("a3")], by: 1) == nil)
    }

    @Test("live-tv-on-iphone-ipad-mac/go-back-to-the-previous-channel Recents gives the newest other channel")
    func recents() throws {
        #expect(catalogue.mostRecent(otherThan: try key("a2"))?.id == "b1")
        #expect(catalogue.mostRecent(otherThan: try key("a1"))?.id == "a2")
        #expect(catalogue.mostRecent(otherThan: nil)?.id == "a2")
        let one = TestCatalogue(
            channels: Channel.tagged([channel("a1")], sourceID: sourceA), groupOrder: [:], favorites: [],
            recents: [LastChannelKey(sourceID: sourceA, channelID: "a1")])
        #expect(one.mostRecent(otherThan: one.rows(in: .all).first) == nil)
    }
}
