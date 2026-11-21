import AntennaCore
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

/// Movie and series posters, decoded and kept in memory up to 50 MB and as
/// files on disk up to 500 MB (movies-and-series-browsing). Entries are named
/// by a SHA-256 hash of the poster's address, so no file name or file holds
/// the address. A poster that fails to load or decode gives nil, and the
/// screen shows the name tile.
actor PosterCache {
    static let shared = PosterCache()

    static let memoryLimit = 50 * 1024 * 1024
    static let diskLimit = 500 * 1024 * 1024

    private let memory = NSCache<NSString, Poster>()
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
        memory.totalCostLimit = memoryLimit
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
    }

    /// A cancelled caller stops waiting with nothing; the last one out
    /// cancels the load.
    private func leave(_ memoryKey: String, waiter: UUID) {
        guard var running = loading[memoryKey], let continuation = running.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(returning: nil)
        if running.waiters.isEmpty {
            running.task.cancel()
            loading[memoryKey] = nil
        } else {
            loading[memoryKey] = running
        }
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

    private func load(_ url: URL, key: String, memoryKey: String, fit: PosterFit?) async -> Poster? {
        let file = directory.appending(path: key)
        if let data = try? Data(contentsOf: file), let poster = await Self.decode(data, fit: fit) {
            try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
            remember(poster, key: memoryKey)
            return poster
        }
        let signpost = BrowseSignposts.signposter.beginInterval("poster")
        defer { BrowseSignposts.signposter.endInterval("poster", signpost) }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
            let poster = await Self.decode(data, fit: fit)
        else { return nil }
        remember(poster, key: memoryKey)
        store(data, at: file)
        return poster
    }

    /// Decodes away from the cache's actor, so posters decode in parallel
    /// instead of one at a time (movies-and-series-browsing/browsing-stays-responsive).
    @concurrent
    private static func decode(_ data: Data, fit: PosterFit?) async -> Poster? {
        Poster(data: data, fitting: fit)
    }

    private func remember(_ poster: Poster, key: String) {
        memory.setObject(poster, forKey: key as NSString, cost: poster.cost)
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
