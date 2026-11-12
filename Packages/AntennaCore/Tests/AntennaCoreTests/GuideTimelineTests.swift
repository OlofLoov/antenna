import AntennaCore
import Foundation
import Testing

/// A Gregorian calendar in `zone`, so every test fixes the clock and the zone.
func gridCalendar(_ zone: String = "Europe/Stockholm") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

/// `day` March 2027 at `hour`:`minute` local time in `calendar`.
func march(_ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar = gridCalendar()) -> Date {
    calendar.date(from: DateComponents(year: 2027, month: 3, day: day, hour: hour, minute: minute)) ?? .distantPast
}

/// "21:30" in `calendar`'s zone.
func clockText(_ date: Date, in calendar: Calendar = gridCalendar()) -> String {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
}

@Suite struct GuideTimelineTests {
    let calendar = gridCalendar()
    /// From 06:10 on Monday 22 March to 06:00 on Tuesday 30 March.
    var horizon: DateInterval { DateInterval(start: march(22, 6, 10), end: march(30, 6)) }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time opening at 21:34 shows 20:00 to 22:00")
    func opensAroundNow() {
        let timeline = GuideTimeline(horizon: horizon, now: march(22, 21, 34), calendar: calendar)
        let start = timeline.opening(at: march(22, 21, 34))
        #expect(start == march(22, 20))
        #expect(timeline.columns(from: start).map { clockText($0) } == ["20:00", "20:30", "21:00", "21:30"])
        #expect(timeline.window(from: start) == DateInterval(start: march(22, 20), end: march(22, 22)))
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time the now line moves with the clock and hides out of view")
    func nowLine() throws {
        let timeline = GuideTimeline(horizon: horizon, now: march(22, 21, 34), calendar: calendar)
        let start = march(22, 20)
        let line = try #require(timeline.nowLine(at: march(22, 21, 34), windowStart: start))
        #expect(abs(line - 94 * 370 / 30) < 0.001)
        let later = try #require(timeline.nowLine(at: march(22, 21, 35), windowStart: start))
        #expect(abs(later - line - 370 / 30) < 0.001)
        #expect(timeline.nowLine(at: march(22, 21, 34), windowStart: march(22, 22)) == nil)
        #expect(timeline.nowLine(at: march(22, 22), windowStart: start) == nil)
        #expect(timeline.nowLine(at: march(22, 20), windowStart: start) == 0)
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time half hours are local, also in a zone a quarter off")
    func localHalfHours() {
        let nepal = gridCalendar("Asia/Kathmandu")
        let timeline = GuideTimeline(horizon: nil, now: march(22, 21, 34, in: nepal), calendar: nepal)
        #expect(timeline.halfHour(atOrBefore: march(22, 21, 34, in: nepal)) == march(22, 21, 30, in: nepal))
        #expect(timeline.halfHour(atOrBefore: march(22, 21, 30, in: nepal)) == march(22, 21, 30, in: nepal))
        #expect(timeline.opening(at: march(22, 21, 34, in: nepal)) == march(22, 20, in: nepal))
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time scrolling stays inside the guide's reach")
    func bounds() {
        let timeline = GuideTimeline(horizon: horizon, now: march(22, 7), calendar: calendar)
        #expect(timeline.bounds.start == march(22, 6))
        // The last column starts at 05:30, strictly before the 06:00 end.
        #expect(timeline.latestStart == march(30, 4))
        #expect(timeline.opening(at: march(22, 7)) == march(22, 6))
        #expect(timeline.clamp(march(21, 12)) == march(22, 6))
        #expect(timeline.clamp(march(31, 12)) == march(30, 4))
        #expect(timeline.moving(march(22, 6), by: -1) == march(22, 6))
        #expect(timeline.moving(march(22, 6), by: 3) == march(22, 7, 30))
        #expect(timeline.moving(march(30, 4), by: 1) == march(30, 4))
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time with no guide the grid covers today")
    func noHorizon() {
        let timeline = GuideTimeline(horizon: nil, now: march(22, 21, 34), calendar: calendar)
        #expect(timeline.bounds == DateInterval(start: march(22, 0), end: march(23, 0)))
        #expect(timeline.latestStart == march(22, 22))
        #expect(timeline.opening(at: march(22, 23, 50)) == march(22, 22))
        #expect(timeline.opening(at: march(22, 0, 40)) == march(22, 0))
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time the header shows the missing hour in spring")
    func springForward() {
        // Sweden moves from 02:00 to 03:00 on 28 March 2027.
        let wide = DateInterval(start: march(27, 0), end: march(29, 0))
        let timeline = GuideTimeline(horizon: wide, now: march(28, 1), calendar: calendar)
        let start = march(28, 1)
        #expect(timeline.columns(from: start).map { clockText($0) } == ["01:00", "01:30", "03:00", "03:30"])
        #expect(timeline.window(from: start).duration == 2 * 3600)
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time the header shows the repeated hour in autumn")
    func fallBack() throws {
        // Sweden moves from 03:00 back to 02:00 on 31 October 2027.
        let first = try #require(calendar.date(from: DateComponents(year: 2027, month: 10, day: 31, hour: 2)))
        let wide = DateInterval(start: first.addingTimeInterval(-86_400), end: first.addingTimeInterval(86_400))
        let timeline = GuideTimeline(horizon: wide, now: first, calendar: calendar)
        #expect(timeline.columns(from: first).map { clockText($0) } == ["02:00", "02:30", "02:00", "02:30"])
    }

    @Test("sources-and-settings/choose-how-the-app-behaves the Guide window sets the hours the grid shows")
    func guideWindowHours() throws {
        let start = march(22, 20)
        for hours in [2, 3, 4] {
            let timeline = GuideTimeline(horizon: horizon, now: march(22, 21, 34), calendar: calendar, hours: hours)
            #expect(timeline.opening(at: march(22, 21, 34)) == start)
            #expect(timeline.columns(from: start).count == hours * 2)
            #expect(timeline.window(from: start) == DateInterval(start: start, duration: Double(hours) * 3600))
            // The window keeps its 1480 pt width; the columns narrow.
            #expect(timeline.scale.columnWidth * Double(hours * 2) == 1480)
            #expect(timeline.scale.minimumBlockWidth == 40)
            let line = try #require(timeline.nowLine(at: march(22, 21, 34), windowStart: start))
            #expect(abs(line - 94 * 1480 / Double(hours * 60)) < 0.001)
            #expect(timeline.latestStart == march(30, 6).addingTimeInterval(-Double(hours) * 3600))
        }
        let four = GuideTimeline(horizon: horizon, now: march(22, 21, 34), calendar: calendar, hours: 4)
        #expect(four.columns(from: start).map { clockText($0) }.last == "23:30")
        #expect(four.nowLine(at: march(22, 23, 50), windowStart: start) != nil)
    }

    @Test("tv-guide-grid/open-at-a-programme-found-in-search the window starts at the programme's half hour")
    func showing() {
        let timeline = GuideTimeline(horizon: horizon, now: march(22, 9), calendar: calendar)
        #expect(timeline.start(showing: march(24, 21, 45)) == march(24, 21, 30))
        #expect(timeline.start(showing: march(30, 5, 45)) == march(30, 4))
    }
}
