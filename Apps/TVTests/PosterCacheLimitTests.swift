import Testing

@testable import AntennaTV

/// The poster cache's memory on Apple TV.
struct PosterCacheLimitTests {
    // Found on 2026-11-25 with the large library on the Apple TV 4K simulator: moving down six
    // rows and back up found 3 posters in 10 not yet in memory with 160 MB, 1 in 170 with 400 MB.
    @Test("movies-and-series-browsing/browsing-stays-responsive Apple TV keeps 400 MB of posters in memory")
    func limit() {
        #expect(PosterCache.memoryLimit == 400 * 1024 * 1024)
    }
}
