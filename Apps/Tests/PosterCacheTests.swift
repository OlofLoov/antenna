import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import Antenna

/// The poster cache against posters written as local files, in a folder of
/// its own per test.
@Suite struct PosterCacheTests {
    let root = FileManager.default.temporaryDirectory.appending(path: "posters-\(UUID().uuidString)", directoryHint: .isDirectory)
    var cacheFolder: URL { root.appending(path: "cache", directoryHint: .isDirectory) }

    /// Writes a `side` by `side` PNG and returns its address.
    private func poster(_ name: String, side: Int = 64) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let context = try #require(
            CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
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
}
