import Foundation
import Testing

@testable import AntennaCore

@Suite struct ReminderMatchingTests {
    typealias Fix = ReminderFixture
    let coverage = DateInterval(start: ReminderFixture.at(-600), end: ReminderFixture.at(2000))

    @Test("programme-reminders/reminders-follow-a-programme-that-moves: the same start keeps it and updates title and stop")
    func sameStart() {
        let updated = ReminderMatching.match(
            Fix.reminder(), programmes: [Fix.programme("Match of the Day: Extra", start: 120, stop: 210)], coverage: coverage)
        #expect(updated?.title == "Match of the Day: Extra")
        #expect(updated?.stop == Fix.at(210))
        #expect(updated?.start == Fix.at(120))
        #expect(
            ReminderMatching.match(
                Fix.reminder(), programmes: [Fix.programme("Match of the Day", start: 120, stop: 195)], coverage: coverage)
                == nil)
    }

    @Test("programme-reminders/reminders-follow-a-programme-that-moves: the nearest same title within six hours moves it")
    func moves() {
        let programmes = [
            Fix.programme("MATCH OF THE DAY", start: 60, stop: 120),
            Fix.programme("Match of the Day", start: 180, stop: 240),
            Fix.programme("News", start: 0, stop: 60),
        ]
        let moved = ReminderMatching.match(Fix.reminder(), programmes: programmes, coverage: coverage)
        // 60 and 180 are both an hour away; the earlier wins.
        #expect(moved?.start == Fix.at(60))
        #expect(moved?.stop == Fix.at(120))
        #expect(moved?.movedFrom == Fix.at(120))
        // A second move keeps the first original start.
        let again = ReminderMatching.match(
            moved!, programmes: [Fix.programme("Match of the Day", start: 90, stop: 150)], coverage: coverage)
        #expect(again?.start == Fix.at(90))
        #expect(again?.movedFrom == Fix.at(120))
        // Moving back to the original start clears the note.
        let back = ReminderMatching.match(
            again!, programmes: [Fix.programme("Match of the Day", start: 120, stop: 195)], coverage: coverage)
        #expect(back?.start == Fix.at(120))
        #expect(back?.movedFrom == nil)
    }

    @Test("programme-reminders/reminders-follow-a-programme-that-moves: accents and case are ignored")
    func folding() {
        let reminder = Fix.reminder("Café Crème")
        let moved = ReminderMatching.match(reminder, programmes: [Fix.programme("cafe creme", start: 150, stop: 200)], coverage: coverage)
        #expect(moved?.start == Fix.at(150))
    }

    @Test("programme-reminders/reminders-follow-a-programme-that-moves: more than six hours counts as gone")
    func sixHourLimit() {
        let edge = ReminderMatching.match(
            Fix.reminder(), programmes: [Fix.programme("Match of the Day", start: 480, stop: 540)], coverage: coverage)
        #expect(edge?.start == Fix.at(480))
        let beyond = ReminderMatching.match(
            Fix.reminder(), programmes: [Fix.programme("Match of the Day", start: 481, stop: 540)], coverage: coverage)
        #expect(beyond?.start == Fix.at(120))
        #expect(beyond?.notListed == true)
        #expect(beyond?.movedFrom == nil)
    }

    @Test("programme-reminders/reminders-survive-a-programme-leaving-the-guide: dropped, then back")
    func dropsAndReturns() {
        let dropped = ReminderMatching.match(Fix.reminder(), programmes: [Fix.programme("News", start: 100, stop: 200)], coverage: coverage)
        #expect(dropped?.notListed == true)
        #expect(dropped?.start == Fix.at(120))
        #expect(ReminderMatching.match(dropped!, programmes: [], coverage: coverage) == nil)
        let back = ReminderMatching.match(
            dropped!, programmes: [Fix.programme("Match of the Day", start: 120, stop: 195)], coverage: coverage)
        #expect(back?.notListed == false)
    }

    @Test("programme-reminders/reminders-survive-a-programme-leaving-the-guide: a failed or short guide changes nothing")
    func failedOrShort() {
        #expect(ReminderMatching.match(Fix.reminder(), programmes: [], coverage: nil) == nil)
        let short = DateInterval(start: Fix.at(-600), end: Fix.at(120))
        #expect(ReminderMatching.match(Fix.reminder(), programmes: [Fix.programme("News", start: 60, stop: 120)], coverage: short) == nil)
    }

    @Test("programme-reminders/reminders-survive-a-programme-leaving-the-guide: the channel's own schedule is the coverage")
    func span() {
        let index = GuideIndex(programmes: [Fix.source: [Fix.programme("A", start: 0, stop: 60), Fix.programme("B", start: 60, stop: 90)]])
        #expect(index.span(for: GuideKey(sourceID: Fix.source, epgID: "s1")) == DateInterval(start: Fix.now, end: Fix.at(90)))
        #expect(index.span(for: GuideKey(sourceID: Fix.source, epgID: "other")) == nil)
        #expect(index.span(for: GuideKey(sourceID: UUID(), epgID: "s1")) == nil)
    }
}
