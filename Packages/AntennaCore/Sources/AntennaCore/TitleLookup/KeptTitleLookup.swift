import Foundation

/// Wraps a `TitleLookup` with the rules the app follows
/// (title-metadata/matches-are-kept-on-the-device,
/// title-metadata/lookups-can-be-turned-off): matches are kept on this
/// device per source, shown again without asking for seven days, never kept
/// longer than six months, and nothing is asked or kept while lookups are off.
///
/// With a directory, each source's matches live in `<directory>/<source id>.json`
/// under Caches, which is never synced and which the system may purge.
/// Without one they live in memory only.
public actor KeptTitleLookup {
    /// Which title a match belongs to. It names the cache entry and is
    /// never sent.
    public struct Key: Sendable, Hashable {
        public var sourceID: UUID
        public var titleID: String

        public init(sourceID: UUID, titleID: String) {
            self.sourceID = sourceID
            self.titleID = titleID
        }

        public init(_ title: ShelfTitle) {
            self.init(sourceID: title.sourceID, titleID: title.id)
        }
    }

    /// A kept match is shown without asking again for seven days.
    public static let refreshAfter: TimeInterval = 7 * 86_400
    /// Nothing from the database is kept longer than 180 days.
    public static let keepAtMost: TimeInterval = 180 * 86_400

    struct Entry: Codable, Sendable {
        var match: TitleMatch
        var fetchedAt: Date
    }

    private let base: any TitleLookup
    private let directory: URL?
    private let now: @Sendable () -> Date
    private var enabled: Bool
    private var sources: [UUID: [String: Entry]] = [:]

    public init(base: any TitleLookup, directory: URL?, enabled: Bool = true, now: @escaping @Sendable () -> Date = { Date() }) {
        self.base = base
        self.directory = directory
        self.enabled = enabled
        self.now = now
    }

    /// `Caches/metadata` in the app's container.
    public static var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appending(path: "metadata", directoryHint: .isDirectory)
    }

    public var isEnabled: Bool { enabled }

    /// Turning lookups off deletes every kept match; turning them on keeps
    /// nothing until a page asks.
    public func setEnabled(_ on: Bool) {
        enabled = on
        guard !on else { return }
        sources = [:]
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// The kept match for `key` at any age up to the cap, for showing at
    /// once while a fresh answer is on its way. Nil while lookups are off.
    public func kept(_ key: Key) -> TitleMatch? {
        guard enabled else { return nil }
        return entries(key.sourceID)[key.titleID]?.match
    }

    /// The match for a title: the kept one while it is under seven days
    /// old, else a fresh answer from the wrapped lookup. When the lookup
    /// fails, the kept match at any age, so an offline device still shows
    /// what it had. Nil while lookups are off, with nothing sent.
    public func match(_ query: TitleLookupQuery, key: Key) async -> TitleMatch? {
        guard enabled else { return nil }
        let kept = entries(key.sourceID)[key.titleID]
        if let kept, now().timeIntervalSince(kept.fetchedAt) < Self.refreshAfter { return kept.match }
        let fresh: TitleMatch?
        do {
            fresh = try await base.match(query)
        } catch {
            return enabled ? kept?.match : nil
        }
        // Lookups may have been turned off while the request was out.
        guard enabled else { return nil }
        var list = entries(key.sourceID)
        list[key.titleID] = fresh.map { Entry(match: $0, fetchedAt: now()) }
        store(list, for: key.sourceID)
        return fresh
    }

    /// Deletes the matches of every source not in `kept`
    /// (title-metadata/matches-are-kept-on-the-device, deleting a source).
    public func keepSources(_ kept: Set<UUID>) {
        for id in sources.keys where !kept.contains(id) { sources[id] = nil }
        guard let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.pathExtension == "json" {
            let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent)
            if id.map(kept.contains) != true { try? FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: Storage

    private func file(_ source: UUID) -> URL? {
        directory?.appending(path: "\(source.uuidString).json")
    }

    /// A source's entries, read from its file the first time, with entries
    /// past the cap dropped.
    private func entries(_ source: UUID) -> [String: Entry] {
        if let loaded = sources[source] { return loaded }
        var read: [String: Entry] = [:]
        if let file = file(source), let data = try? Data(contentsOf: file) {
            read = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
        }
        let date = now()
        let fresh = read.filter { date.timeIntervalSince($0.value.fetchedAt) < Self.keepAtMost }
        sources[source] = fresh
        if fresh.count != read.count { write(fresh, for: source) }
        return fresh
    }

    private func store(_ list: [String: Entry], for source: UUID) {
        sources[source] = list
        write(list, for: source)
    }

    private func write(_ list: [String: Entry], for source: UUID) {
        guard let directory, let file = file(source) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
