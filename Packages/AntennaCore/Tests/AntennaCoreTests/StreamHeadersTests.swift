import Foundation
import Testing

@testable import AntennaCore

@Suite struct StreamHeadersTests {
    private func parse(_ text: String) -> [Channel] {
        M3UParser().parse(text).channels
    }

    @Test("m3u-playlists/stream-headers-from-the-playlist VLC options, EXTHTTP, KODIPROP and the user-agent attribute")
    func directives() {
        let channels = parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-id="a",A
            #EXTVLCOPT:http-user-agent=VLC/3.0.20
            #EXTVLCOPT:http-referrer=https://site.example/
            #EXTVLCOPT:network-caching=1000
            http://s/a.ts
            #EXTINF:-1,B
            #EXTHTTP:{"User-Agent":"Kodi","referer":"https://b.example/","X-Token":"t1","Count":2}
            http://s/b.ts
            #KODIPROP:inputstream.adaptive.stream_headers=User-Agent=Tivi%2F1&Referer=https%3A%2F%2Fc.example%2F
            #EXTINF:-1,C
            http://s/c.ts
            #EXTINF:-1 user-agent="Smart TV",D
            http://s/d.ts
            #EXTINF:-1,E
            http://s/e.ts
            """)
        #expect(channels.map(\.name) == ["A", "B", "C", "D", "E"])
        #expect(channels[0].headers?.fields == ["User-Agent": "VLC/3.0.20", "Referer": "https://site.example/"])
        #expect(channels[1].headers?.fields == ["User-Agent": "Kodi", "Referer": "https://b.example/", "X-Token": "t1"])
        #expect(channels[2].headers?.fields == ["User-Agent": "Tivi/1", "Referer": "https://c.example/"])
        #expect(channels[3].headers?.fields == ["User-Agent": "Smart TV"])
        // Headers end with the link they came before.
        #expect(channels[4].headers == nil)
    }

    @Test("m3u-playlists/stream-headers-from-the-playlist Kodi pipe headers leave the link and win over the other forms")
    func pipe() {
        let channels = parse(
            """
            #EXTINF:-1 user-agent="Attr",A
            #EXTVLCOPT:http-user-agent=Option
            http://s/live/1.ts|User-Agent=VLC/3.0.20&Referer=http%3A%2F%2Fx%2F
            #EXTINF:-1,B
            http://s/b.ts|nothing-here
            """)
        #expect(channels[0].streamURL.absoluteString == "http://s/live/1.ts")
        #expect(channels[0].headers?.fields == ["User-Agent": "VLC/3.0.20", "Referer": "http://x/"])
        #expect(channels[1].headers == nil)
        #expect(channels[1].streamURL.absoluteString == "http://s/b.ts%7Cnothing-here")
    }

    @Test("m3u-playlists/stream-headers-from-the-playlist headers never print their values")
    func redacted() {
        let headers = StreamHeaders(["Referer": "https://x/?token=secret", "user-agent": "VLC"])
        #expect(headers.fields.keys.sorted() == ["Referer", "User-Agent"])
        for printed in [headers.description, String(reflecting: headers), "\(headers)"] {
            #expect(!printed.contains("secret"))
            #expect(!printed.contains("VLC"))
        }
        var dumped = ""
        dump(headers, to: &dumped)
        #expect(!dumped.contains("secret"))
        var bad = StreamHeaders()
        bad.set("X-Bad", "a\r\nInjected: 1")
        bad.set("", "x")
        #expect(bad.isEmpty)
    }

    @Test("playback-engine/streams-are-asked-for-with-their-headers the book gives each address its own headers over its server's")
    func book() throws {
        let book = StreamHeaderBook()
        let source = UUID()
        var own = Channel(id: "a", name: "A", streamURL: try #require(URL(string: "http://panel.example:8080/live/1.ts")))
        own.headers = StreamHeaders(["Referer": "http://r/"])
        let plain = Channel(id: "b", name: "B", streamURL: try #require(URL(string: "http://panel.example:8080/live/2.ts")))
        book.register([own, plain], source: source)
        let server = try #require(URL(string: "http://PANEL.example:8080"))
        book.register(StreamHeaders(["User-Agent": "Box/1"]), server: server, source: source)
        #expect(book.headers(for: own.streamURL).fields == ["User-Agent": "Box/1", "Referer": "http://r/"])
        #expect(book.headers(for: plain.streamURL).fields == ["User-Agent": "Box/1"])
        #expect(book.headers(for: try #require(URL(string: "http://panel.example:9090/live/2.ts"))).isEmpty)
        book.register([plain], source: source)
        #expect(book.headers(for: own.streamURL).fields == ["User-Agent": "Box/1"])
        book.remove(source: source)
        #expect(book.headers(for: own.streamURL).isEmpty)
    }

    @Test("playback-engine/streams-are-asked-for-with-their-headers the stream probe sends the address's headers")
    func probeSendsHeaders() async throws {
        let host = "headers-probe.panel"
        StubURLProtocol.register(host: host, status: 200, body: Data(repeating: 0x47, count: 188))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let url = try #require(URL(string: "http://\(host)/live/1.ts"))
        var channel = Channel(id: "a", name: "A", streamURL: url)
        channel.headers = StreamHeaders(["User-Agent": "VLC/3.0.20", "Referer": "http://r/"])
        let source = UUID()
        StreamHeaderBook.shared.register([channel], source: source)
        defer { StreamHeaderBook.shared.remove(source: source) }
        _ = try await StreamProbe.run(url, session: URLSession(configuration: configuration))
        let request = try #require(StubURLProtocol.requests(host: host).first)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "VLC/3.0.20")
        #expect(request.value(forHTTPHeaderField: "Referer") == "http://r/")
    }
}
