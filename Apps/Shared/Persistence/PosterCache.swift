import AntennaCore
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import Synchronization

/// Movie and series posters, decoded and kept in memory up to 80 MB and as
/// files on disk up to 500 MB (movies-and-series-browsing).
/// Entries are named by a SHA-256 hash of the poster's address, so no file
/// name or file holds the address. A poster that fails to load or decode gives nil, and the
/// screen shows the name tile.
actor PosterCache {
    static let shared = PosterCache()

    /// The same on every platform. Posters decode at their card's resting
    /// size, about 1.1 MB on a 4K Apple TV, so 80 MB holds about 70: the
    /// two and a half rows on screen, the rows loaded ahead of the
    /// highlight and the scroll, and a banner backdrop. The disk holds the
    /// rest (movies-and-series-browsing/browsing-stays-responsive).
    static let memoryLimit = 80 * 1024 * 1024
    static let diskLimit = 500 * 1024 * 1024
    /// Connections the posters open to one host, as many as a browser opens.
    static let connectionsPerHost = 6
    /// Posters loaded ahead at once, one fewer than the connections, so a
    /// card on screen always finds a connection free. The rest wait in
    /// line, newest asks first, and a poster nobody wants any more leaves
    /// the line without being downloaded
    /// (movies-and-series-browsing/browsing-stays-responsive).
    static let prefetchLimit = connectionsPerHost - 1

    /// The posters' own session. The cache keeps the files, so the session keeps none.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = connectionsPerHost
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private nonisolated let memory: PosterMemory
    private let directory: URL
    private let session: URLSession
    private let diskLimit: Int
    private var loading: [String: Load] = [:]
    /// The posters asked for ahead that wait their turn or load.
    private var line: PosterLine
    /// The folder's size after the last trim plus every write since, nil
    /// before the first write. It never counts less than the folder holds,
    /// so the folder is listed again only when a write may cross the limit.
    private var usage: Int?

    init(
        directory: URL = URL.cachesDirectory.appending(path: "Posters", directoryHint: .isDirectory),
        session: URLSession = PosterCache.session, memoryLimit: Int = PosterCache.memoryLimit, diskLimit: Int = PosterCache.diskLimit,
        prefetchLimit: Int = PosterCache.prefetchLimit
    ) {
        self.directory = directory
        self.session = session
        self.diskLimit = diskLimit
        line = PosterLine(limit: prefetchLimit)
        memory = PosterMemory(limit: memoryLimit)
    }

    /// The poster for `fit` if it is in memory now, without waiting for the
    /// actor, so a card whose poster is kept draws it in its first frame.
    /// The browsing benchmarks count each call as a card asking, and a nil
    /// as a poster not ready (movies-and-series-browsing/browsing-stays-responsive).
    nonisolated func kept(_ url: URL, fitting fit: PosterFit?) -> Poster? {
        let key = Self.key(url)
        let kept = memory.object(forKey: (fit.map { "\(key)@\($0.key)" } ?? key) as NSString)
        #if DEBUG
            Self.asks.add(1, ordering: .relaxed)
            if kept == nil { Self.misses.add(1, ordering: .relaxed) }
        #endif
        return kept
    }

    /// The hex SHA-256 of the address, the entry's name in memory and on disk.
    static func key(_ url: URL) -> String {
        // Every card on screen looks itself up on the main actor, so no
        // `String(format:)` per byte.
        let digits = Array("0123456789abcdef".utf8)
        var hex: [UInt8] = []
        hex.reserveCapacity(64)
        for byte in SHA256.hash(data: Data(url.absoluteString.utf8)) {
            hex.append(digits[Int(byte >> 4)])
            hex.append(digits[Int(byte & 0x0f)])
        }
        return String(decoding: hex, as: UTF8.self)
    }

    /// The poster from memory, else disk, else the network, decoded to
    /// cover `fit`, or at full size without one. Memory keeps one picture
    /// per address and frame; disk keeps the file as it came. Two calls
    /// for one address and frame while it loads share one download.
    ///
    /// A caller that is cancelled, such as a card scrolled off screen,
    /// stops waiting at once, and once no caller waits the download and
    /// decode stop too, so a fast scroll does not leave a queue of posters
    /// nobody sees (movies-and-series-browsing/browsing-stays-responsive).
    func poster(for url: URL, fitting fit: PosterFit? = nil) async -> Poster? {
        let key = Self.key(url)
        let memoryKey = fit.map { "\(key)@\($0.key)" } ?? key
        if let kept = memory.object(forKey: memoryKey as NSString) { return kept }
        guard !Task.isCancelled else { return nil }
        #if DEBUG
            if loading[memoryKey] == nil {
                PosterTrace.missCold.add(1, ordering: .relaxed)
            } else {
                PosterTrace.missInFlight.add(1, ordering: .relaxed)
            }
        #endif
        let waiter = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if loading[memoryKey] != nil {
                    loading[memoryKey]?.waiters[waiter] = continuation
                    // A card on screen does not wait in the line of posters loaded ahead.
                    if loading[memoryKey]?.task == nil, let pending = line.take(memoryKey) { start(pending) }
                } else {
                    let id = UUID()
                    let task = Task {
                        let poster = await load(url, key: key, memoryKey: memoryKey, fit: fit)
                        finish(memoryKey, id: id, with: poster)
                    }
                    loading[memoryKey] = Load(id: id, task: task, waiters: [waiter: continuation])
                }
            }
        } onCancel: {
            Task { await self.leave(memoryKey, waiter: waiter) }
        }
    }

    /// A load in flight or in line: the work, none while in line, and the
    /// callers waiting for it.
    private struct Load {
        let id: UUID
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<Poster?, Never>]
    }

    /// Starts the load of a poster that was in line.
    private func start(_ pending: PosterLine.Pending) {
        guard let id = loading[pending.memoryKey]?.id else { return }
        #if DEBUG
            PosterTrace.prefetchStarted.add(1, ordering: .relaxed)
            if pending.origin == "along" { PosterTrace.startedAlong.add(1, ordering: .relaxed) }
        #endif
        let ahead = line.loading.contains(pending.memoryKey)
        loading[pending.memoryKey]?.task = Task(priority: ahead ? .utility : nil) {
            let poster = await load(pending.url, key: pending.key, memoryKey: pending.memoryKey, fit: pending.fit, origin: pending.origin)
            finish(pending.memoryKey, id: id, with: poster)
        }
    }

    /// Starts posters from the line while fewer than `prefetchLimit` load ahead.
    private func startFromTheLine() {
        while let next = line.next() {
            if let load = loading[next.memoryKey], load.task == nil { start(next) } else { line.remove(next.memoryKey) }
        }
    }

    /// Drops a load nobody waits for, running or in line.
    private func drop(_ memoryKey: String) {
        loading.removeValue(forKey: memoryKey)?.task?.cancel()
        line.remove(memoryKey)
    }

    /// Hands the load's poster to everyone still waiting.
    private func finish(_ memoryKey: String, id: UUID, with poster: Poster?) {
        guard loading[memoryKey]?.id == id, let done = loading.removeValue(forKey: memoryKey) else { return }
        line.remove(memoryKey)
        defer { startFromTheLine() }
        for waiter in done.waiters.values { waiter.resume(returning: poster) }
        // A finished load is no longer wanted by any row.
        for (group, keys) in prefetching where keys.contains(memoryKey) {
            let rest = keys.subtracting([memoryKey])
            prefetching[group] = rest.isEmpty ? nil : rest
        }
    }

    /// A cancelled caller stops waiting with nothing; the last one out
    /// cancels the load, unless a row still wants it loaded ahead.
    private func leave(_ memoryKey: String, waiter: UUID) {
        guard var running = loading[memoryKey], let continuation = running.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(returning: nil)
        if running.waiters.isEmpty, !prefetching.values.contains(where: { $0.contains(memoryKey) }) {
            drop(memoryKey)
            startFromTheLine()
            #if DEBUG
                PosterTrace.cancelledByCard.add(1, ordering: .relaxed)
            #endif
        } else {
            loading[memoryKey] = running
        }
    }

    /// Loads and decodes posters before anyone asks for them, so they are in
    /// memory when their cards come into view
    /// (movies-and-series-browsing/browsing-stays-responsive). A card that
    /// asks while one loads joins it. `group` names who asked, such as a
    /// row, for `stopPrefetching` once it scrolls away. At most
    /// `prefetchLimit` load at once; the rest wait in line, these `urls` in
    /// their order ahead of those asked for before. With `replacing`, the
    /// group wants these alone, and what it wanted before that no card
    /// waits for and no other group wants stops, as when the highlight moves.
    func prefetch(_ urls: [URL], fitting fit: PosterFit, group: String, replacing: Bool = false) {
        let before = prefetching[group, default: []]
        var wanted = replacing ? Set<String>() : before
        var asks: [PosterLine.Pending] = []
        for url in urls {
            let key = Self.key(url)
            let memoryKey = "\(key)@\(fit.key)"
            #if DEBUG
                PosterTrace.prefetchAsked.add(1, ordering: .relaxed)
            #endif
            guard memory.object(forKey: memoryKey as NSString, shown: false) == nil else { continue }
            wanted.insert(memoryKey)
            let pending = PosterLine.Pending(url: url, key: key, memoryKey: memoryKey, fit: fit, origin: String(group.prefix { $0 != "." }))
            if let load = loading[memoryKey] {
                // Still in line, it moves up with this ask.
                if load.task == nil { asks.append(pending) }
                continue
            }
            loading[memoryKey] = Load(id: UUID(), task: nil, waiters: [:])
            asks.append(pending)
        }
        line.putInFront(asks)
        // Only loads running or in line are worth remembering.
        wanted = wanted.filter { loading[$0] != nil }
        prefetching[group] = wanted.isEmpty ? nil : wanted
        if replacing { release(before.subtracting(wanted)) }
        startFromTheLine()
        #if DEBUG
            traceGauges()
        #endif
    }

    /// Stops the loads `group` asked for that no card waits for and no
    /// other group wants, as when a row scrolls away, so a fast scroll does
    /// not leave a queue of posters nobody sees.
    func stopPrefetching(_ group: String) {
        guard let keys = prefetching.removeValue(forKey: group) else { return }
        release(keys)
        startFromTheLine()
        #if DEBUG
            traceGauges()
        #endif
    }

    /// Drops the loads of `keys` that no card waits for and no group wants.
    private func release(_ keys: Set<String>) {
        guard !keys.isEmpty else { return }
        let others = prefetching.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        for key in keys.subtracting(others) {
            guard let running = loading[key], running.waiters.isEmpty else { continue }
            drop(key)
            #if DEBUG
                PosterTrace.cancelledByRow.add(1, ordering: .relaxed)
            #endif
        }
    }

    #if DEBUG
        private func traceGauges() {
            PosterTrace.loading.store(loading.count, ordering: .relaxed)
            PosterTrace.groups.store(prefetching.count, ordering: .relaxed)
            PosterTrace.wanted.store(prefetching.values.reduce(0) { $0 + $1.count }, ordering: .relaxed)
        }
    #endif

    #if DEBUG
        /// Calls to `kept` that found nothing, since launch: cards that
        /// showed the placeholder. The browsing benchmarks read it
        /// (movies-and-series-browsing/browsing-stays-responsive).
        static let misses = Atomic<Int>(0)
        /// Calls to `kept`, since launch.
        static let asks = Atomic<Int>(0)
    #endif

    /// The posters each group asked to prefetch that are still loading.
    private var prefetching: [String: Set<String>] = [:]

    /// The posters rows still want loaded, over every row. For tests.
    var wanted: Int { prefetching.values.reduce(0) { $0 + $1.count } }

    /// The loads in flight or in line, waited for or not. For tests.
    var inFlight: Int { loading.count }

    /// The loads running, waited for or not, not those in line. For tests.
    var running: Int { loading.values.filter { $0.task != nil }.count }

    /// The posters asked for ahead that wait in line. For tests.
    var inLine: Int { line.waiting.count }

    /// The bytes and the number of posters in memory. For tests.
    nonisolated var memoryCost: Int { memory.cost }
    nonisolated var memoryCount: Int { memory.count }

    /// True when the poster at `url` decoded for `fit` is in memory. For tests.
    func inMemory(_ url: URL, fitting fit: PosterFit) -> Bool {
        memory.object(forKey: "\(Self.key(url))@\(fit.key)" as NSString) != nil
    }

    /// The callers waiting for a load, over every load in flight. For tests.
    var waiting: Int { loading.values.reduce(0) { $0 + $1.waiters.count } }

    /// The poster from memory or disk, never the network; nil when it was
    /// never loaded or has been trimmed. The Top Shelf tiles use it.
    func cached(for url: URL) -> Poster? {
        let key = Self.key(url)
        if let kept = memory.object(forKey: key as NSString) { return kept }
        guard let data = try? Data(contentsOf: directory.appending(path: key)), let poster = Poster(data: data) else { return nil }
        remember(poster, key: key)
        return poster
    }

    private func load(_ url: URL, key: String, memoryKey: String, fit: PosterFit?, origin: String = "") async -> Poster? {
        let file = directory.appending(path: key)
        if let data = try? Data(contentsOf: file), let poster = await Self.decode(data, fit: fit) {
            try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
            remember(poster, key: memoryKey, origin: origin)
            return poster
        }
        let signpost = BrowseSignposts.signposter.beginInterval("poster")
        defer { BrowseSignposts.signposter.endInterval("poster", signpost) }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
            let poster = await Self.decode(data, fit: fit)
        else { return nil }
        remember(poster, key: memoryKey, origin: origin)
        store(data, at: file)
        return poster
    }

    /// Decodes away from the cache's actor, so posters decode in parallel
    /// instead of one at a time (movies-and-series-browsing/browsing-stays-responsive).
    @concurrent
    private static func decode(_ data: Data, fit: PosterFit?) async -> Poster? {
        Poster(data: data, fitting: fit)
    }

    private func remember(_ poster: Poster, key: String, origin: String = "") {
        memory.setObject(poster, forKey: key as NSString, cost: poster.cost, origin: origin)
    }

    private func store(_ data: Data, at file: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        if let usage, usage + data.count <= diskLimit {
            self.usage = usage + data.count
        } else {
            usage = trimDisk()
        }
    }

    /// Trimming stops at this share of the limit, so the writes after a
    /// trim fit without listing the folder again
    /// (movies-and-series-browsing/browsing-stays-responsive).
    static let trimmedShare = 0.8

    /// How many times the folder was trimmed. For tests.
    private(set) var trims = 0

    /// Deletes the least recently used files until the folder holds at most
    /// `trimmedShare` of the disk limit. Returns the bytes left.
    @discardableResult
    func trimDisk() -> Int {
        trims += 1
        let target = Int(Double(diskLimit) * Self.trimmedShare)
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        struct Entry {
            let file: URL
            let size: Int
            let used: Date
        }
        var entries = files.compactMap { file -> Entry? in
            guard let values = try? file.resourceValues(forKeys: keys), let size = values.fileSize else { return nil }
            return Entry(file: file, size: size, used: values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        entries.sort { $0.used < $1.used }
        for entry in entries where total > target {
            try? FileManager.default.removeItem(at: entry.file)
            total -= entry.size
        }
        return total
    }

    /// The bytes on disk, for tests and the limit check.
    func diskUsage() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
