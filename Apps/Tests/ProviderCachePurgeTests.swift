import Foundation
import Testing

@testable import Antenna

/// The one-time removal of replies earlier versions cached.
@Suite struct ProviderCachePurgeTests {
    private func store(_ address: String, in cache: URLCache) throws -> URLRequest {
        let url = try #require(URL(string: address))
        let request = URLRequest(url: url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data("[]".utf8)), for: request)
        return request
    }

    // source-management/provider-replies-are-not-kept-on-disk
    @Test func theFirstLaunchEmptiesTheCacheAndLaterOnesLeaveIt() throws {
        let defaults = try #require(UserDefaults(suiteName: "provider-cache-purge-\(UUID().uuidString)"))
        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0)
        let panel = try store("http://panel.test/player_api.php?username=u&password=secret", in: cache)
        ProviderCachePurge.run(defaults, cache: cache)
        #expect(cache.cachedResponse(for: panel) == nil)

        let poster = try store("http://panel.test/images/poster.jpg", in: cache)
        ProviderCachePurge.run(defaults, cache: cache)
        #expect(cache.cachedResponse(for: poster) != nil)
    }
}
