import Foundation
import Testing

@testable import AntennaCore

@Suite struct StartOverPlannerTests {
    static let now = Date(timeIntervalSince1970: 1_793_824_800)  // 20:40Z
    static let programme = Programme(
        channelID: "s1", start: now.addingTimeInterval(-2400), stop: now.addingTimeInterval(4800), title: "Match")
    static let channel = Channel(
        id: "m3u#a#1", name: "Sport One", streamURL: URL(filePath: "/live.ts"), hasCatchup: true, sourceID: UUID(), position: 0)
    static let catchup = URL(filePath: "/catchup.ts")

    static func plan(
        playing: Channel? = channel, programme: Programme? = programme, window: TimeshiftWindow? = nil, url: URL? = nil
    ) -> StartOverPlan {
        StartOverPlanner.plan(channel: channel, playing: playing, programme: programme, now: now, window: window) { _ in url }
    }

    @Test("timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work: catch-up first, the buffer second")
    func appears() {
        #expect(Self.plan(url: Self.catchup) == .catchup(Self.catchup, Self.programme))
        let reaching = TimeshiftWindow(start: Self.programme.start.addingTimeInterval(-60), end: Self.now)
        #expect(Self.plan(window: reaching, url: Self.catchup) == .catchup(Self.catchup, Self.programme))
        #expect(Self.plan(window: reaching) == .buffer(Self.programme))
    }

    @Test("timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work: when it is absent")
    func absent() {
        let short = TimeshiftWindow(start: Self.now.addingTimeInterval(-600), end: Self.now)
        #expect(Self.plan(window: short) == .none)
        #expect(Self.plan(programme: nil, url: Self.catchup) == .none)
        var other = Self.channel
        other.id = "m3u#b#2"
        #expect(Self.plan(playing: other, url: Self.catchup) == .none)
        #expect(Self.plan(playing: nil, url: Self.catchup) == .none)
        let later = Programme(
            channelID: "s1", start: Self.now.addingTimeInterval(60), stop: Self.now.addingTimeInterval(600), title: "Next")
        #expect(Self.plan(programme: later, url: Self.catchup) == .none)
    }

    @Test("timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work: the request is the programme on now")
    func request() {
        var asked: CatchupRequest?
        _ = StartOverPlanner.plan(channel: Self.channel, playing: Self.channel, programme: Self.programme, now: Self.now, window: nil) {
            asked = $0
            return nil
        }
        #expect(asked == CatchupRequest(start: Self.programme.start, duration: 7200, now: Self.now))
    }
}
