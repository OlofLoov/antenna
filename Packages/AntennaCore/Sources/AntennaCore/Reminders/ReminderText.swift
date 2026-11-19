import Foundation

/// The words reminders show, in the user's calendar, time zone and locale,
/// which tests pass in.
public struct ReminderText: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    var words: Words { Words(locale) }

    public init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    public static func remindMe(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Remind me")
    }
    public static func reminderSet(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Reminder set")
    }
    public static func notListed(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("No longer in the guide")
    }
    public static func empty(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("No reminders")
    }
    public static func emptyHint(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Choose Remind me on a programme that has not started, in the Guide or in Search.")
    }
    public static func syncNote(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)(
            """
            Reminders sync to your other devices through iCloud. Each device reminds \
            you in its own way: a notification on iPhone, iPad and Mac, a banner on \
            Apple TV while Antenna is open.
            """
        )
    }
    public static func cannotNotify(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Notifications are off for Antenna. Reminders show only while the app is open.")
    }
    public static func notAskedYet(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Antenna has not asked to send notifications. Reminders show only while the app is open.")
    }
    public static func television(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Apple TV cannot show notifications. Reminders show as a banner while Antenna is open.")
    }

    /// The notification's body (programme-reminders/a-notification-before-the-programme-starts):
    /// "Starts at 22:00 on Sport One", or "Starts now on Sport One" when reminding at start.
    public func notificationBody(_ reminder: Reminder, lead: ReminderLeadTime) -> String {
        lead == .atStart
            ? words("Starts now on \(words.source(reminder.channelName))")
            : words("Starts at \(time(reminder.start)) on \(words.source(reminder.channelName))")
    }

    /// The banner's top line: "Starts in 5 min", "Starts now" within the
    /// minute, or "On now" once it has started.
    public func bannerEyebrow(_ reminder: Reminder, now: Date) -> String {
        let seconds = reminder.start.timeIntervalSince(now)
        if seconds <= -60 { return words("On now") }
        if seconds < 60 { return words("Starts now") }
        return words("Starts in \(GuidePanelText.length(from: now, to: reminder.start, locale: locale))")
    }

    /// The banner's body: "22:00 · 104 Sport One", with the number when the channel has one.
    public func bannerBody(_ reminder: Reminder, number: ChannelNumber?) -> String {
        let channel = [number.map { $0.text(locale) }, reminder.channelName].compactMap(\.self).joined(separator: " ")
        return "\(time(reminder.start)) · \(channel)"
    }

    /// A list row's second line: "Today 22:00 – 23:15 · Sport One". With no
    /// stop the end time is left out.
    public func rowDetail(_ reminder: Reminder, now: Date) -> String {
        let times = reminder.stop.map { "\(time(reminder.start)) – \(time($0))" } ?? time(reminder.start)
        return "\(day(reminder.start, now: now)) \(times) · \(reminder.channelName)"
    }

    /// A list row's note: "Moved from 20:00" (with the day when it moved
    /// across days), "No longer in the guide", or nil.
    public func rowStatus(_ reminder: Reminder) -> String? {
        if reminder.notListed { return Self.notListed(locale) }
        guard let from = reminder.movedFrom else { return nil }
        if calendar.isDate(from, inSameDayAs: reminder.start) { return words("Moved from \(time(from))") }
        return words("Moved from \(format(from, .weekday)) \(time(from))")
    }

    /// The Settings row's count: nil at zero.
    public static func count(_ upcoming: Int) -> String? {
        upcoming == 0 ? nil : "\(upcoming)"
    }

    /// "Today", "Tomorrow", the short weekday within a week, else the short date.
    public func day(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return words("Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return words("Tomorrow")
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        return format(date, days < 7 ? .weekday : .weekdayAndDate)
    }

    /// A time of day in the locale's style, "21:00" or "9:00 PM".
    public func time(_ date: Date) -> String {
        format(date, .time)
    }

    private enum Shape { case weekday, longWeekday, weekdayAndDate, time }

    private func format(_ date: Date, _ shape: Shape) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return switch shape {
        case .weekday: date.formatted(style.weekday(.abbreviated))
        case .longWeekday: date.formatted(style.weekday(.wide))
        case .weekdayAndDate: date.formatted(style.weekday(.abbreviated).day().month(.abbreviated))
        case .time: date.formatted(style.hour().minute())
        }
    }
}
