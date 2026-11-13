import Foundation

/// What this device remembers of one source's channels: when it first and
/// last saw each one (new-channels/what-new-remembers-stays-on-the-device).
/// Channels are kept as a 64-bit hash of their id, so the value holds no
/// link, login or channel id.
public struct SeenChannels: Sendable, Equatable, Codable {
    /// One channel's dates. `first` is `distantPast` for a channel of the
    /// source's first load on this device.
    public struct Entry: Sendable, Equatable, Codable {
        public var key: UInt64
        public var first: Date
        public var last: Date
    }

    /// A channel missing from the loads for this long is forgotten.
    public static let forgetAfter: TimeInterval = 30 * 86_400

    /// By hashed channel id.
    public private(set) var entries: [UInt64: Entry]

    /// A source's first load on this device: every channel counts as known
    /// (new-channels/a-new-source-starts-with-nothing-new).
    public init(firstLoad channelIDs: some Sequence<String>, now: Date) {
        entries = [:]
        for id in channelIDs {
            let key = Self.key(id)
            entries[key] = Entry(key: key, first: .distantPast, last: now)
        }
    }

    /// The memory after a load at `now` of `channelIDs`: channels not seen
    /// before take `now` as their first sighting, ones seen again keep
    /// theirs, and ones missing for 30 days are forgotten. With no memory
    /// the load counts as the first.
    public static func recording(_ previous: SeenChannels?, channelIDs: some Sequence<String>, now: Date) -> SeenChannels {
        guard var memory = previous else { return SeenChannels(firstLoad: channelIDs, now: now) }
        for id in channelIDs {
            let key = key(id)
            memory.entries[key] = Entry(key: key, first: memory.entries[key]?.first ?? now, last: now)
        }
        let cutoff = now.addingTimeInterval(-forgetAfter)
        memory.entries = memory.entries.filter { $0.value.last >= cutoff }
        return memory
    }

    /// When this device first saw the channel with `channelID`, nil when it
    /// never did.
    public func firstSeen(_ channelID: String) -> Date? {
        entries[Self.key(channelID)]?.first
    }

    /// FNV-1a over the id's UTF-8 bytes; the same on every launch and device.
    static func key(_ channelID: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in channelID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    private enum CodingKeys: String, CodingKey { case entries }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let list = try container.decode([Entry].self, forKey: .entries)
        entries = Dictionary(list.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries.values.sorted { $0.key < $1.key }, forKey: .entries)
    }
}

/// The New group of Live and the Apple TV overlay
/// (new-channels/a-new-group-lists-channels-added-lately).
public enum NewChannels {
    /// A channel stays new this many days after this device first saw it.
    public static let days = 7

    /// `catalogue` with its New group set: the channels whose source memory
    /// in `seen` first saw them in the last seven days, newest first, then
    /// in catalogue order. A channel is matched by its id, so a new name,
    /// group or number does not make it new. A source with no memory adds
    /// nothing.
    public static func group<Token>(_ catalogue: Catalogue<Token>, seen: [UUID: SeenChannels], now: Date) -> Catalogue<Token> {
        let since = now.addingTimeInterval(-Double(days) * 86_400)
        let index = catalogue.index
        var found: [(entry: Int, first: Date)] = []
        for (entry, key) in index.keys.enumerated() {
            guard let first = seen[key.sourceID]?.firstSeen(key.id), first >= since, first <= now else { continue }
            found.append((entry, first))
        }
        let ordered = found.sorted { lhs, rhs in
            lhs.first != rhs.first ? lhs.first > rhs.first : index.allRank[lhs.entry] < index.allRank[rhs.entry]
        }
        return catalogue.replacingNew(CatalogueRecents(ranked: ordered.map(\.entry), index: index))
    }
}
