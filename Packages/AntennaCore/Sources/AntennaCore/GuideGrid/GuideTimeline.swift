import Foundation

/// The time axis of the Apple TV guide grid (tv-guide-grid capability):
/// half-hour columns 370 pt wide, four of them on screen, between bounds set
/// by the guide's horizon. Every answer is in `calendar`'s time zone, so a
/// test fixes both the clock and the zone.
public struct GuideTimeline: Sendable {
    /// One column covers half an hour.
    public static let column: TimeInterval = 30 * 60
    public static let columnWidth = GuideScale.television.columnWidth
    public static let visibleColumns = 4
    /// What the window shows: two hours.
    public static let windowLength = column * Double(visibleColumns)
    /// The grid opens with this much of the past in view.
    public static let lookBack: TimeInterval = 90 * 60

    public let calendar: Calendar
    /// The first column's start can be no earlier than `bounds.start`.
    /// The last column on screen starts strictly before `bounds.end`.
    public let bounds: DateInterval

    /// Bounds from the half hour at or before the horizon's start to its
    /// end. With no horizon, today from 00:00 to the next midnight.
    public init(horizon: DateInterval?, now: Date, calendar: Calendar) {
        self.calendar = calendar
        if let horizon {
            let start = Self.halfHour(atOrBefore: horizon.start, in: calendar)
            bounds = DateInterval(start: start, end: max(horizon.end, start.addingTimeInterval(Self.column)))
        } else {
            let today = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
            bounds = DateInterval(start: today, end: tomorrow)
        }
    }

    /// The start of the local half hour holding `date`: 21:34 gives 21:30.
    public func halfHour(atOrBefore date: Date) -> Date {
        Self.halfHour(atOrBefore: date, in: calendar)
    }

    static func halfHour(atOrBefore date: Date, in calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        let minutes = Double((parts.minute ?? 0) % 30) * 60
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
        return date.addingTimeInterval(-(minutes + seconds))
    }

    /// The latest first column the bounds allow: four columns back from the
    /// last one that starts before the end, or the bounds' start.
    public var latestStart: Date {
        let last = halfHour(atOrBefore: bounds.end.addingTimeInterval(-1))
        let latest = last.addingTimeInterval(-Self.column * Double(Self.visibleColumns - 1))
        return max(bounds.start, latest)
    }

    /// `start` moved inside the bounds.
    public func clamp(_ start: Date) -> Date {
        min(max(start, bounds.start), latestStart)
    }

    /// The first column when the guide opens at `now`: the half hour at or
    /// before 90 minutes ago, 20:00 at 21:34
    /// (tv-guide-grid/the-grid-opens-around-now-and-keeps-time).
    public func opening(at now: Date) -> Date {
        clamp(halfHour(atOrBefore: now.addingTimeInterval(-Self.lookBack)))
    }

    /// The first column that puts the half hour around `date` in view, for
    /// a programme picked in Search (tv-guide-grid/open-at-a-programme-found-in-search).
    public func start(showing date: Date) -> Date {
        clamp(halfHour(atOrBefore: date))
    }

    /// The window's first column moved by `columns`, kept inside the bounds.
    public func moving(_ start: Date, by columns: Int) -> Date {
        clamp(start.addingTimeInterval(Self.column * Double(columns)))
    }

    /// The two hours on screen from `start`.
    public func window(from start: Date) -> DateInterval {
        DateInterval(start: start, duration: Self.windowLength)
    }

    /// The four column starts from `start`. Across a daylight saving change
    /// their local times repeat or skip an hour.
    public func columns(from start: Date) -> [Date] {
        (0..<Self.visibleColumns).map { start.addingTimeInterval(Self.column * Double($0)) }
    }

    /// Points from the window's left edge to `date`, at 370 pt per half hour.
    public static func offset(of date: Date, from start: Date) -> Double {
        GuideScale.television.offset(of: date, from: start)
    }

    /// Where the now line goes, in points from the window's left edge, or
    /// nil when now is out of view.
    public func nowLine(at now: Date, windowStart start: Date) -> Double? {
        guard now >= start, now < start.addingTimeInterval(Self.windowLength) else { return nil }
        return Self.offset(of: now, from: start)
    }
}
