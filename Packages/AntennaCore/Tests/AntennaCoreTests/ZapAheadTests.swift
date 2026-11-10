import Foundation
import Testing

@testable import AntennaCore

/// Which channels open ahead of a zap, by the account's connection limit.
@Suite struct ZapAheadTests {
    let lineup = (1...5).compactMap { URL(string: "http://p.test/live/u/p/\($0).ts") }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly a one-connection provider gets nothing opened ahead")
    func oneConnectionOpensNothing() {
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 1).isEmpty)
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: nil).isEmpty)
    }

    @Test("playback-engine/channel-switching-is-fast two connections open the next channel in the zap direction")
    func twoConnectionsOpenOne() {
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 2) == [lineup[3]])
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 2, direction: .down) == [lineup[1]])
    }

    @Test("playback-engine/channel-switching-is-fast three or more connections open both neighbors, wrapping at the ends")
    func threeConnectionsOpenBoth() {
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 3) == [lineup[3], lineup[1]])
        #expect(ZapAhead.addresses(around: 4, in: lineup, allowedConnections: 5) == [lineup[0], lineup[3]])
        #expect(ZapAhead.addresses(around: 0, in: lineup, allowedConnections: 3) == [lineup[1], lineup[4]])
    }

    @Test("playback-engine/channel-switching-is-fast short lineups never open the current channel or one twice")
    func shortLineups() {
        #expect(ZapAhead.addresses(around: 0, in: [lineup[0]], allowedConnections: 3).isEmpty)
        #expect(ZapAhead.addresses(around: 0, in: Array(lineup[0...1]), allowedConnections: 3) == [lineup[1]])
        #expect(ZapAhead.addresses(around: 9, in: lineup, allowedConnections: 3).isEmpty)
    }

    @Test func xtreamLimitParses() {
        #expect(ZapAhead.allowedConnections(xtream: "2") == 2)
        #expect(ZapAhead.allowedConnections(xtream: " 3 ") == 3)
        #expect(ZapAhead.allowedConnections(xtream: "0") == nil)
        #expect(ZapAhead.allowedConnections(xtream: "unlimited") == nil)
        #expect(ZapAhead.allowedConnections(xtream: nil) == nil)
    }
}
