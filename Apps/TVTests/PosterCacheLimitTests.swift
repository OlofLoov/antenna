import Foundation
import Testing

@testable import AntennaTV

/// The poster cache's memory on Apple TV.
struct PosterCacheLimitTests {
    // Owner decision on 2026-11-25: 400 MB of posters on Apple TV was wasteful. Posters decode at
    // their card's resting size instead, and Apple TV keeps the same limit as every other platform.
    // Owner-found on 2026-11-28: posters showed late as the highlight moved, so more rows load ahead
    // and the limit is 80 MB, enough for them next to the rows on screen.
    @Test("movies-and-series-browsing/browsing-stays-responsive Apple TV keeps 80 MB of posters in memory")
    func limit() {
        #expect(PosterCache.memoryLimit == 80 * 1024 * 1024)
        #expect(PosterCache.prefetchLimit == 5)
        #expect(PosterCache.session.configuration.httpMaximumConnectionsPerHost == 6)
    }

    // The window ahead on a 4K Apple TV, where a poster decoded for its card is 448 by 640 pixels.
    @Test("movies-and-series-browsing/browsing-stays-responsive Apple TV's posters on screen and ahead fit the memory")
    func windowFits() {
        let poster = 448 * 640 * 4
        // Two and a half rows on screen, the rows by the highlight and the ones ahead of the scroll, six along.
        let onScreen = 20
        let ahead = 3 * 8 + 6
        let banner = 1920 * 1080 * 4
        #expect((onScreen + ahead) * poster + banner < PosterCache.memoryLimit)
    }
}
