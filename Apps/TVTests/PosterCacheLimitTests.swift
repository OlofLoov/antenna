import Testing

@testable import AntennaTV

/// The poster cache's memory on Apple TV.
struct PosterCacheLimitTests {
    // Owner decision on 2026-11-25: 400 MB of posters on Apple TV was wasteful. Posters decode at
    // their card's resting size instead, and Apple TV keeps 50 MB like every other platform.
    @Test("movies-and-series-browsing/browsing-stays-responsive Apple TV keeps 50 MB of posters in memory")
    func limit() {
        #expect(PosterCache.memoryLimit == 50 * 1024 * 1024)
    }
}
