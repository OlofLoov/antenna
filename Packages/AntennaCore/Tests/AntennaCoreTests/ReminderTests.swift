import Foundation
import Testing

@testable import AntennaCore

/// Fixtures shared by the reminder suites. 1_800_000_000 is Fri 15 Jan 2027 08:00 UTC.
enum ReminderFixture {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let source = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xAA))

    static func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }

    static func reminder(
        _ title: String = "Match of the Day", start: Double = 120, stop: Double? = 195, guideID: String = "s1",
        created: Double = 0, id: Int = 1, movedFrom: Double? = nil, notListed: Bool = false
    ) -> Reminder {
        Reminder(
            id: uuid(id), sourceID: source, guideID: guideID, start: at(start), stop: stop.map(at), title: title,
            channelName: "Sport One", movedFrom: movedFrom.map(at), notListed: notListed, createdAt: at(created))
    }

    static func programme(_ title: String, start: Double, stop: Double, guideID: String = "s1") -> Programme {
        Programme(channelID: guideID, start: at(start), stop: at(stop), title: title)
    }

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

@Suite struct ReminderListTests {
    typealias Fix = ReminderFixture

    @Test("programme-reminders/see-every-upcoming-reminder-in-one-list: duplicates show once, earliest created first, soonest first")
    func duplicatesShowOnce() {
        let early = Fix.reminder(created: -10, id: 5)
        let late = Fix.reminder(created: -5, id: 2)
        let sameTimeLowerID = Fix.reminder(created: -10, id: 3)
        let other = Fix.reminder("News", start: 60, stop: 90, guideID: "n1", id: 9)
        let list = ReminderList.upcoming([early, late, other, sameTimeLowerID], now: Fix.now)
        #expect(list.map(\.id) == [other.id, sameTimeLowerID.id])
        #expect(Set(ReminderList.duplicates(in: [early, late, other, sameTimeLowerID])) == [early.id, late.id])
    }

    @Test("programme-reminders/remove-a-reminder-anywhere: removing deletes every copy")
    func removalTakesEveryCopy() {
        let copies = [Fix.reminder(id: 1), Fix.reminder(id: 2), Fix.reminder("News", start: 60, guideID: "n1", id: 3)]
        #expect(Set(ReminderList.copies(of: copies[0].key, in: copies)) == [Fix.uuid(1), Fix.uuid(2)])
    }

    @Test("programme-reminders/remove-a-reminder-anywhere: a deleted source takes its reminders")
    func sourceDeletion() {
        let other = Reminder(
            sourceID: UUID(), guideID: "s1", start: Fix.at(60), stop: nil, title: "X", channelName: "Y", createdAt: Fix.now)
        #expect(ReminderList.onSource(Fix.source, in: [Fix.reminder(), other]) == [Fix.uuid(1)])
    }

    @Test("programme-reminders/see-every-upcoming-reminder-in-one-list: ended programmes hide, and go ten minutes later")
    func endedHideThenDelete() {
        let ended = Fix.reminder(start: -60, stop: -5)
        #expect(ReminderList.upcoming([ended], now: Fix.now).isEmpty)
        #expect(ReminderList.expired([ended], now: Fix.now).isEmpty)
        #expect(ReminderList.expired([ended], now: Fix.at(5)) == [ended.id])
        // A device whose clock runs four minutes fast hides it but does not delete it.
        let fastClock = Fix.at(-5 + 4)
        #expect(ReminderList.upcoming([ended], now: fastClock).isEmpty)
        #expect(ReminderList.expired([ended], now: fastClock).isEmpty)
    }

    @Test("programme-reminders/see-every-upcoming-reminder-in-one-list: no stop counts as three hours")
    func noStop() {
        let open = Fix.reminder(start: -170, stop: nil)
        #expect(ReminderList.upcoming([open], now: Fix.now).count == 1)
        #expect(ReminderList.upcoming([open], now: Fix.at(10)).isEmpty)
    }

