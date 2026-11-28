import Foundation

/// Which posters to load before they come into view
/// (movies-and-series-browsing/browsing-stays-responsive). When a poster
/// shows, the next few in the direction the row is moving load; when a row
/// shows, the posters the next rows in the direction of the scroll show
/// first load. On Apple TV the rows by the highlight load the posters
/// around its column, two rows ahead of a move up or down and one behind.
/// The window fits the poster memory next to the posters on screen.
public enum PosterPrefetch {
    /// Posters loaded ahead of the last one shown in a row.
    public static let along = 6
    /// Rows past a row that shows, in the direction of the scroll, whose
    /// first posters load.
    public static let rowsAhead = 2
    /// Rows by the Apple TV highlight that load the posters around its
    /// column: ahead of the last move up or down, and behind it.
    public static let highlightRowsAhead = 2
    public static let highlightRowsBehind = 1

    /// The way a row is scrolling.
    public enum Direction: Sendable {
        case forward, backward
    }

    /// The positions in a row of `count` posters to load once the poster at
    /// `index` shows: the next `along` in the direction of travel, never
    /// past either end. Empty for a position outside the row.
    public static func ahead(of index: Int, count: Int, going direction: Direction = .forward, along: Int = along) -> Range<Int> {
        guard index >= 0, index < count, along > 0 else { return 0..<0 }
        switch direction {
        case .forward: return (index + 1)..<min(count, index + 1 + along)
        case .backward: return max(0, index - along)..<index
        }
    }

    /// How many posters of `poster` points, `gap` apart after a leading
    /// `gutter`, a row `width` points wide shows, the last one cut or not.
    /// At least one.
    public static func visible(width: Double, poster: Double, gap: Double, gutter: Double) -> Int {
        guard width > gutter, poster + gap > 0 else { return 1 }
        return max(1, Int(((width - gutter) / (poster + gap)).rounded(.up)))
    }

    /// The first `visible` positions of a row of `count` posters.
    public static func start(count: Int, visible: Int) -> Range<Int> {
        0..<max(0, min(count, visible))
    }

    /// The `visible` positions of a row of `count` posters around `column`,
    /// half before it and half after: what a row shows once it scrolls
    /// sideways to the Apple TV highlight at that column. The row's start
    /// without a column, or while the column is within the first screen.
    public static func around(_ column: Int?, count: Int, visible: Int) -> Range<Int> {
        guard let column, visible > 0 else { return start(count: count, visible: visible) }
        let first = max(0, min(column - visible / 2, count - visible))
        return first..<max(first, min(count, first + visible))
    }

    /// The way the Apple TV highlight last moved between rows.
    public enum Vertical: Sendable {
        case down, up
    }

    /// Posters of one row to load: the row's position and the posters in it.
    public struct Span: Equatable, Sendable {
        public let row: Int
        public let columns: Range<Int>

        public init(row: Int, columns: Range<Int>) {
            self.row = row
            self.columns = columns
        }
    }

    /// What the rows by the Apple TV highlight load while it rests on
    /// `column` of `row`, among rows of `counts` posters: the `visible`
    /// posters around the column in the `ahead` rows past it in the
    /// direction it last moved and the `behind` rows on the other side,
    /// nearest first, ahead before behind at the same distance. Not its own
    /// row, which loads along as it scrolls, and never past the first or
    /// last row.
    public static func aroundHighlight(
        row: Int, column: Int, counts: [Int], visible: Int, going vertical: Vertical = .down,
        ahead: Int = highlightRowsAhead, behind: Int = highlightRowsBehind
    ) -> [Span] {
        guard counts.indices.contains(row) else { return [] }
        let step = vertical == .down ? 1 : -1
        var rows: [Int] = []
        for distance in 1...max(1, max(ahead, behind)) {
            if distance <= ahead { rows.append(row + step * distance) }
            if distance <= behind { rows.append(row - step * distance) }
        }
        return rows.filter { counts.indices.contains($0) }.compactMap { neighbor in
            let columns = around(column, count: counts[neighbor], visible: visible)
            return columns.isEmpty ? nil : Span(row: neighbor, columns: columns)
        }
    }

    /// The last poster each row showed, or the last row a section showed,
    /// to tell which way it is moving. A row seen again after scrolling
    /// away starts afresh.
    ///
    /// A row that comes into view shows its first posters all at once.
    /// Those are not a scroll along the row, so for `settle` after a row's
    /// first poster shows, its posters load nothing ahead. Walking down and
    /// up the rows, those loads were never shown and pushed the posters
    /// about to show out of memory.
    public struct Trail: Sendable {
        /// How long a row that came into view loads nothing along it.
        public static let settle = Duration.milliseconds(500)

        private var last: [String: Int] = [:]
        private var arrived: [String: ContinuousClock.Instant] = [:]
        private var vertical: [String: Vertical] = [:]

        public init() {}

        /// The positions to load once the poster or row at `index` of
        /// `line` shows: the next `along`, forward unless it is before the
        /// one shown last. With `time`, nothing while the line is within
        /// `settle` of its first poster showing.
        public mutating func shown(
            _ index: Int, in line: String, count: Int, along: Int = PosterPrefetch.along, at time: ContinuousClock.Instant? = nil
        ) -> Range<Int> {
            let previous = last[line]
            last[line] = index
            if let time {
                if previous == nil { arrived[line] = time }
                if let start = arrived[line], time - start < Self.settle { return 0..<0 }
            }
            let direction: Direction = previous.map { index < $0 ? .backward : .forward } ?? .forward
            return PosterPrefetch.ahead(of: index, count: count, going: direction, along: along)
        }

        /// The way the highlight moved to `row` of `line`: up when the row
        /// is above the last one, down when below, and the way it last
        /// moved while it stays in the row. Down at first.
        public mutating func highlight(in row: Int, of line: String) -> Vertical {
            let previous = last[line]
            last[line] = row
            if let previous, previous != row { vertical[line] = row < previous ? .up : .down }
            return vertical[line] ?? .down
        }

        /// Forgets a row that scrolled away.
        public mutating func forget(_ line: String) {
            last[line] = nil
            arrived[line] = nil
            vertical[line] = nil
        }

        /// True while `line` is remembered, for tests: only rows on screen are.
        public func remembers(_ line: String) -> Bool { last[line] != nil }
    }
}
