import Foundation

/// The day list along the top of the Apple TV guide grid
/// (tv-guide-grid/pick-a-day): today and each later calendar day the guide
/// reaches, in the timeline's time zone.
extension GuideTimeline {
    /// The start of today and of each later day that begins before the
    /// bounds end. Always holds today, also when the guide ends earlier.
    public func days(at now: Date) -> [Date] {
        let today = calendar.startOfDay(for: now)
        var days = [today]
        while let last = days.last, let next = calendar.date(byAdding: .day, value: 1, to: last), next < bounds.end {
            days.append(next)
        }
        return days
    }

    /// The day the window starting at `start` belongs to, as an index into
    /// `days`. Follows the window past midnight; before today it is today.
    public func dayIndex(of start: Date, in days: [Date]) -> Int {
        let day = calendar.startOfDay(for: start)
        return days.lastIndex { $0 <= day } ?? 0
    }

    /// The window start at the same local time as `start` on `day`, kept
    /// inside the bounds. A time the day does not have, as in a spring
    /// daylight saving change, moves to the next valid time.
    public func start(_ start: Date, movedTo day: Date) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: start)
        let moved =
            calendar.date(
                bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day,
                matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? day
        return clamp(moved)
    }

    /// "Today" for today, else the short weekday, "Tue". A day a week or
    /// more ahead adds its date, "Tue 18", so no two chips read the same.
    public func dayLabel(_ day: Date, today: Date, locale: Locale = .current) -> String {
        let start = calendar.startOfDay(for: today)
        guard day > start else { return "Today" }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated)
        let distance = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        if distance >= 7 { style = style.day() }
        return day.formatted(style)
    }
}
