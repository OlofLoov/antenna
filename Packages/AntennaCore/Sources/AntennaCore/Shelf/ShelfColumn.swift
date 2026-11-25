import Foundation

/// The column the Apple TV highlight keeps on a move up or down between
/// rows of posters
/// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
/// The focus engine picks the poster under the middle of the expanded
/// card, one to the right of the poster it grew from, so each move would
/// drift a poster to the right. The highlight lands instead on the poster
/// at the same position in the row it moves into, or on that row's last
/// poster when it is shorter.
public enum ShelfColumn {
    /// The position in a row of `count` posters to move the highlight to,
    /// after it left position `from` in another row and the focus engine
    /// put it on `landed`. Nil when it is already there.
    public static func target(from: Int, landed: Int, count: Int) -> Int? {
        guard count > 0, from >= 0 else { return nil }
        let target = min(from, count - 1)
        return target == landed ? nil : target
    }

    /// The position in a row of `count` posters that a move up or down
    /// lands on, with the highlight at `column` in the row it leaves. Nil
    /// for an empty row.
    public static func landing(column: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(max(0, column), count - 1)
    }

    /// The row between `from` and `to` in `order`, the section's rows top
    /// to bottom, when a move went two rows at once. The focus engine does
    /// that when nothing in the row it passed sits under the highlight, as
    /// when a second press comes before the highlight is back in its column
    /// and the row passed is short. Nil for a move to the next row.
    public static func skipped(_ order: [String], from: String, to: String) -> String? {
        guard let start = order.firstIndex(of: from), let end = order.firstIndex(of: to), abs(end - start) == 2 else {
            return nil
        }
        return order[(start + end) / 2]
    }
}
