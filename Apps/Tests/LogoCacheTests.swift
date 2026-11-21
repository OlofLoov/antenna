import Foundation
import Testing

@testable import Antenna

/// Logo downloads stop once no row waits for them.
@Suite struct LogoCacheTests {
    private func cache() -> LogoCache {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SilentURLProtocol.self]
        return LogoCache(session: URLSession(configuration: configuration))
    }

    // From the Live TV review: a fast flick through a large group left every
    // scrolled-past row's logo downloading, and the logos on screen waited.
    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive a row scrolled away stops its logo once no row waits")
    func cancelledRowsStopTheirLoad() async throws {
        let cache = cache()
        let url = try #require(URL(string: "https://silent.example/logo-\(UUID().uuidString).png"))
        let first = Task { await cache.logo(for: url) }
        let second = Task { await cache.logo(for: url) }
        try await eventually { cache.waiting == 2 && SilentURLProtocol.started(url) }
        first.cancel()
        #expect(await first.value == nil, "the cancelled row stops waiting at once")
        try await eventually { cache.waiting == 1 }
        #expect(!SilentURLProtocol.stopped(url), "another row still waits")
        second.cancel()
        #expect(await second.value == nil)
        try await eventually { SilentURLProtocol.stopped(url) }
        #expect(SilentURLProtocol.stopped(url), "the download stopped")
        #expect(cache.waiting == 0)
    }

    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive a stopped download is asked for again by the next row")
    func stoppedIsNotFailed() async throws {
        let cache = cache()
        let url = try #require(URL(string: "https://silent.example/logo-\(UUID().uuidString).png"))
        let first = Task { await cache.logo(for: url) }
        try await eventually { SilentURLProtocol.started(url) }
        first.cancel()
        _ = await first.value
        try await eventually { SilentURLProtocol.stopped(url) }
        let again = Task { await cache.logo(for: url) }
        try await eventually { cache.waiting == 1 }
        #expect(cache.waiting == 1, "the logo is not marked as broken")
        again.cancel()
        _ = await again.value
    }

    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(20)
        while await !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    }
}