    @Test("programme-reminders/watch-plays-the-channel: several channels on one listing play the first")
    func firstChannel() {
        let url = URL(string: "http://example.invalid/1.ts")!
        let channels = [
            Channel(id: "a", name: "Other", streamURL: url, epgID: "x", sourceID: Fix.source),
            Channel(id: "b", name: "Sport One HD", streamURL: url, epgID: "s1", sourceID: Fix.source),
            Channel(id: "c", name: "Sport One", streamURL: url, epgID: "s1", sourceID: Fix.source),
        ]
        #expect(Fix.reminder().channel(in: channels)?.id == "b")
        #expect(Fix.reminder(guideID: "gone").channel(in: channels) == nil)
    }
}

@Suite struct ReminderScheduleTests {
    typealias Fix = ReminderFixture

    @Test(
        "programme-reminders/choose-how-early-reminders-go-off: each lead time moves the fire date",
        arguments: ReminderLeadTime.allCases)
    func leadTimes(lead: ReminderLeadTime) {
        let schedule = ReminderSchedule(lead: lead)
        #expect(schedule.fireDate(Fix.reminder()) == Fix.at(120 - Double(lead.rawValue)))
        let plan = schedule.notifications(for: [Fix.reminder()], delivery: ReminderDelivery(), now: Fix.now)
        #expect(plan.notifications.map(\.fireAt) == [Fix.at(120 - Double(lead.rawValue))])
    }

    @Test("programme-reminders/choose-how-early-reminders-go-off: five minutes until the user picks")
    func standard() {
        #expect(ReminderLeadTime.standard == .five)
        #expect(ReminderLeadTime.allCases.map(\.title) == ["At start", "5 minutes", "10 minutes", "15 minutes", "30 minutes"])
    }

    @Test("programme-reminders/a-notification-before-the-programme-starts: set inside the lead time goes off at once")
    func insideLeadTime() {
        let schedule = ReminderSchedule(lead: .ten)
        let soon = Fix.reminder(start: 3, stop: 60)
        let plan = schedule.notifications(for: [soon], delivery: ReminderDelivery(), now: Fix.now)
        #expect(plan.notifications.map(\.fireAt) == [Fix.now.addingTimeInterval(1)])
        #expect(schedule.due([soon], delivery: ReminderDelivery(), now: Fix.now) == [soon])
        // The next pass, after it went off, schedules it no more.
        let next = schedule.notifications(for: [soon], delivery: plan.delivery, now: Fix.now.addingTimeInterval(2))
        #expect(next.notifications.isEmpty)
        #expect(next.delivery.reminded == [soon.key.text])
    }

    @Test("programme-reminders/a-notification-before-the-programme-starts: at most 64 pending, topped up as they go")
    func sixtyFourWindow() {
        let reminders = (0..<70).map { Fix.reminder("P\($0)", start: Double(60 + $0 * 30), stop: Double(80 + $0 * 30), id: $0 + 1) }
        let schedule = ReminderSchedule(lead: .five)
        let first = schedule.notifications(for: reminders.shuffled(), delivery: ReminderDelivery(), now: Fix.now)
        #expect(first.notifications.count == 64)
        #expect(first.notifications.map(\.reminder.title) == (0..<64).map { "P\($0)" })
        let later = schedule.notifications(for: reminders, delivery: first.delivery, now: Fix.at(60 + 30 + 1))
        #expect(later.notifications.first?.reminder.title == "P2")
        #expect(later.notifications.last?.reminder.title == "P65")
    }

    @Test("programme-reminders/a-notification-before-the-programme-starts: a time zone change keeps the moment")
    func timeZoneChange() {
        let schedule = ReminderSchedule(lead: .five)
        let fire = schedule.fireDate(Fix.reminder())
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        var tokyo = berlin
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        #expect(ReminderText(calendar: berlin, locale: Locale(identifier: "en_GB")).time(Fix.at(120)) == "11:00")
        #expect(ReminderText(calendar: tokyo, locale: Locale(identifier: "en_GB")).time(Fix.at(120)) == "19:00")
        #expect(schedule.fireDate(Fix.reminder()) == fire)
    }

