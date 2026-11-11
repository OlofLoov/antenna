import Foundation

/// The channels watched lately on this device, newest first, each once,
/// at most `limit` (session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once).
public struct RecentChannels: Hashable, Sendable {
    public static let limit = 20

    /// Newest first.
    public private(set) var entries: [LastChannelKey]

    /// Keeps the first occurrence of each channel, drops ids that hold a
    /// stream link and everything past `limit`.
    public init(_ entries: [LastChannelKey] = []) {
        var seen: Set<LastChannelKey> = []
        self.entries = Array(entries.filter { LastChannelKey.canStore($0.channelID) && seen.insert($0).inserted }.prefix(Self.limit))
    }

    /// Puts `key` on top. A channel already listed moves up; the oldest
    /// falls off past `limit`. An id holding a stream link changes nothing.
    public mutating func record(_ key: LastChannelKey) {
        guard LastChannelKey.canStore(key.channelID) else { return }
        entries.removeAll { $0 == key }
        entries.insert(key, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }

    /// Drops every channel of `source`
    /// (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
    public mutating func remove(source: UUID) {
        entries.removeAll { $0.sourceID == source }
    }

    /// The list stored as `data`; empty when `data` is nil or cannot be read.
    public init(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode([LastChannelKey].self, from: data) else {
            self.init()
            return
        }
        self.init(decoded)
    }

    /// The JSON array of entries, newest first.
    public var data: Data? {
        try? JSONEncoder().encode(entries)
    }
}
