import Foundation

/// The time axis of the iPad and Mac guide, which scrolls freely across the
/// timeline's bounds instead of moving a two-hour window
/// (guide-on-iphone-ipad-and-mac capability). Columns are absolute half
/// hours from `bounds.start`, so a daylight saving change repeats or skips
/// an hour in the labels.
extension GuideTimeline {
    /// The grid opens half an hour back.
    public static let regularLookBack: TimeInterval = 30 * 60

    /// Where the grid's left edge goes when it opens at `now`: the half hour
    /// at or before half an hour ago, 21:00 at 21:34. When `visibleWidth`
    /// is too narrow to show the now line from there, the half hour at or
    /// before now. Never before the bounds.
    public func regularOpening(at now: Date, visibleWidth: Double, scale: GuideScale) -> Date {
        let back = halfHour(atOrBefore: now.addingTimeInterval(-Self.regularLookBack))
        let start = scale.offset(of: now, from: back) < visibleWidth ? back : halfHour(atOrBefore: now)
        return scrollClamp(start)
    }

    /// `date` kept inside the bounds.
    public func scrollClamp(_ date: Date) -> Date {
        min(max(date, bounds.start), bounds.end)
    }

    /// The same local time as `time` on `day`, kept inside the bounds. A time
    /// the day does not have, as in a spring daylight saving change, moves to
    /// the next minute that exists.
    public func time(_ time: Date, on day: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let moved =
            calendar.date(
                bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day,
                matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? day
        return scrollClamp(moved)
    }

    /// How wide the whole timeline is at `scale`.
    public func width(at scale: GuideScale) -> Double {
        scale.offset(of: bounds.end, from: bounds.start)
    }

    /// The half-hour column starts that overlap `interval`, within the bounds.
    public func columns(in interval: DateInterval) -> [Date] {
        let first = max(bounds.start, halfHourFromBounds(atOrBefore: interval.start))
        var columns: [Date] = []
        var column = first
        while column < interval.end, column < bounds.end {
            columns.append(column)
            column = column.addingTimeInterval(Self.column)
        }
        return columns
    }

    /// The column start at or before `date`, counted in whole half hours from
    /// `bounds.start`, so columns stay absolute across a clock change.
    private func halfHourFromBounds(atOrBefore date: Date) -> Date {
        let columns = (date.timeIntervalSince(bounds.start) / Self.column).rounded(.down)
        return bounds.start.addingTimeInterval(columns * Self.column)
    }
}

/// The part of the iPad and Mac grid to build: the rows and the stretch of
/// time on screen, plus one row and one column of slack each way, so only
/// what can be seen is laid out whatever the size of the group
/// (guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac).
public struct GuideViewport: Sendable, Equatable {
    public var rows: Range<Int>
    public var time: DateInterval

    public init(rows: Range<Int>, time: DateInterval) {
        self.rows = rows
        self.time = time
    }

    /// The viewport for a scroll offset of `x`, `y` with `width` by `height`
    /// of grid on screen, rows `rowPitch` apart. Rounded to whole rows and
    /// half hours, so it changes only when a row or column comes into view.
    public init(
        x: Double, y: Double, width: Double, height: Double, rowPitch: Double, rowCount: Int, timeline: GuideTimeline,
        scale: GuideScale
    ) {
        let pitch = max(rowPitch, 1)
        let firstRow = max(0, Int((y / pitch).rounded(.down)) - 1)
        let lastRow = min(rowCount, Int(((y + height) / pitch).rounded(.up)) + 1)
        rows = firstRow..<max(firstRow, lastRow)
        let columnWidth = max(scale.columnWidth, 1)
        let firstColumn = max(0, (x / columnWidth).rounded(.down) - 1)
        let lastColumn = ((x + width) / columnWidth).rounded(.up) + 1
        let origin = timeline.bounds.start
        let start = origin.addingTimeInterval(firstColumn * GuideTimeline.column)
        let end = min(timeline.bounds.end, origin.addingTimeInterval(lastColumn * GuideTimeline.column))
        time = DateInterval(start: min(start, end), end: end)
    }
}