    @Test("programme-reminders/a-banner-while-antenna-is-open: due once, then not again, and the next one is known")
    func dueOnce() {
        let schedule = ReminderSchedule(lead: .five)
        let reminder = Fix.reminder(start: 30, stop: 90)
        #expect(schedule.due([reminder], delivery: ReminderDelivery(), now: Fix.now).isEmpty)
        #expect(schedule.nextFire([reminder], delivery: ReminderDelivery(), now: Fix.now) == Fix.at(25))
        #expect(schedule.due([reminder], delivery: ReminderDelivery(), now: Fix.at(25)) == [reminder])
        let shown = ReminderDelivery(reminded: [reminder.key.text])
        #expect(schedule.due([reminder], delivery: shown, now: Fix.at(26)).isEmpty)
        #expect(schedule.nextFire([reminder], delivery: shown, now: Fix.now) == nil)
    }

    @Test("programme-reminders/a-banner-while-antenna-is-open: a missed reminder is due while its programme is on, not after")
    func missed() {
        let schedule = ReminderSchedule(lead: .five)
        let reminder = Fix.reminder(start: -30, stop: 30)
        #expect(schedule.due([reminder], delivery: ReminderDelivery(), now: Fix.now) == [reminder])
        #expect(schedule.due([reminder], delivery: ReminderDelivery(), now: Fix.at(31)).isEmpty)
    }

    @Test("programme-reminders/remove-a-reminder-anywhere: a removed reminder is not scheduled and its state goes")
    func removed() {
        let schedule = ReminderSchedule(lead: .five)
        let plan = schedule.notifications(for: [Fix.reminder()], delivery: ReminderDelivery(), now: Fix.now)
        let after = schedule.notifications(for: [], delivery: plan.delivery.pruned(keeping: []), now: Fix.now)
        #expect(after.notifications.isEmpty)
        #expect(after.delivery == ReminderDelivery())
    }
}

@Suite struct ReminderTextTests {
    typealias Fix = ReminderFixture
    var text: ReminderText {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return ReminderText(calendar: calendar, locale: Locale(identifier: "en_GB"))
    }

    @Test("programme-reminders/a-notification-before-the-programme-starts: Starts at, or Starts now at start")
    func notification() {
        #expect(text.notificationBody(Fix.reminder(), lead: .five) == "Starts at 10:00 on Sport One")
        #expect(text.notificationBody(Fix.reminder(), lead: .atStart) == "Starts now on Sport One")
    }

    @Test("programme-reminders/a-banner-while-antenna-is-open: the banner's lines")
    func banner() {
        #expect(text.bannerEyebrow(Fix.reminder(), now: Fix.at(115)) == "Starts in 5 min")
        #expect(text.bannerEyebrow(Fix.reminder(), now: Fix.at(119.5)) == "Starts now")
        #expect(text.bannerEyebrow(Fix.reminder(), now: Fix.at(130)) == "On now")
        #expect(text.bannerBody(Fix.reminder(), number: 104) == "10:00 · 104 Sport One")
        #expect(text.bannerBody(Fix.reminder(), number: nil) == "10:00 · Sport One")
    }

    @Test("programme-reminders/see-every-upcoming-reminder-in-one-list: row lines and notes")
    func rows() {
        #expect(text.rowDetail(Fix.reminder(), now: Fix.now) == "Today 10:00 – 11:15 · Sport One")
        #expect(text.rowDetail(Fix.reminder(start: 24 * 60, stop: nil), now: Fix.now) == "Tomorrow 08:00 · Sport One")
        #expect(text.rowDetail(Fix.reminder(start: 3 * 24 * 60, stop: nil), now: Fix.now) == "Mon 08:00 · Sport One")
        #expect(text.rowStatus(Fix.reminder(movedFrom: 60)) == "Moved from 09:00")
        #expect(text.rowStatus(Fix.reminder(movedFrom: 60 - 24 * 60)) == "Moved from Thu 09:00")
        #expect(text.rowStatus(Fix.reminder(notListed: true)) == "No longer in the guide")
        #expect(text.rowStatus(Fix.reminder()) == nil)
        #expect(ReminderText.count(0) == nil)
        #expect(ReminderText.count(4) == "4")
    }
}
