import Foundation

/// Which posters to load before they come into view
/// (movies-and-series-browsing/browsing-stays-responsive). When a poster
/// shows, the next ones along its row load; when a row shows, the first
/// posters of the rows under it load. Holds no state: the caller passes
/// what has just shown.
public enum PosterPrefetch {
    /// Posters loaded ahead of the last one shown in a row.
    public static let along = 8
    /// Rows under a row that shows whose first posters load.
    public static let rowsBelow = 2
    /// Posters loaded at the start of each of those rows.
    public static let rowStart = 8

    /// The positions in a row of `count` posters to load once the poster at
    /// `index` shows: the next `along`, never past the row's end. Empty for
    /// a position outside the row.
    public static func ahead(of index: Int, count: Int, along: Int = along) -> Range<Int> {
        guard index >= 0, index < count, along > 0 else { return 0..<0 }
        return (index + 1)..<min(count, index + 1 + along)
    }

    /// The positions of the rows to load the start of once the row at
    /// `row` shows, in a section of `rowCount` rows: the next `rowsBelow`.
    public static func below(row: Int, rowCount: Int, rowsBelow: Int = rowsBelow) -> Range<Int> {
        guard row >= 0, row < rowCount, rowsBelow > 0 else { return 0..<0 }
        return (row + 1)..<min(rowCount, row + 1 + rowsBelow)
    }

    /// The first `rowStart` positions of a row of `count` posters.
    public static func start(count: Int, rowStart: Int = rowStart) -> Range<Int> {
        0..<max(0, min(count, rowStart))
    }
}
