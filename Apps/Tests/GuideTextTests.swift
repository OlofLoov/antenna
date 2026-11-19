import AntennaCore
import Foundation
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// The guide's VoiceOver line and panel, in an explicit English locale so
    /// a simulator set to another language reads the same.
    @Suite struct GuideTextTests {
        let text = GuideText(locale: Locale(identifier: "en_US"))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var stop: Date { start.addingTimeInterval(3600) }
        let channel = Channel(id: "c1", name: "Sport One", streamURL: URL(fileURLWithPath: "/s.ts"), epgID: "s1")

        var cell: GuideCell {
            GuideCell(
                segment: GuideSegment(
                    start: start, stop: stop, programme: Programme(channelID: "s1", start: start, stop: stop, title: "Match")))
        }

        @Test("tv-guide-grid/the-panel-describes-the-highlighted-programme VoiceOver reads channel, title, times and timing")
        func spoken() {
            let times = "\(text.time(start)) to \(text.time(stop))"
            #expect(text.spoken(cell, channel: channel, now: start.addingTimeInterval(60)) == "Sport One, Match, \(times), on now")
            #expect(text.spoken(cell, channel: channel, now: stop.addingTimeInterval(60)) == "Sport One, Match, \(times), past")
            #expect(text.spoken(cell, channel: channel, now: start.addingTimeInterval(-60)) == "Sport One, Match, \(times), later")
        }

        @Test("tv-guide-grid/the-panel-describes-the-highlighted-programme the panel names a programme on now")
        func details() {
            let timeline = GuideTimeline(horizon: DateInterval(start: start, end: stop), now: start, calendar: .autoupdatingCurrent)
            let details = text.details(cell, channel: channel, timeline: timeline, now: start.addingTimeInterval(60), quality: nil)
            #expect(details.eyebrow == "Now · Sport One")
            #expect(details.title == "Match")
        }

        @Test("localization/times-and-dates-follow-the-user-s-region the clock follows the locale, not the device")
        func clock() {
            let american = text.time(start)
            let swedish = GuideText(locale: Locale(identifier: "sv_SE")).time(start)
            #expect(american.contains("AM") || american.contains("PM"))
            #expect(!swedish.contains("AM") && !swedish.contains("PM"))
            #expect(LiveModel.time(start, locale: Locale(identifier: "en_US")) == american)
        }
    }
#endif
