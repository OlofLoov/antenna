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
    private var loading: [String: Task<Poster?, Never>] = [:]

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

    /// The poster from memory, else disk, else the network. Two calls for one
    /// address while it loads share one download.
    func poster(for url: URL) async -> Poster? {
        let key = Self.key(url)
        if let kept = memory.object(forKey: key as NSString) { return kept }
        if let running = loading[key] { return await running.value }
        let task = Task { await load(url, key: key) }
        loading[key] = task
        let poster = await task.value
        loading[key] = nil
        return poster
    }

    /// The poster from memory or disk, never the network; nil when it was
    /// never loaded or has been trimmed. The Top Shelf tiles use it.
    func cached(for url: URL) -> Poster? {
        let key = Self.key(url)
        if let kept = memory.object(forKey: key as NSString) { return kept }
        guard let data = try? Data(contentsOf: directory.appending(path: key)), let poster = Poster(data: data) else { return nil }
        remember(poster, key: key)
        return poster
    }

    private func load(_ url: URL, key: String) async -> Poster? {
        let file = directory.appending(path: key)
        if let data = try? Data(contentsOf: file), let poster = Poster(data: data) {
            try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
            remember(poster, key: key)
            return poster
        }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
            let poster = Poster(data: data)
        else { return nil }
        remember(poster, key: key)
        store(data, at: file)
        return poster
    }

    private func remember(_ poster: Poster, key: String) {
        memory.setObject(poster, forKey: key as NSString, cost: poster.cost)
    }

    private func store(_ data: Data, at file: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        trimDisk()
    }

    /// Deletes the least recently used files until the folder is under the
    /// disk limit.
    func trimDisk() {
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
        for entry in entries where total > diskLimit {
            try? FileManager.default.removeItem(at: entry.file)
            total -= entry.size
        }
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

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        self.image = image
    }

    init(image: CGImage) {
        self.image = image
    }

    /// The decoded size in bytes, what it costs the memory limit.
    var cost: Int { image.bytesPerRow * image.height }
}
