import Foundation

/// Which rows of the guide grid are drawn. Only the rows on screen plus one
/// below are built, so a group of 20 000 channels costs the same as one of
/// ten (tv-guide-grid/one-row-per-channel-in-the-current-group).
public struct GuideRowWindow: Sendable, Equatable {
    /// The index of the top row on screen.
    public var first: Int
    /// How many whole rows fit on screen, at least one.
    public var capacity: Int

    public init(first: Int = 0, capacity: Int) {
        self.first = max(0, first)
        self.capacity = max(1, capacity)
    }

    /// The rows to build out of `count`: the ones on screen and one more,
    /// which shows cut off at the bottom.
    public func drawn(of count: Int) -> Range<Int> {
        let start = min(first, max(0, count - 1))
        return start..<min(count, start + capacity + 1)
    }

    /// Scrolled just enough to show `row` whole. A row already in view
    /// leaves the window where it is.
    public func showing(_ row: Int) -> GuideRowWindow {
        var moved = self
        if row < first {
            moved.first = max(0, row)
        } else if row >= first + capacity {
            moved.first = row - capacity + 1
        }
        return moved
    }
}
