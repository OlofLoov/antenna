import AntennaCore
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import Synchronization

/// Movie and series posters, decoded and kept in memory up to 50 MB and as
/// files on disk up to 500 MB (movies-and-series-browsing).
/// Entries are named by a SHA-256 hash of the poster's address, so no file
/// name or file holds the address. A poster that fails to load or decode gives nil, and the
/// screen shows the name tile.
actor PosterCache {
    static let shared = PosterCache()

    /// The same on every platform. Posters decode at their card's resting
    /// size, about 1.1 MB on a 4K Apple TV, so 50 MB holds the two and a half
    /// rows on screen and the few loaded ahead; the disk holds the rest
    /// (movies-and-series-browsing/browsing-stays-responsive).
    static let memoryLimit = 50 * 1024 * 1024
    static let diskLimit = 500 * 1024 * 1024

    private nonisolated let memory: Memory
    private let directory: URL
    private let session: URLSession
    private let diskLimit: Int
    private var loading: [String: Load] = [:]
    /// The folder's size after the last trim plus every write since, nil
    /// before the first write. It never counts less than the folder holds,
    /// so the folder is listed again only when a write may cross the limit.
    private var usage: Int?

    init(
        directory: URL = URL.cachesDirectory.appending(path: "Posters", directoryHint: .isDirectory), session: URLSession = .shared,
        memoryLimit: Int = PosterCache.memoryLimit, diskLimit: Int = PosterCache.diskLimit
    ) {
        self.directory = directory
        self.session = session
        self.diskLimit = diskLimit
        memory = Memory(limit: memoryLimit)
    }

    /// Decoded posters up to a limit in bytes, letting go of the least
    /// recently shown first, so the posters on screen and those just loaded
    /// ahead stay (movies-and-series-browsing/browsing-stays-responsive).
    /// `NSCache` lets go in no set order. Safe from any thread, so a card can
    /// look for its poster without waiting for the actor: the entries sit
    /// behind a mutex, and the memory pressure source is set up once in
    /// `init`. Empties itself when the system runs low on memory.
    private final class Memory: @unchecked Sendable {
        private struct Entry {
            let poster: Poster
            var used: UInt64
            var shown = false
            var origin = ""
        }

        private struct State {
            var entries: [String: Entry] = [:]
            var cost = 0
            var clock: UInt64 = 0
        }

        private let state = Mutex(State())
        private let limit: Int
        private let pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))

        init(limit: Int) {
            self.limit = limit
            pressure.setEventHandler { [weak self] in self?.removeAll() }
            pressure.activate()
        }

        deinit {
            pressure.cancel()
        }

        func removeAll() {
            state.withLock { $0 = State() }
        }

        func object(forKey key: NSString, shown: Bool = true) -> Poster? {
            state.withLock { state in
                guard var entry = state.entries[key as String] else { return nil }
                state.clock += 1
                entry.used = state.clock
                entry.shown = entry.shown || shown
                state.entries[key as String] = entry
                return entry.poster
            }
        }

        func setObject(_ poster: Poster, forKey key: NSString, cost: Int, origin: String = "") {
            guard cost <= limit else { return }
            state.withLock { state in
                state.clock += 1
                if let old = state.entries[key as String] { state.cost -= old.poster.cost }
                state.entries[key as String] = Entry(poster: poster, used: state.clock, origin: origin)
                state.cost += cost
                while state.cost > limit, let oldest = state.entries.min(by: { $0.value.used < $1.value.used })?.key {
                    let gone = state.entries.removeValue(forKey: oldest)
                    state.cost -= gone?.poster.cost ?? 0
                    #if DEBUG
                        PosterTrace.evicted.add(1, ordering: .relaxed)
                        if gone?.shown == false {
                            PosterTrace.evictedUnshown.add(1, ordering: .relaxed)
                            if gone?.origin == "along" { PosterTrace.evictedUnshownAlong.add(1, ordering: .relaxed) }
                            if gone?.origin == "below" { PosterTrace.evictedUnshownRow.add(1, ordering: .relaxed) }
                        }
                    #endif
                }
            }
        }
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
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
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

    /// A load in flight: the work and the callers waiting for it.
    private struct Load {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<Poster?, Never>]
    }

    /// Hands the load's poster to everyone still waiting.
    private func finish(_ memoryKey: String, id: UUID, with poster: Poster?) {
        guard loading[memoryKey]?.id == id, let done = loading.removeValue(forKey: memoryKey) else { return }
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
            running.task.cancel()
            loading[memoryKey] = nil
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
    /// row, for `stopPrefetching` once it scrolls away.
    func prefetch(_ urls: [URL], fitting fit: PosterFit, group: String) {
        var wanted = prefetching[group, default: []]
        for url in urls {
            let key = Self.key(url)
            let memoryKey = "\(key)@\(fit.key)"
            #if DEBUG
                PosterTrace.prefetchAsked.add(1, ordering: .relaxed)
            #endif
            guard memory.object(forKey: memoryKey as NSString, shown: false) == nil else { continue }
            wanted.insert(memoryKey)
            guard loading[memoryKey] == nil else { continue }
            #if DEBUG
                PosterTrace.prefetchStarted.add(1, ordering: .relaxed)
                if group.hasPrefix("along") { PosterTrace.startedAlong.add(1, ordering: .relaxed) }
            #endif
            let id = UUID()
            let origin = String(group.prefix { $0 != "." })
            let task = Task(priority: .utility) {
                let poster = await load(url, key: key, memoryKey: memoryKey, fit: fit, origin: origin)
                finish(memoryKey, id: id, with: poster)
            }
            loading[memoryKey] = Load(id: id, task: task, waiters: [:])
        }
        // Only loads still running are worth remembering.
        wanted = wanted.filter { loading[$0] != nil }
        prefetching[group] = wanted.isEmpty ? nil : wanted
        #if DEBUG
            traceGauges()
        #endif
    }

    /// Stops the loads `group` asked for that no card waits for and no
    /// other group wants, as when a row scrolls away, so a fast scroll does
    /// not leave a queue of posters nobody sees.
    func stopPrefetching(_ group: String) {
        guard let keys = prefetching.removeValue(forKey: group) else { return }
        let others = prefetching.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        for key in keys.subtracting(others) {
            guard let running = loading[key], running.waiters.isEmpty else { continue }
            running.task.cancel()
            loading[key] = nil
            #if DEBUG
                PosterTrace.cancelledByRow.add(1, ordering: .relaxed)
            #endif
        }
        #if DEBUG
            traceGauges()
        #endif
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

    /// The loads in flight, waited for or not. For tests.
    var inFlight: Int { loading.count }

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

/// A decoded poster. Immutable once made, so it can cross actors.
final class Poster: @unchecked Sendable {
    let image: CGImage

    /// Decodes `data` at full size, or with `fit` scaled down to cover that
    /// frame. A picture already that small or smaller decodes as it is.
    init?(data: Data, fitting fit: PosterFit? = nil) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let fit, let side = Self.pixels(of: source).flatMap({ fit.longestSide(pictureWidth: $0.width, pictureHeight: $0.height) }) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: side,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            self.image = image
            return
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        self.image = image
    }

    /// The picture's size in pixels as stored, read from its header.
    private static func pixels(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    init(image: CGImage) {
        self.image = image
    }

    /// The decoded size in bytes, what it costs the memory limit.
    var cost: Int { image.bytesPerRow * image.height }
}

#if DEBUG
    /// Where posters go between loading ahead and showing, since launch,
    /// for the browsing benchmarks. Read by the large shelf's probe.
    enum PosterTrace {
        static let prefetchAsked = Atomic<Int>(0)
        static let prefetchStarted = Atomic<Int>(0)
        static let cancelledByRow = Atomic<Int>(0)
        static let cancelledByCard = Atomic<Int>(0)
        static let evicted = Atomic<Int>(0)
        static let evictedUnshown = Atomic<Int>(0)
        static let evictedUnshownAlong = Atomic<Int>(0)
        static let evictedUnshownRow = Atomic<Int>(0)
        static let startedAlong = Atomic<Int>(0)
        static let missCold = Atomic<Int>(0)
        static let missInFlight = Atomic<Int>(0)
        static let rowTriggers = Atomic<Int>(0)
        static let alongTriggers = Atomic<Int>(0)
        /// Gauges, as of the last prefetch or stop.
        static let loading = Atomic<Int>(0)
        static let groups = Atomic<Int>(0)
        static let wanted = Atomic<Int>(0)
        /// The row the Apple TV highlight is in and its position there.
        static let focusedRow = Mutex("")
        /// Time spent finding the highlight's position in its row, and how
        /// many times, on the main actor.
        static let lookupMicros = Atomic<Int>(0)
        static let lookups = Atomic<Int>(0)

        static func lookup(since start: ContinuousClock.Instant) {
            let elapsed = ContinuousClock.now - start
            let micros = elapsed.components.seconds * 1_000_000 + elapsed.components.attoseconds / 1_000_000_000_000
            lookupMicros.add(Int(micros), ordering: .relaxed)
            lookups.add(1, ordering: .relaxed)
        }

        static var line: String {
            func v(_ counter: borrowing Atomic<Int>) -> Int { counter.load(ordering: .relaxed) }
            let counts: [(String, Int)] = [
                ("ask", v(prefetchAsked)), ("start", v(prefetchStarted)), ("startAlong", v(startedAlong)),
                ("cxRow", v(cancelledByRow)), ("cxCard", v(cancelledByCard)), ("evict", v(evicted)),
                ("evictUnshown", v(evictedUnshown)), ("euAlong", v(evictedUnshownAlong)), ("euRow", v(evictedUnshownRow)),
                ("missCold", v(missCold)), ("missFlight", v(missInFlight)), ("rowTrig", v(rowTriggers)),
                ("alongTrig", v(alongTriggers)), ("loading", v(loading)), ("groups", v(groups)), ("wanted", v(wanted)),
                ("lookups", v(lookups)), ("lookupMicros", v(lookupMicros)),
            ]
            return (counts.map { $0.0 + "=" + String($0.1) } + ["row=" + focusedRow.withLock { $0 }]).joined(separator: " ")
        }
    }
#endif
