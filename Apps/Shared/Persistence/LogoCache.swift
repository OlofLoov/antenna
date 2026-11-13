import CoreGraphics
import Foundation
import ImageIO
import Synchronization

/// Channel logos, shrunk to tile size off the main thread and kept in memory
/// up to 20 MB (design-system/channels-without-a-logo-show-initials). The
/// download goes through the shared URL cache, which the Top Shelf reads
/// too. A logo that fails to load or decode gives nil for five minutes, and
/// the row keeps its initials.
final class LogoCache: @unchecked Sendable {
    static let shared = LogoCache()

    static let memoryLimit = 20 * 1024 * 1024
    /// The longest side a logo is decoded at, in pixels. The largest logo
    /// tile, 132 points wide in the Apple TV panel, needs 264 at 2x.
    static let maxPixels = 280
    /// How long a logo that failed stays failed before the next row asks again.
    static let retryAfter: TimeInterval = 300

    private let memory = NSCache<NSURL, DecodedLogo>()
    private let failed = Mutex<[URL: Date]>([:])
    private let loading = Mutex<[URL: Task<DecodedLogo?, Never>]>([:])
    private let session: URLSession

    init(session: URLSession = .shared, memoryLimit: Int = LogoCache.memoryLimit) {
        self.session = session
        memory.totalCostLimit = memoryLimit
    }

    /// The logo when it is in memory, without waiting; what a row draws in its first frame.
    func cached(_ url: URL) -> DecodedLogo? {
        memory.object(forKey: url as NSURL)
    }

    /// The logo from memory, else the network. Rows asking for one address
    /// while it loads share one download and one decode.
    func logo(for url: URL) async -> DecodedLogo? {
        if let kept = cached(url) { return kept }
        if let since = failed.withLock({ $0[url] }), Date.now.timeIntervalSince(since) < Self.retryAfter { return nil }
        let task = loading.withLock { running in
            if let task = running[url] { return task }
            let task = Task.detached(priority: .utility) { [self] in await download(url) }
            running[url] = task
            return task
        }
        let logo = await task.value
        loading.withLock { $0[url] = nil }
        return logo
    }

    private func download(_ url: URL) async -> DecodedLogo? {
        let state = BrowseSignposts.signposter.beginInterval("logo")
        defer { BrowseSignposts.signposter.endInterval("logo", state) }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
            let logo = DecodedLogo(data: data, maxPixels: Self.maxPixels)
        else {
            failed.withLock { $0[url] = .now }
            return nil
        }
        memory.setObject(logo, forKey: url as NSURL, cost: logo.cost)
        failed.withLock { $0[url] = nil }
        return logo
    }
}

/// A decoded logo, at most `LogoCache.maxPixels` on its longest side.
/// Immutable once made, so it can cross actors.
final class DecodedLogo: @unchecked Sendable {
    let image: CGImage

    init?(data: Data, maxPixels: Int) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        self.image = image
    }

    /// The decoded size in bytes, what it costs the memory limit.
    var cost: Int { image.bytesPerRow * image.height }
}
