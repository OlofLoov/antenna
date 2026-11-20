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
        LiveNowText(channel: "Sport One", number: 104, state: state, current: current, next: next, now: now, time: time, locale: .english)
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
        let line = LiveNowText(
            channel: "Sport One", number: nil, state: .loaded, current: nil, next: [], now: now, time: time, locale: .english)
        #expect(line.meta == "Sport One")
        #expect(line.compact == "Sport One")
    }

    @Test("localization/mixed-scripts-keep-their-own-direction the iPhone line reads from the right in Arabic")
    func arabicCompactLine() {
        let arabic = Locale(identifier: "ar_SA")
        let line = LiveNowText(
            channel: "News One", number: 1, state: .loaded, current: programme("Morning News", startsIn: -10),
            next: [programme("Weather", startsIn: 50)], now: now, time: time, locale: arabic)
        // A right-to-left mark first, then the number, the isolated name, the times and the next title.
        #expect(line.compact.hasPrefix("\u{200F}١ \u{2068}News One\u{2069} • -10m – 50m • التالي: \u{2068}"))
        #expect(line.compact.withoutIsolates == "\u{200F}١ News One • -10m – 50m • التالي: Weather")
        #expect(line.meta.hasPrefix("\u{200F}\u{2068}News One\u{2069} • ١"))
        let english = LiveNowText(
            channel: "News One", number: 1, state: .loaded, current: programme("Morning News", startsIn: -10),
            next: [programme("Weather", startsIn: 50)], now: now, time: time, locale: Locale(identifier: "en_US"))
        #expect(english.compact == "1 News One · -10m – 50m · Next: Weather")
    }

    @Test("localization/mixed-scripts-keep-their-own-direction the guide's picture caption reads from the right in Arabic")
    func channelIdentity() {
        let arabic = ChannelIdentityText.text(number: 1, name: "Channel a1", locale: Locale(identifier: "ar_SA"))
        #expect(arabic == "\u{200F}١ \u{2068}Channel a1\u{2069}")
        #expect(ChannelIdentityText.text(number: 104, name: "Sport One", locale: Locale(identifier: "en_US")) == "104 Sport One")
        #expect(ChannelIdentityText.text(number: nil, name: "Sport One", locale: Locale(identifier: "en_US")) == "Sport One")
    }
}
