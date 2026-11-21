import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

/// Replies to calls that carry a login stay off disk
/// (source-management/provider-replies-are-not-kept-on-disk).
@Suite(.timeLimit(.minutes(1))) struct ProviderSessionTests {
    /// A panel at 127.0.0.1 that answers `player_api.php` with an empty list
    /// and no cache headers, the way most panels do.
    private func panel() async throws -> (FixtureServer, URL) {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.always("/player_api.php", .body(Data("[]".utf8), contentType: "application/json"))
        return (server, base)
    }

    /// The address the server saw, with the login in its query.
    private func requested(_ server: FixtureServer, base: URL) async throws -> URL {
        let request = try #require(await server.requests(for: "/player_api.php").last)
        let query = try #require(request.query)
        #expect(query.contains("password=secret"))
        return try #require(URL(string: "player_api.php?\(query)", relativeTo: base)?.absoluteURL)
    }

    /// Waits up to a second for `cache` to hold a reply for `url`, since
    /// the session stores it after handing the body over.
    private func cached(_ url: URL, in cache: URLCache) async throws -> CachedURLResponse? {
        for _ in 0..<20 {
            if let found = cache.cachedResponse(for: URLRequest(url: url)) { return found }
            try await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    // source-management/provider-replies-are-not-kept-on-disk
    @Test func aPanelCallLeavesNoReplyInTheSharedCache() async throws {
        let (server, base) = try await panel()
        defer { Task { await server.stop() } }
        let client = XtreamClient(credentials: .init(server: base, username: "viewer", password: "secret"))
        #expect(try await client.liveCategories().isEmpty)
        let url = try await requested(server, base: base)
        #expect(try await cached(url, in: .shared) == nil)
    }

    // source-management/provider-replies-are-not-kept-on-disk
    @Test func theProviderSessionHasNoCache() {
        #expect(URLSession.provider.configuration.urlCache == nil)
        #expect(URLSessionConfiguration.provider.urlCache == nil)
    }

    /// Proves the check above can see a stored reply. A session with a
    /// cache keeps the same reply under the address with the password.
    @Test func aCachingSessionWouldKeepTheLogin() async throws {
        let (server, base) = try await panel()
        defer { Task { await server.stop() } }
        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        let client = XtreamClient(
            credentials: .init(server: base, username: "viewer", password: "secret"), session: URLSession(configuration: configuration))
        _ = try await client.liveCategories()
        let url = try await requested(server, base: base)
        #expect(try await cached(url, in: cache) != nil)
    }
}
