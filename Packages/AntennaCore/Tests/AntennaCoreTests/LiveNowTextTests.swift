import AntennaCore
import Foundation
import Testing

/// What Live on iPhone, iPad and Mac says about the playing channel.
@Suite struct LiveNowTextTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func programme(_ title: String, startsIn minutes: Double, lasting length: Double = 60) -> Programme {
        let start = now.addingTimeInterval(minutes * 60)
        return Programme(channelID: "sport", start: start, stop: start.addingTimeInterval(length * 60), title: title)
    }

    /// Minutes from `now`, so the test does not depend on the time zone.
    private func time(_ date: Date) -> String {
        "\(Int(date.timeIntervalSince(now) / 60))m"
    }

    private func text(state: GuideLoadingState = .loaded, current: Programme?, next: [Programme]) -> LiveNowText {
        LiveNowText(channel: "Sport One", number: 104, state: state, current: current, next: next, now: now, time: time)
    }

    @Test("live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next a programme on now with its times, progress and what follows")
    func programmeOnNow() {
        let titles = ["Match of the Day", "Sports Tonight", "Replay", "Late Film"]
        let following = zip(titles.indices, titles).map { index, title in
            programme(title, startsIn: 30 + Double(index) * 60)
        }
        var current = programme("Premier League", startsIn: -30)
        current.summary = "Second half."
        let line = text(current: current, next: following)

        #expect(line.title == "Premier League")
        #expect(line.times == "-30m – 30m")
        #expect(line.progress == 0.5)
        #expect(line.summary == "Second half.")
        #expect(line.meta == "Sport One · 104 · 30 min left")
        #expect(line.compact == "104 Sport One · -30m – 30m · Next: Match of the Day")
        #expect(line.next.map(\.title) == ["Match of the Day", "Sports Tonight", "Replay"], "three at most")
    }

    @Test("live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next nothing in the guide reads No programme information")
    func nothingInTheGuide() {
        let line = text(current: nil, next: [])
        #expect(line.title == "No programme information")
        #expect(line.times == nil)
        #expect(line.progress == nil)
        #expect(line.summary == nil)
        #expect(line.meta == "Sport One · 104")
        #expect(line.compact == "104 Sport One")

        #expect(text(state: .loading, current: nil, next: []).title == "Loading guide…")
    }

    @Test("live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next a programme that ended no longer shows as on now")
    func programmeEnded() {
        let ended = text(current: programme("Premier League", startsIn: -90), next: [programme("Match of the Day", startsIn: -30)])
        #expect(ended.title == "No programme information")
        #expect(ended.compact == "104 Sport One · Next: Match of the Day")
    }

    @Test("live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next a channel without a number")
    func noNumber() {
        let line = LiveNowText(channel: "Sport One", number: nil, state: .loaded, current: nil, next: [], now: now, time: time)
        #expect(line.meta == "Sport One")
        #expect(line.compact == "Sport One")
    }
}
