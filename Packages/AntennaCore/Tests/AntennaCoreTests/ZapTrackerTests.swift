import Foundation
import Testing

@testable import AntennaCore

/// Scanning through channels versus settling on one.
@Suite struct ZapTrackerTests {
    let start = ContinuousClock.now

    @Test("playback-engine/channel-switching-is-fast two quick changes one way start a scan")
    func quickChangesScan() {
        var tracker = ZapTracker()
        #expect(tracker.zapped(.up, at: start) == .settled)
        #expect(tracker.zapped(.up, at: start + .milliseconds(600)) == .scanning(.up))
        #expect(tracker.zapped(.up, at: start + .milliseconds(1100)) == .scanning(.up))
    }

    @Test("playback-engine/channel-switching-is-fast a slow change or a turn back is not a scan")
    func slowOrTurningIsNotAScan() {
        var tracker = ZapTracker()
        _ = tracker.zapped(.up, at: start)
        #expect(tracker.zapped(.up, at: start + .seconds(3)) == .settled)
        _ = tracker.zapped(.up, at: start + .seconds(3) + .milliseconds(400))
        #expect(tracker.zapped(.down, at: start + .seconds(3) + .milliseconds(800)) == .settled)
    }

    @Test("playback-engine/channel-switching-is-fast a scan ends when the user stays on a channel")
    func scanSettles() {
        var tracker = ZapTracker()
        _ = tracker.zapped(.down, at: start)
        _ = tracker.zapped(.down, at: start + .milliseconds(500))
        #expect(tracker.mode(at: start + .milliseconds(1500)) == .scanning(.down))
        #expect(tracker.mode(at: start + .milliseconds(2100)) == .settled)
    }

    @Test("playback-engine/channel-switching-is-fast while scanning, the next two channels that way open ahead")
    func scanningOpensAhead() {
        let lineup = (1...6).compactMap { URL(string: "http://p.test/live/u/p/\($0).ts") }
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 3, direction: .up, scanning: true) == [lineup[3], lineup[4]])
        #expect(
            ZapAhead.addresses(around: 1, in: lineup, allowedConnections: 3, direction: .down, scanning: true) == [lineup[0], lineup[5]])
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 2, direction: .up, scanning: true) == [lineup[3]])
        #expect(ZapAhead.addresses(around: 2, in: lineup, allowedConnections: 1, direction: .up, scanning: true).isEmpty)
    }
}
