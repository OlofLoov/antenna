import AntennaCore
import Foundation

/// One stretch of a guide row as the grid draws and navigates it: a
/// programme, a gap, or the placeholder that stands for the whole row.
struct GuideCell: Equatable {
    var segment: GuideSegment
    /// Set when the row has no programmes to show; the segment is then the window.
    var placeholder: GuidePlaceholder?

    var start: Date { segment.start }
    var stop: Date { segment.stop }
    var programme: Programme? { segment.programme }

    /// How far either side of the window a row's programmes are read, so
    /// the gap before the first one starts at the previous stop.
    static let reach: TimeInterval = 24 * 3600

    /// A row's cells around `window`: the placeholder for a guide that is
    /// loading, failed or has nothing in the window
    /// (tv-guide-grid/channels-without-a-guide-say-so), else its
    /// programmes and the gaps between them, from `bounds.start` or a day
    /// before the window, whichever is later.
    static func cells(
        state: GuideLoadingState, programmes: [Programme], window: DateInterval, bounds: DateInterval
    ) -> [GuideCell] {
        if let placeholder = GuidePlaceholder(state: state) {
            return [GuideCell(segment: GuideSegment(start: window.start, stop: window.end), placeholder: placeholder)]
        }
        let floor = max(bounds.start, window.start.addingTimeInterval(-reach))
        let ceiling = min(bounds.end, window.end.addingTimeInterval(reach))
        let segments = GuideRowLayout.segments(programmes, from: floor, to: max(ceiling, floor))
        let inView = segments.contains { $0.programme != nil && $0.stop > window.start && $0.start < window.end }
        guard inView else {
            return [GuideCell(segment: GuideSegment(start: window.start, stop: window.end), placeholder: .noGuide)]
        }
        return segments.map { GuideCell(segment: $0) }
    }
}

/// What the guide grid reads: the time axis, the current group's rows in
/// channel-list order, and each row's cells around a window. The screen
/// builds it from the catalogue and the guide; tests build it from fixtures.
struct GuideData {
    let timeline: GuideTimeline
    let rows: [RowKey]
    let cells: (RowKey, DateInterval) -> [GuideCell]

    /// `row`'s cells around `window`, empty for a row that is not there.
    func cells(_ row: Int, _ window: DateInterval) -> [GuideCell] {
        rows.indices.contains(row) ? cells(rows[row], window) : []
    }

    /// The app's data: `rows` with `guide`'s programmes, in the user's time zone.
    @MainActor
    static func live(rows: [RowKey], channel: @escaping (RowKey) -> Channel?, guide: OverlayGuide, now: Date) -> GuideData {
        let timeline = GuideTimeline(horizon: guide.horizon(), now: now, calendar: .autoupdatingCurrent)
        return GuideData(timeline: timeline, rows: rows) { key, window in
            guard let channel = channel(key) else { return [] }
            let reach = DateInterval(
                start: window.start.addingTimeInterval(-GuideCell.reach), end: window.end.addingTimeInterval(GuideCell.reach))
            return GuideCell.cells(
                state: guide.state(channel), programmes: guide.programmes(channel, reach), window: window, bounds: timeline.bounds)
        }
    }
}
