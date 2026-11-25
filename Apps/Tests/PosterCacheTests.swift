import AntennaCore
import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers

@testable import Antenna

/// The poster cache against posters written as local files, in a folder of
/// its own per test.
@Suite struct PosterCacheTests {
    let root = FileManager.default.temporaryDirectory.appending(path: "posters-\(UUID().uuidString)", directoryHint: .isDirectory)
    var cacheFolder: URL { root.appending(path: "cache", directoryHint: .isDirectory) }

    /// Writes a `side` wide PNG, square unless `height` says, and returns its address.
    private func poster(_ name: String, side: Int = 64, height: Int? = nil) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let context = try #require(
            CGContext(
                data: nil, width: side, height: height ?? side, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: height ?? side))
        let image = try #require(context.makeImage())
        let url = root.appending(path: "\(name).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order the limits are 50 MB in memory and 500 MB on disk")
    func limits() {
        #expect(PosterCache.memoryLimit == 50 * 1024 * 1024)
        #expect(PosterCache.diskLimit == 500 * 1024 * 1024)
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order entries are named by a hash and never hold the address")
    func keyedOnAHash() async throws {
        let url = try poster("dune")
        let key = PosterCache.key(url)
        #expect(key.count == 64)
        #expect(key == PosterCache.key(url))
        #expect(!key.contains("dune"))

        let cache = PosterCache(directory: cacheFolder)
        #expect(await cache.poster(for: url)?.image.width == 64)
        let files = try FileManager.default.contentsOfDirectory(atPath: cacheFolder.path)
        #expect(files == [key])
        let stored = try Data(contentsOf: cacheFolder.appending(path: key))
        #expect(stored.range(of: Data(url.absoluteString.utf8)) == nil, "the file holds the picture only")
        #expect(stored.range(of: Data("dune".utf8)) == nil)
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order a poster comes back from memory, then from disk")
    func memoryThenDisk() async throws {
        let url = try poster("arrival")
        let first = PosterCache(directory: cacheFolder)
        let loaded = await first.poster(for: url)
        try FileManager.default.removeItem(at: url)
        #expect(await first.poster(for: url) === loaded, "memory, no second read")
        let second = PosterCache(directory: cacheFolder)
        #expect(await second.poster(for: url) != nil, "from disk, the original gone")
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order a missing or broken poster gives nothing, so the name tile shows")
    func broken() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let garbage = root.appending(path: "broken.png")
        try Data("not a picture".utf8).write(to: garbage)
        let cache = PosterCache(directory: cacheFolder)
        #expect(await cache.poster(for: garbage) == nil)
        #expect(await cache.poster(for: root.appending(path: "missing.png")) == nil)
        #expect(await cache.diskUsage() == 0, "nothing broken is kept")
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order the disk stays under its limit, oldest first out")
    func diskLimit() async throws {
        let urls = try (0..<5).map { try poster("p\($0)", side: 128) }
        let size = try #require(try urls[0].resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let cache = PosterCache(directory: cacheFolder, diskLimit: size * 3)
        for url in urls {
            _ = await cache.poster(for: url)
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await cache.diskUsage() <= size * 3)
        let kept = Set(try FileManager.default.contentsOfDirectory(atPath: cacheFolder.path))
        #expect(kept.contains(PosterCache.key(urls[4])))
        #expect(!kept.contains(PosterCache.key(urls[0])))
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a full folder trims to 80% of its limit, not on every new poster")
    func trimsInBatches() async throws {
        let urls = try (0..<30).map { try poster("t\($0)", side: 128) }
        let size = try #require(try urls[0].resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let cache = PosterCache(directory: cacheFolder, diskLimit: size * 10)
        for url in urls { _ = await cache.poster(for: url) }
        #expect(await cache.diskUsage() <= size * 10)
        // One trim on the first write, then one each time two or three
        // posters fill the fifth that was freed. A trim per poster past
        // the limit would be 21.
        let trims = await cache.trims
        #expect(trims < 12, "the folder was trimmed \(trims) times for 30 posters")
    }

    @Test(
        "movies-and-series-browsing/browsing-stays-responsive thirty new posters into a folder of 3 000 load in under a second",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func manyFilesOnDisk() async throws {
        try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        let filler = Data(count: 1_024)
        for index in 0..<3_000 {
            try filler.write(to: cacheFolder.appending(path: "filler-\(index)"))
        }
        let urls = try (0..<30).map { try poster("new\($0)") }
        let cache = PosterCache(directory: cacheFolder)
        let elapsed = await ContinuousClock().measure {
            for url in urls { _ = await cache.poster(for: url) }
        }
        print("benchmark posters: thirty into 3 000 files \(elapsed)")
        #expect(elapsed < .seconds(1))
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a poster decodes at the size of its frame, the file stays whole")
    func decodedForTheFrame() async throws {
        let url = try poster("large", side: 1_000, height: 1_500)
        let cache = PosterCache(directory: cacheFolder)
        let card = try #require(PosterFit(width: 110, height: 165, scale: 2))
        let small = try #require(await cache.poster(for: url, fitting: card))
        #expect(small.image.width >= card.width - 1 && small.image.width < 1_000, "covers the frame, far below 1 000")
        #expect(small.image.height >= card.height - 1)
        #expect(await cache.poster(for: url, fitting: card) === small, "kept in memory per frame")
        #expect(await cache.poster(for: url)?.image.width == 1_000, "whole for a caller that needs it whole")
        let stored = try Data(contentsOf: cacheFolder.appending(path: PosterCache.key(url)))
        #expect(Poster(data: stored)?.image.width == 1_000, "the file on disk is the poster as it came")

        let tiny = try poster("tiny", side: 40, height: 60)
        #expect(await cache.poster(for: tiny, fitting: card)?.image.width == 40, "a small poster is never enlarged")
    }

    // Owner-found: fast scrolling left every scrolled-past card's download
    // running, so the posters on screen queued behind them.
    @Test("movies-and-series-browsing/browsing-stays-responsive a card scrolled away stops its download once nobody waits for it")
    func cancelledCardsStopTheirLoad() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SilentURLProtocol.self]
        let cache = PosterCache(directory: cacheFolder, session: URLSession(configuration: configuration))
        let url = try #require(URL(string: "https://silent.example/poster-\(UUID().uuidString).jpg"))
        let first = Task { await cache.poster(for: url) }
        let second = Task { await cache.poster(for: url) }
        try await eventually { await cache.waiting == 2 && SilentURLProtocol.started(url) }
        first.cancel()
        #expect(await first.value == nil, "the cancelled card stops waiting at once")
        try await eventually { await cache.waiting == 1 }
        #expect(!SilentURLProtocol.stopped(url), "another card still waits")
        second.cancel()
        #expect(await second.value == nil)
        try await eventually { SilentURLProtocol.stopped(url) }
        #expect(SilentURLProtocol.stopped(url), "the download stopped")
        #expect(await cache.waiting == 0)
    }

    // Owner-found on 2026-11-25: posters showed their name tiles as the
    // highlight reached them, since each started loading only on screen.
    @Test("movies-and-series-browsing/browsing-stays-responsive posters loaded ahead are in memory when their cards ask")
    func prefetchedPostersAreInMemory() async throws {
        let urls = try (0..<3).map { try poster("ahead-\($0)", side: 600, height: 900) }
        let cache = PosterCache(directory: cacheFolder)
        let card = try #require(PosterFit(width: 212, height: 318, scale: 1))
        await cache.prefetch(urls, fitting: card, group: "row")
        try await eventually { await cache.inFlight == 0 }
        for url in urls {
            #expect(await cache.inMemory(url, fitting: card), "decoded at the card's size before any card asks")
        }
        #expect(await cache.wanted == 0, "a row wants nothing once its loads finish")
        let shown = try #require(await cache.poster(for: urls[0], fitting: card))
        #expect(shown.image.width < 600, "decoded for the card, not whole")
    }

    // Found on 2026-11-25 with the large library at 50 MB: walking down and up the rows, posters loaded
    // ahead were let go before their cards showed, more with every walk, since NSCache lets go in no set order.
    @Test("movies-and-series-browsing/browsing-stays-responsive memory lets go of the poster shown longest ago first")
    func leastRecentlyShownGoesFirst() async throws {
        let urls = try (0..<4).map { try poster("recent-\($0)") }
        let frame = try #require(PosterFit(width: 64, height: 64, scale: 1))
        // A 64 by 64 poster costs 16 KB; three fit.
        let cache = PosterCache(directory: cacheFolder, memoryLimit: 3 * 64 * 64 * 4)
        for url in urls.prefix(3) { _ = await cache.poster(for: url, fitting: frame) }
        #expect(cache.kept(urls[0], fitting: frame) != nil, "shown again, so it is the most recent")
        _ = await cache.poster(for: urls[3], fitting: frame)
        #expect(await cache.inMemory(urls[0], fitting: frame))
        #expect(await !cache.inMemory(urls[1], fitting: frame), "shown longest ago, so it went")
        #expect(await cache.inMemory(urls[2], fitting: frame))
        #expect(await cache.inMemory(urls[3], fitting: frame))
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a card finds a kept poster without waiting")
    func keptWithoutWaiting() async throws {
        let url = try poster("kept-now", side: 600, height: 900)
        let cache = PosterCache(directory: cacheFolder)
        let card = try #require(PosterFit(width: 212, height: 318, scale: 2))
        #expect(cache.kept(url, fitting: card) == nil, "not loaded yet")
        let loaded = try #require(await cache.poster(for: url, fitting: card))
        #expect(cache.kept(url, fitting: card) === loaded)
        #expect(cache.kept(url, fitting: PosterFit(width: 110, height: 165, scale: 2)) == nil, "kept per frame")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a row scrolled away stops loading the posters nobody waits for")
    func prefetchStops() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SilentURLProtocol.self]
        let cache = PosterCache(directory: cacheFolder, session: URLSession(configuration: configuration))
        let card = try #require(PosterFit(width: 212, height: 318, scale: 1))
        let urls = try (0..<3).map { try #require(URL(string: "https://silent.example/ahead-\($0)-\(UUID().uuidString).jpg")) }
        await cache.prefetch(urls, fitting: card, group: "row")
        // Another row wants the third, as the rows under a row share posters with their own.
        await cache.prefetch([urls[2]], fitting: card, group: "other")
        try await eventually { urls.allSatisfy { SilentURLProtocol.started($0) } }
        // A card asks for the second poster while it loads, so it keeps loading.
        let waiting = Task { await cache.poster(for: urls[1], fitting: card) }
        try await eventually { await cache.waiting == 1 }
        await cache.stopPrefetching("row")
        try await eventually { SilentURLProtocol.stopped(urls[0]) }
        #expect(SilentURLProtocol.stopped(urls[0]), "nobody waits for the first, so it stops")
        #expect(!SilentURLProtocol.stopped(urls[1]), "a card waits for the second")
        #expect(!SilentURLProtocol.stopped(urls[2]), "another row wants the third")
        #expect(await cache.inFlight == 2)
        waiting.cancel()
        _ = await waiting.value
        await cache.stopPrefetching("other")
        try await eventually { await cache.inFlight == 0 }
        #expect(await cache.inFlight == 0)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a load a row still wants outlives a card that stopped waiting")
    func prefetchOutlivesACard() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SilentURLProtocol.self]
        let cache = PosterCache(directory: cacheFolder, session: URLSession(configuration: configuration))
        let card = try #require(PosterFit(width: 212, height: 318, scale: 1))
        let url = try #require(URL(string: "https://silent.example/kept-\(UUID().uuidString).jpg"))
        await cache.prefetch([url], fitting: card, group: "row")
        let waiting = Task { await cache.poster(for: url, fitting: card) }
        try await eventually { await cache.waiting == 1 }
        waiting.cancel()
        _ = await waiting.value
        #expect(await cache.inFlight == 1, "the row still wants it")
        #expect(!SilentURLProtocol.stopped(url))
        await cache.stopPrefetching("row")
        try await eventually { await cache.inFlight == 0 }
    }

    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while await !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    }
}

/// Never answers; records which requests started and which were stopped.
final class SilentURLProtocol: URLProtocol, @unchecked Sendable {
    private static let state = Mutex<(started: Set<URL>, stopped: Set<URL>)>(([], []))

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.state.withLock { _ = $0.started.insert(url) }
    }

    override func stopLoading() {
        guard let url = request.url else { return }
        Self.state.withLock { _ = $0.stopped.insert(url) }
    }

    static func started(_ url: URL) -> Bool { state.withLock { $0.started.contains(url) } }
    static func stopped(_ url: URL) -> Bool { state.withLock { $0.stopped.contains(url) } }
}
