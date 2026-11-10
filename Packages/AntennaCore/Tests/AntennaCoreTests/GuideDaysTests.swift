import AntennaCore
import Foundation
import Testing

@Suite struct GuideDaysTests {
    let calendar = gridCalendar()
    let locale = Locale(identifier: "en_US")
    /// Monday 22 March 2027 at 21:34; the guide reaches 06:00 on Tuesday 30 March.
    let now = march(22, 21, 34)
    var timeline: GuideTimeline {
        GuideTimeline(horizon: DateInterval(start: march(22, 6), end: march(30, 6)), now: now, calendar: calendar)
    }

    @Test("tv-guide-grid/pick-a-day today and each later day the guide covers")
    func dayList() {
        let days = timeline.days(at: now)
        #expect(days == (22...30).map { march($0, 0) })
        let labels = days.map { timeline.dayLabel($0, today: now, locale: locale) }
        #expect(labels == ["Today", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun", "Mon 29", "Tue 30"])
    }

    @Test("tv-guide-grid/pick-a-day picking a day keeps the time of day")
    func pick() {
        let days = timeline.days(at: now)
        #expect(timeline.start(march(22, 20), movedTo: days[3]) == march(25, 20))
        #expect(timeline.start(march(25, 20), movedTo: days[0]) == march(22, 20))
        // The last day is cut at the guide's 06:00 end.
        #expect(timeline.start(march(22, 20), movedTo: days[8]) == march(30, 4))
    }

    @Test("tv-guide-grid/pick-a-day the chosen day follows the window past midnight")
    func followsScrolling() {
        let days = timeline.days(at: now)
        #expect(timeline.dayIndex(of: march(22, 23, 30), in: days) == 0)
        #expect(timeline.dayIndex(of: march(23, 0), in: days) == 1)
        #expect(timeline.dayIndex(of: march(30, 4), in: days) == 8)
        #expect(timeline.dayIndex(of: march(21, 23), in: days) == 0)
    }

    @Test("tv-guide-grid/pick-a-day a guide with no dates gives a single Today")
    func noDates() {
        let bare = GuideTimeline(horizon: nil, now: now, calendar: calendar)
        let days = bare.days(at: now)
        #expect(days == [march(22, 0)])
        #expect(days.map { bare.dayLabel($0, today: now, locale: locale) } == ["Today"])
        let ended = GuideTimeline(horizon: DateInterval(start: march(20, 6), end: march(21, 6)), now: now, calendar: calendar)
        #expect(ended.days(at: now) == [march(22, 0)])
    }

    @Test("tv-guide-grid/pick-a-day calendar days follow the time zone across daylight saving")
    func daylightSaving() {
        // Sunday 28 March 2027 has 23 hours in Stockholm.
        let days = timeline.days(at: now)
        #expect(days[6] == march(28, 0))
        #expect(days[7] == march(29, 0))
        #expect(days[7].timeIntervalSince(days[6]) == 23 * 3600)
        #expect(timeline.start(march(22, 20), movedTo: days[6]) == march(28, 20))
        // 02:30 does not exist that night; the window starts at 03:00.
        #expect(timeline.start(march(22, 2, 30), movedTo: days[6]) == march(28, 3))
    }
}
