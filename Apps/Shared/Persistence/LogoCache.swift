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

    /// A download in flight: the work and the rows waiting for it.
    private struct Load {
        let id: UUID
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<DecodedLogo?, Never>]
    }

    private let memory = NSCache<NSURL, DecodedLogo>()
    private let failed = Mutex<[URL: Date]>([:])
    private let loading = Mutex<[URL: Load]>([:])
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
    ///
    /// A row that is cancelled, such as one scrolled off screen, stops
    /// waiting at once, and once no row waits the download stops too, so
    /// the logos on screen do not queue behind rows already gone
    /// (live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive).
    func logo(for url: URL) async -> DecodedLogo? {
        if let kept = cached(url) { return kept }
        if let since = failed.withLock({ $0[url] }), Date.now.timeIntervalSince(since) < Self.retryAfter { return nil }
        guard !Task.isCancelled else { return nil }
        let waiter = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let started: UUID? = loading.withLock { running in
                    if running[url] != nil {
                        running[url]?.waiters[waiter] = continuation
                        return nil
                    }
                    let id = UUID()
                    running[url] = Load(id: id, waiters: [waiter: continuation])
                    return id
                }
                guard let id = started else { return }
                let task = Task.detached(priority: .utility) { [self] in
                    let logo = await download(url)
                    finish(url, id: id, with: logo)
                }
                let kept = loading.withLock { running in
                    guard running[url]?.id == id else { return false }
                    running[url]?.task = task
                    return true
                }
                // Every row left before the download was stored.
                if !kept { task.cancel() }
            }
        } onCancel: {
            leave(url, waiter: waiter)
        }
    }

    /// The rows waiting for a download, over every download in flight. For tests.
    var waiting: Int {
        loading.withLock { $0.values.reduce(0) { $0 + $1.waiters.count } }
    }

    /// Hands the download's logo to every row still waiting.
    private func finish(_ url: URL, id: UUID, with logo: DecodedLogo?) {
        let waiters = loading.withLock { running -> [CheckedContinuation<DecodedLogo?, Never>] in
            guard running[url]?.id == id, let done = running.removeValue(forKey: url) else { return [] }
            return Array(done.waiters.values)
        }
        for waiter in waiters { waiter.resume(returning: logo) }
    }

    /// A cancelled row stops waiting with nothing; the last one out cancels the download.
    private func leave(_ url: URL, waiter: UUID) {
        let (continuation, stop) = loading.withLock { running -> (CheckedContinuation<DecodedLogo?, Never>?, Task<Void, Never>?) in
            guard var load = running[url], let continuation = load.waiters.removeValue(forKey: waiter) else { return (nil, nil) }
            if load.waiters.isEmpty {
                running[url] = nil
                return (continuation, load.task)
            }
            running[url] = load
            return (continuation, nil)
        }
        continuation?.resume(returning: nil)
        stop?.cancel()
    }

    private func download(_ url: URL) async -> DecodedLogo? {
        let state = BrowseSignposts.signposter.beginInterval("logo")
        defer { BrowseSignposts.signposter.endInterval("logo", state) }
        guard let (data, response) = try? await session.data(from: url),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
            let logo = DecodedLogo(data: data, maxPixels: Self.maxPixels)
        else {
            // A download stopped because no row waits is not a broken logo.
            if !Task.isCancelled { failed.withLock { $0[url] = .now } }
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
