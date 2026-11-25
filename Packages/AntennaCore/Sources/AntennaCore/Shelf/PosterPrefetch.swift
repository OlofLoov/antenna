import Foundation

/// Which posters to load before they come into view
/// (movies-and-series-browsing/browsing-stays-responsive). When a poster
/// shows, the next few in the direction the row is moving load; when a row
/// shows, the posters the next row in the direction of the scroll shows
/// first load. The window is small so it fits the poster memory next to
/// the posters on screen.
public enum PosterPrefetch {
    /// Posters loaded ahead of the last one shown in a row.
    public static let along = 3
    /// Rows past a row that shows, in the direction of the scroll, whose
    /// first posters load.
    public static let rowsAhead = 1

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

        /// Forgets a row that scrolled away.
        public mutating func forget(_ line: String) {
            last[line] = nil
            arrived[line] = nil
        }

        /// True while `line` is remembered, for tests: only rows on screen are.
        public func remembers(_ line: String) -> Bool { last[line] != nil }
    }
}
