#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation

    /// A direction on the remote.
    enum GuideMove: Equatable {
        case up, down, left, right
    }

    /// Where the guide grid is and what it highlights (tv-guide-grid
    /// capability, focus rules in the change's design.md). The window moves in
    /// whole columns; the highlight is a row and a time inside one of its cells.
    @MainActor @Observable
    final class GuideModel {
        /// Which part of the guide has focus.
        enum Area: Equatable {
            case grid, days, watch
        }

        /// A row and a time inside its highlighted cell.
        struct Highlight: Equatable {
            var row: Int
            var at: Date
        }

        /// What select or Watch asks the shell to do.
        enum Selection: Equatable {
            /// Tune this row's channel full screen.
            case tune(RowKey)
            /// Focus moves to Watch.
            case watch
            case nothing
        }

        static let visibleRows = 7

        private(set) var windowStart = Date.distantPast
        private(set) var rowWindow = GuideRowWindow(capacity: visibleRows)
        private(set) var highlight: Highlight?
        private(set) var area: Area = .grid
        /// The highlight and window when focus went up to the day chips.
        @ObservationIgnored private var leftForDays: (highlight: Highlight?, windowStart: Date)?

        // MARK: Opening

        /// Opens around `now` with the highlight on the cell covering now in
        /// the playing channel's row, or the first row when the group does not
        /// hold it (tv-guide-grid/it-opens-on-what-is-on-now). An empty group
        /// puts focus on the day chips (tv-guide-grid/an-empty-group).
        func open(_ data: GuideData, playing: RowKey?, now: Date) {
            windowStart = data.timeline.opening(at: now)
            guard !data.rows.isEmpty else {
                highlight = nil
                area = .days
                return
            }
            let row = playing.flatMap(data.rows.firstIndex(of:)) ?? 0
            rowWindow = GuideRowWindow(capacity: Self.visibleRows).showing(row)
            highlight = Highlight(row: row, at: clamped(now, data))
            area = .grid
        }

        /// Opens on the programme starting at `start` in `row`, with the half
        /// hour around its start in view (tv-guide-grid/open-at-a-programme-found-in-search).
        func open(_ data: GuideData, row: Int, start: Date) {
            windowStart = data.timeline.start(showing: start)
            rowWindow = GuideRowWindow(capacity: Self.visibleRows).showing(row)
            highlight = Highlight(row: row, at: clamped(start, data))
            area = .grid
        }

        /// Keeps the window inside the guide after the Guide window
        /// preference changed its length. A shorter window that would lose
        /// the highlight moves right until the highlighted half hour is its
        /// last column.
        func fit(_ data: GuideData) {
            guard windowStart != .distantPast else { return }
            let timeline = data.timeline
            windowStart = timeline.clamp(windowStart)
            guard let highlight else { return }
            if highlight.at >= window(data).end {
                let last = timeline.halfHour(atOrBefore: highlight.at)
                windowStart = timeline.clamp(last.addingTimeInterval(GuideTimeline.column - timeline.windowLength))
            }
            self.highlight = Highlight(row: highlight.row, at: clamped(highlight.at, data))
        }

        // MARK: Reading

        func window(_ data: GuideData) -> DateInterval {
            data.timeline.window(from: windowStart)
        }

        /// The highlighted row's index, kept inside the group.
        func highlightedRow(_ data: GuideData) -> Int? {
            guard let highlight, !data.rows.isEmpty else { return nil }
            return min(highlight.row, data.rows.count - 1)
        }

        /// The highlighted cell, read again from the guide so it follows the clock.
        func highlightedCell(_ data: GuideData) -> GuideCell? {
            guard let row = highlightedRow(data), let highlight else { return nil }
            return cell(in: data.cells(row, window(data)), at: clamped(highlight.at, data))
        }

        /// The day chip for the window: today, or the day the window has scrolled to.
        func selectedDay(_ data: GuideData, now: Date) -> Int {
            data.timeline.dayIndex(of: windowStart, in: data.timeline.days(at: now))
        }

        // MARK: Moving in the grid

        /// A press on the remote while the grid has focus. Up from the first
        /// row goes to the day chips.
        func move(_ direction: GuideMove, _ data: GuideData) {
            guard area == .grid, let row = highlightedRow(data), let current = highlightedCell(data) else { return }
            switch direction {
            case .up where row == 0:
                leftForDays = (highlight, windowStart)
                area = .days
            case .up:
                moveRow(from: current, to: row - 1, data)
            case .down:
                if row + 1 < data.rows.count { moveRow(from: current, to: row + 1, data) }
            case .left:
                moveLeft(from: current, in: row, data)
            case .right:
                moveRight(from: current, in: row, data)
            }
        }

        /// Up or down lands on the cell holding the highlighted cell's start,
        /// kept inside the window, and scrolls that row into view.
        private func moveRow(from current: GuideCell, to row: Int, _ data: GuideData) {
            let anchor = clamped(current.start, data)
            highlight = Highlight(row: row, at: anchor)
            rowWindow = rowWindow.showing(row)
        }

        /// Left from a cell cut by the window's left edge scrolls back one
        /// column; otherwise the cell before it takes the highlight.
        private func moveLeft(from current: GuideCell, in row: Int, _ data: GuideData) {
            let window = window(data)
            guard current.start > window.start else {
                windowStart = data.timeline.moving(windowStart, by: -1)
                highlight = Highlight(row: row, at: max(current.start, windowStart))
                return
            }
            let cells = data.cells(row, window)
            guard let index = cells.firstIndex(of: current), index > 0 else { return }
            highlight = Highlight(row: row, at: clamped(cells[index - 1].start, data))
        }

        /// Right to a cell outside the window scrolls so its start column is
        /// first. With no cell after this one the window moves one column.
        private func moveRight(from current: GuideCell, in row: Int, _ data: GuideData) {
            let window = window(data)
            let cells = data.cells(row, window)
            guard let index = cells.firstIndex(of: current), index + 1 < cells.count else {
                windowStart = data.timeline.moving(windowStart, by: 1)
                return
            }
            let next = cells[index + 1]
            if next.start >= window.end {
                let moved = data.timeline.clamp(data.timeline.halfHour(atOrBefore: next.start))
                guard moved > windowStart else { return }
                windowStart = moved
            }
            highlight = Highlight(row: row, at: next.start)
        }

        // MARK: Day chips

        /// Picks a day: the window moves to the same time of day on it
        /// (tv-guide-grid/pick-a-day).
        func pick(day index: Int, _ data: GuideData, now: Date) {
            let days = data.timeline.days(at: now)
            guard days.indices.contains(index) else { return }
            windowStart = data.timeline.start(windowStart, movedTo: days[index])
        }

        /// Down from a chip: back to the cell focus came from when the window
        /// has not moved, else the cell at the window's start in that row.
        /// An empty group keeps focus on the chips.
        func leaveDays(_ data: GuideData) {
            guard !data.rows.isEmpty else { return }
            if let leftForDays, leftForDays.windowStart == windowStart, let previous = leftForDays.highlight {
                highlight = previous
            } else {
                let row = min(leftForDays?.highlight?.row ?? highlight?.row ?? 0, data.rows.count - 1)
                highlight = Highlight(row: row, at: windowStart)
                rowWindow = rowWindow.showing(row)
            }
            area = .grid
        }

        /// Up from a chip, or right from the last one.
        func toWatch() {
            area = .watch
        }

        /// Focus moved onto a chip some other way, as when the group is empty.
        func focusedDays() {
            if area != .days { leftForDays = (highlight, windowStart) }
            area = .days
        }

        // MARK: Select and Watch

        /// Select in the grid: a programme on now tunes, anything else moves
        /// focus to Watch (tv-guide-grid/select-on-a-programme-that-is-on-now,
        /// tv-guide-grid/select-on-anything-else-goes-to-watch).
        func select(_ data: GuideData, now: Date) -> Selection {
            guard let cell = highlightedCell(data), let row = highlightedRow(data) else { return .nothing }
            if cell.programme != nil, cell.segment.contains(now) { return .tune(data.rows[row]) }
            area = .watch
            return .watch
        }

        /// Watch tunes the highlighted row's channel.
        func watch(_ data: GuideData) -> Selection {
            guard let row = highlightedRow(data) else { return .nothing }
            return .tune(data.rows[row])
        }

        /// Menu or down on Watch: back to the cell it came from.
        func leaveWatch(_ data: GuideData) {
            area = data.rows.isEmpty ? .days : .grid
        }

        // MARK: Helpers

        /// `date` kept inside the window.
        private func clamped(_ date: Date, _ data: GuideData) -> Date {
            let window = window(data)
            return min(max(date, window.start), window.end.addingTimeInterval(-1))
        }

        private func cell(in cells: [GuideCell], at date: Date) -> GuideCell? {
            cells.first { $0.segment.contains(date) } ?? cells.last { $0.start <= date } ?? cells.first
        }
    }
#endif
