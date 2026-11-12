import Foundation

/// The words reminders show, in the user's calendar, time zone and locale,
/// which tests pass in.
public struct ReminderText: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    public init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    public static let remindMe = "Remind me"
    public static let reminderSet = "Reminder set"
    public static let notListed = "No longer in the guide"
    public static let empty = "No reminders"
    public static let emptyHint = "Choose Remind me on a programme that has not started, in the Guide or in Search."
    public static let syncNote =
        "Reminders sync to your other devices through iCloud. Each device reminds you in its own way: "
        + "a notification on iPhone, iPad and Mac, a banner on Apple TV while Antenna is open."
    public static let cannotNotify = "Notifications are off for Antenna. Reminders show only while the app is open."
    public static let notAskedYet = "Antenna has not asked to send notifications. Reminders show only while the app is open."
    public static let television = "Apple TV cannot show notifications. Reminders show as a banner while Antenna is open."

    /// The notification's body (programme-reminders/a-notification-before-the-programme-starts):
    /// "Starts at 22:00 on Sport One", or "Starts now on Sport One" when reminding at start.
    public func notificationBody(_ reminder: Reminder, lead: ReminderLeadTime) -> String {
        lead == .atStart ? "Starts now on \(reminder.channelName)" : "Starts at \(time(reminder.start)) on \(reminder.channelName)"
    }

    /// The banner's top line: "Starts in 5 min", "Starts now" within the
    /// minute, or "On now" once it has started.
    public func bannerEyebrow(_ reminder: Reminder, now: Date) -> String {
        let seconds = reminder.start.timeIntervalSince(now)
        if seconds <= -60 { return "On now" }
        if seconds < 60 { return "Starts now" }
        return "Starts in \(GuidePanelText.length(from: now, to: reminder.start))"
    }

    /// The banner's body: "22:00 · 104 Sport One", with the number when the channel has one.
    public func bannerBody(_ reminder: Reminder, number: ChannelNumber?) -> String {
        let channel = [number.map(\.description), reminder.channelName].compactMap(\.self).joined(separator: " ")
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
        if reminder.notListed { return Self.notListed }
        guard let from = reminder.movedFrom else { return nil }
        if calendar.isDate(from, inSameDayAs: reminder.start) { return "Moved from \(time(from))" }
        return "Moved from \(format(from, template: "EEE")) \(time(from))"
    }

    /// The Settings row's count: nil at zero.
    public static func count(_ upcoming: Int) -> String? {
        upcoming == 0 ? nil : "\(upcoming)"
    }

    /// "Today", "Tomorrow", the short weekday within a week, else the short date.
    public func day(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        return format(date, template: days < 7 ? "EEE" : "EEEdMMM")
    }

    /// A time of day in the locale's style, "21:00" or "9:00 PM".
    public func time(_ date: Date) -> String {
        format(date, template: "jmm")
    }

    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
