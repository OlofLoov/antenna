import Foundation
import Testing

@testable import AntennaCore

@Suite struct SourceUserAgentTests {
    @Test("sources-and-settings/a-user-agent-per-source Xtream calls carry the source's User-Agent")
    func xtreamCalls() async throws {
        let host = "agent-xtream.panel"
        StubURLProtocol.register(host: host, status: 200, body: Data("[]".utf8))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let server = try #require(URL(string: "http://\(host):8080"))
        let client = XtreamClient(
            credentials: XtreamCredentials(server: server, username: "u", password: "p"),
            session: URLSession(configuration: configuration), userAgent: "Box/1")
        _ = try await client.liveStreams()
        #expect(StubURLProtocol.requests(host: host).first?.value(forHTTPHeaderField: "User-Agent") == "Box/1")
    }

    @Test("sources-and-settings/a-user-agent-per-source an empty User-Agent means the default")
    func emptyIsDefault() throws {
        let url = try #require(URL(string: "http://p/list.m3u"))
        #expect(SourceDescriptor(name: "P", kind: .m3u, url: url, userAgent: "  ").headers.isEmpty)
        #expect(SourceDescriptor(name: "P", kind: .m3u, url: url).headers.isEmpty)
        #expect(SourceDescriptor(name: "P", kind: .m3u, url: url, userAgent: "Box/1").headers.userAgent == "Box/1")
    }

    @Test("playback-engine/streams-are-asked-for-with-their-headers a channel's own User-Agent wins over its source's")
    func channelWins() throws {
        let book = StreamHeaderBook()
        let source = UUID()
        var own = Channel(id: "a", name: "A", streamURL: try #require(URL(string: "http://cdn.example/a.ts")))
        own.headers = StreamHeaders(["User-Agent": "VLC/3.0.20"])
        let plain = Channel(id: "b", name: "B", streamURL: try #require(URL(string: "http://cdn.example/b.ts")))
        book.register([own, plain], source: source, base: StreamHeaders(["User-Agent": "Box/1"]))
        #expect(book.headers(for: own.streamURL).userAgent == "VLC/3.0.20")
        #expect(book.headers(for: plain.streamURL).userAgent == "Box/1")
        let panel = try #require(URL(string: "http://panel.example:8080"))
        book.register(StreamHeaders(["User-Agent": "Box/1"]), server: panel, source: source)
        let timeshift = try #require(URL(string: "http://panel.example:8080/timeshift/u/p/60/2026-11-21:20-00/1.ts"))
        #expect(book.headers(for: timeshift).userAgent == "Box/1")
    }
}
