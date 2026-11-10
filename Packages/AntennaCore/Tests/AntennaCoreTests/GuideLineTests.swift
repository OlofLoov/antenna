import AntennaCore
import Foundation
import Testing

/// What a channel row says about its guide.
@Suite struct GuideLineTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func programme(startsMinutesAgo ago: Double, lasting minutes: Double) -> Programme {
        let start = now.addingTimeInterval(-ago * 60)
        return Programme(channelID: "news", start: start, stop: start.addingTimeInterval(minutes * 60), title: "Morning News")
    }

    @Test("tv-channel-overlay/each-channel-shows-what-is-on a programme on now with progress and time left")
    func programmeOnNow() {
        let line = GuideLine(state: .loaded, current: programme(startsMinutesAgo: 15, lasting: 60), now: now)
        #expect(line == .programme(title: "Morning News", progress: 0.25, remaining: "45 min left"))
        #expect(line.text == "Morning News")
    }

    @Test("tv-channel-overlay/each-channel-shows-what-is-on no programme, a loading guide and a failed one")
    func states() {
        #expect(GuideLine(state: .loaded, current: nil, now: now) == .message("No programme information"))
        #expect(GuideLine(state: .noData, current: nil, now: now) == .message("No programme information"))
        #expect(GuideLine(state: .unavailable, current: nil, now: now) == .message("No programme information"))
        #expect(GuideLine(state: .failed(.timeout), current: nil, now: now) == .message("No programme information"))
        #expect(GuideLine(state: .loading, current: nil, now: now) == .message("Loading guide…"))
        let over = programme(startsMinutesAgo: 90, lasting: 60)
        let ended = GuideLine(state: .loaded, current: over, now: now)
        #expect(ended == .message("No programme information"), "a programme that ended moves on")
    }

    @Test("tv-channel-overlay/each-channel-shows-what-is-on the catch-up mark")
    func catchUp() {
        let link = URL(fileURLWithPath: "/a.ts")
        #expect(Channel(id: "a", name: "A", streamURL: link, hasCatchup: true, catchupDays: 7).catchUpBadge == "CATCH-UP 7D")
        #expect(Channel(id: "a", name: "A", streamURL: link, hasCatchup: true).catchUpBadge == "CATCH-UP")
        #expect(Channel(id: "a", name: "A", streamURL: link, catchupDays: 3).catchUpBadge == "CATCH-UP 3D")
        #expect(Channel(id: "a", name: "A", streamURL: link).catchUpBadge == nil)
    }
}
