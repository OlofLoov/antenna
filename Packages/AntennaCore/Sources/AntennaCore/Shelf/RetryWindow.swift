import Foundation

/// Lets one retry through per key in each window, such as fetching a whole
/// playlist again for a series its kept load lacks
/// (movies-and-series-browsing/browsing-stays-responsive).
public struct RetryWindow<Key: Hashable & Sendable>: Sendable {
    public let length: TimeInterval
    private var last: [Key: Date] = [:]

    public init(length: TimeInterval) {
        self.length = length
    }

    /// True, and the window starts, when `key` has had no retry in the
    /// `length` before `now`.
    public mutating func allows(_ key: Key, now: Date) -> Bool {
        if let since = last[key], now.timeIntervalSince(since) < length, now >= since { return false }
        last[key] = now
        return true
    }
}
