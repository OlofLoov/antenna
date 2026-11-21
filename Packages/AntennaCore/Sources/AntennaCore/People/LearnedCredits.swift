import Foundation

/// The names from every info answer the app received, so person pages list
/// those titles after a restart (browse-by-person/names-the-provider-sent-are-kept).
/// Kept for 30 days, at most 20,000 titles, oldest dropped first.
public struct LearnedCredits: Sendable, Hashable {
    /// One title's names and when they arrived.
    public struct Entry: Sendable, Hashable, Codable {
        public var titleID: String
        public var sourceID: UUID
        public var credits: TitleCredits
        /// The info answer's year, for the person page's order.
        public var year: Int?
        public var learned: Date

        public init(titleID: String, sourceID: UUID, credits: TitleCredits, year: Int?, learned: Date) {
            self.titleID = titleID
            self.sourceID = sourceID
            self.credits = credits
            self.year = year
            self.learned = learned
        }

        var key: ActivityKey { ActivityKey(titleID: titleID, sourceID: sourceID) }
    }

    public static let keepFor: TimeInterval = 30 * 24 * 60 * 60
    public static let limit = 20_000

    private var entries: [ActivityKey: Entry] = [:]

    public init() {}

    public var count: Int { entries.count }

    /// Every entry, in no order.
    var all: Dictionary<ActivityKey, Entry>.Values { entries.values }
    public var isEmpty: Bool { entries.isEmpty }

    /// The names learned for a title, nil when no info answer has arrived for it.
    public func entry(_ key: ActivityKey) -> Entry? {
        entries[key]
    }

    /// Records an info answer's names. An answer with no names is kept too,
    /// so the title counts as known. Returns false when nothing changed.
    @discardableResult
    public mutating func record(_ title: ShelfTitle, credits: TitleCredits, year: Int?, now: Date) -> Bool {
        let entry = Entry(titleID: title.id, sourceID: title.sourceID, credits: credits, year: year, learned: now)
        let previous = entries.updateValue(entry, forKey: entry.key)
        if previous == nil, entries.count > Self.limit { dropOldest(entries.count - Self.limit) }
        return previous?.credits != credits || previous?.year != year
    }

    /// Adds `newer`'s entries, which replace this one's for the same title,
    /// then drops the oldest past `limit`.
    public mutating func merge(_ newer: LearnedCredits) {
        entries.merge(newer.entries) { _, new in new }
        if entries.count > Self.limit { dropOldest(entries.count - Self.limit) }
    }

    /// Drops the names of sources not in `sources`. Returns false when nothing was dropped.
    @discardableResult
    public mutating func keep(sources: Set<UUID>) -> Bool {
        let before = entries.count
        entries = entries.filter { sources.contains($0.value.sourceID) }
        return entries.count != before
    }

    /// The file's contents: entries older than `keepFor` left out.
    public func encoded(now: Date) -> Data {
        let fresh = entries.values.filter { now.timeIntervalSince($0.learned) < Self.keepFor }.sorted { $0.learned < $1.learned }
        return (try? JSONEncoder().encode(File(entries: fresh))) ?? Data()
    }

    /// Reads a file written by `encoded(now:)`. Entries older than `keepFor`
    /// are dropped; a file that does not decode reads as empty.
    public static func decode(_ data: Data, now: Date) -> LearnedCredits {
        var learned = LearnedCredits()
        guard let file = try? JSONDecoder().decode(File.self, from: data), file.version == File.current else { return learned }
        for entry in file.entries where now.timeIntervalSince(entry.learned) < keepFor {
            learned.entries[entry.key] = entry
        }
        if learned.entries.count > limit { learned.dropOldest(learned.entries.count - limit) }
        return learned
    }

    private mutating func dropOldest(_ count: Int) {
        let oldest = entries.values.sorted { $0.learned < $1.learned }.prefix(count)
        for entry in oldest { entries[entry.key] = nil }
    }

    private struct File: Codable {
        static let current = 1
        var version = current
        var entries: [Entry]
    }
}
