import AntennaTestSupport
import Foundation
import Testing

/// The in-test server the playback tests run against.
@Suite(.timeLimit(.minutes(1))) struct FixtureServerTests {
    static let fixtures = [
        "film.mp4", "hls/index.m3u8", "hls/segment0.ts", "hls/segment1.ts", "hls/segment2.ts", "channel.ts", "channel.mkv",
        "channel.avi", "mpeg2.ts", "hdr10.mp4", "hlg.mp4", "radio.aac", "radio.mp3", "page.html", "garbage.bin",
    ]

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        return URLSession(configuration: configuration)
    }

    @Test("serves every fixture byte for byte", arguments: fixtures)
    func servesEveryFixture(name: String) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        let (data, response) = try await Self.session().data(from: base.appending(path: name))
        let expected = try Data(contentsOf: server.root.appending(path: name))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == expected)
        #expect(!data.isEmpty)
    }

    @Test func everyFixtureFileIsListed() throws {
        let root = try FixtureServer.fixtures()
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
        var found: Set<String> = []
        for case let url as URL in files where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            found.insert(String(url.path.dropFirst(root.path.count + 1)))
        }
        #expect(found == Set(Self.fixtures))
    }

    @Test func servesByteRanges() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        var request = URLRequest(url: base.appending(path: "film.mp4"))
        request.setValue("bytes=10-19", forHTTPHeaderField: "Range")
        let (data, response) = try await Self.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        let file = try Data(contentsOf: server.root.appending(path: "film.mp4"))
        #expect(http.statusCode == 206)
        #expect(http.value(forHTTPHeaderField: "Content-Range") == "bytes 10-19/\(file.count)")
        #expect(data == file.subdata(in: 10..<20))
    }

    @Test func ignoresRangesWhenToldTo() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.always("/film.mp4", .ignoreRanges)
        var request = URLRequest(url: base.appending(path: "film.mp4"))
        request.setValue("bytes=10-19", forHTTPHeaderField: "Range")
        let (_, response) = try await Self.session().data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.value(forHTTPHeaderField: "Accept-Ranges") == nil)
    }

    @Test func answersScriptedStatusesThenServes() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.script("/channel.ts", .status(503), .status(404))
        let url = base.appending(path: "channel.ts")
        var codes: [Int] = []
        for _ in 0..<3 {
            let (_, response) = try await Self.session().data(from: url)
            codes.append((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        #expect(codes == [503, 404, 200])
        #expect(await server.requests(for: "/channel.ts").count == 3)
    }

    @Test func unknownPathIsNotFound() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        let (_, response) = try await Self.session().data(from: base.appending(path: "nothing.ts"))
        #expect((response as? HTTPURLResponse)?.statusCode == 404)
    }

    @Test func refusesAConnection() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        // URLSession retries a GET once when the connection closes unanswered.
        await server.always("/channel.ts", .refuse)
        await #expect(throws: URLError.self) {
            _ = try await Self.session().data(from: base.appending(path: "channel.ts"))
        }
    }

    @Test func cutsAfterSomeBytes() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.script("/channel.ts", .cut(afterBytes: 1000))
        await #expect(throws: URLError.self) {
            _ = try await Self.session().data(from: base.appending(path: "channel.ts"))
        }
    }

    @Test func stallsAfterSomeBytes() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.script("/channel.ts", .stall(afterBytes: 1000))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        let session = URLSession(configuration: configuration)
        let error = await #expect(throws: URLError.self) {
            _ = try await session.data(from: base.appending(path: "channel.ts"))
        }
        #expect(error?.code == .timedOut)
    }

    @Test func servesAScriptedBody() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.script("/live/1.ts", .body(Data("#EXTM3U\n".utf8), contentType: "application/vnd.apple.mpegurl"))
        let (data, _) = try await Self.session().data(from: base.appending(path: "live/1.ts"))
        #expect(String(decoding: data, as: UTF8.self) == "#EXTM3U\n")
    }

    @Test func recordsQueryAndHeadersButMatchesOnPath() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        let url = try #require(URL(string: "radio.mp3?token=abc", relativeTo: base))
        _ = try await Self.session().data(from: url)
        let request = try #require(await server.requests(for: "/radio.mp3").first)
        #expect(request.query == "token=abc")
        #expect(request.method == "GET")
        #expect(await server.peakConnections == 1)
    }

    @Test func livePlaylistMovesAndLoops() {
        let playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:2
            #EXTINF:2.0,
            a.ts
            #EXTINF:2.0,
            b.ts
            #EXTINF:2.0,
            c.ts
            #EXT-X-ENDLIST
            """
        let start = FixtureServer.livePlaylist(from: playlist, elapsed: .seconds(1))
        #expect(start.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        #expect(!start.contains("ENDLIST"))
        #expect(start.split(separator: "\n").filter { $0.hasSuffix(".ts") } == ["a.ts", "b.ts", "c.ts"])
        let later = FixtureServer.livePlaylist(from: playlist, elapsed: .seconds(5))
        #expect(later.contains("#EXT-X-MEDIA-SEQUENCE:2"))
        #expect(later.split(separator: "\n").filter { $0.hasSuffix(".ts") } == ["c.ts", "a.ts", "b.ts"])
        #expect(later.contains("#EXT-X-DISCONTINUITY\n"))
    }

    @Test func servesALivePlaylistUnderLive() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        let (data, _) = try await Self.session().data(from: base.appending(path: "live/hls/index.m3u8"))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("#EXT-X-MEDIA-SEQUENCE:"))
        #expect(!text.contains("ENDLIST"))
        let (segment, _) = try await Self.session().data(from: base.appending(path: "live/hls/segment0.ts"))
        #expect(segment == (try Data(contentsOf: server.root.appending(path: "hls/segment0.ts"))))
    }
}
