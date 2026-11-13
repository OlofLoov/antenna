import Foundation

/// Moving from the playing channel to another without opening the list.
extension Catalogue {
    /// The channel `steps` places from `key` in `rows`, wrapping round at
    /// either end. Nil when `rows` does not hold `key`, or holds nothing else.
    public func neighbor(of key: RowKey, in rows: [RowKey], by steps: Int) -> Channel? {
        guard rows.count > 1, let index = rows.firstIndex(of: key) else { return nil }
        let next = ((index + steps) % rows.count + rows.count) % rows.count
        return channel(for: rows[next])
    }

    /// The most recent channel in Recents other than `key`, nil when Recents
    /// holds no other channel.
    public func mostRecent(otherThan key: RowKey?) -> Channel? {
        rows(in: .recents).first { $0 != key }.flatMap(channel(for:))
    }
}
