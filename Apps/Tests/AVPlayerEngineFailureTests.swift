import AntennaCore
import AntennaTestSupport
import Foundation
import Synchronization
import Testing

@testable import Antenna

/// Lines an engine logged.
final class LogLines: Sendable {
    private let lines = Mutex<[String]>([])

    var all: [String] { lines.withLock { $0 } }

    func add(_ line: String) {
        lines.withLock { $0.append(line) }
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineFailureTests {
    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason server answers fail as one reason",
        arguments: [
            (401, PlaybackFailure.notAllowed), (403, .notAllowed), (404, .notFound), (429, .serverBusy), (500, .serverError),
            (418, .refused(status: 418)),
        ])
    func serverAnswers(status: Int, reason: PlaybackFailure) async throws {
        let harness = try await PlayerHarness(fastWaits: true)
        await harness.server.always("/hls/index.m3u8", .status(status))
        await #expect(throws: reason) { try await harness.engine.load(harness.url("hls/index.m3u8")) }
        #expect(harness.engine.state == .failed(reason))
        await harness.stop()
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a web page, garbage or TS at an HLS address is unreadable",
        arguments: [("page.mp4", "page.html"), ("clip.mp4", "garbage.bin"), ("live.m3u8", "channel.ts")])
    func notVideo(path: String, fixture: String) async throws {
        let harness = try await PlayerHarness()
        let body = try Data(contentsOf: harness.server.root.appending(path: fixture))
        await harness.server.always("/\(path)", .body(body, contentType: "application/octet-stream"))
        await #expect(throws: PlaybackFailure.unreadable) { try await harness.engine.load(harness.url(path)) }
        await harness.stop()
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a broken address fails without contacting any server",
        arguments: ["rtsp", "rtmp", "udp", "mms", "ftp"])
    func brokenAddress(scheme: String) async throws {
        let harness = try await PlayerHarness()
        let port = harness.base.port ?? 0
        let url = try #require(URL(string: "\(scheme)://127.0.0.1:\(port)/live/1.ts"))
        await #expect(throws: PlaybackFailure.unreadable) { try await harness.engine.load(url) }
        #expect(await harness.server.requests.isEmpty)
        await harness.stop()
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a server that is not there is unreachable, at once")
    func unreachable() async throws {
        let harness = try await PlayerHarness()
        let url = harness.url("hls/index.m3u8")
        await harness.server.stop()
        let started = ContinuousClock.now
        await #expect(throws: PlaybackFailure.unreachable) { try await harness.engine.load(url) }
        #expect(ContinuousClock.now - started < .seconds(2))
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEnginePrivacyTests {
    static let secrets = ["alice7", "s3cr3t", "4711", "abc123"]

    @Test("playback-engine/passwords-never-leak a failing, refused, playing and stalling stream leaves its login nowhere")
    func nothingLeaks() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let lines = LogLines()
        let engine = AVPlayerEngine(sleep: { _ in try await Task.sleep(for: .milliseconds(50)) }, log: { lines.add($0) })
        let harness = PlayerHarnessPlaylist(server: server, base: base)
        let path = "/live/alice7/s3cr3t/4711.m3u8"
        let url = try #require(URL(string: "\(base.absoluteString.dropLast())\(path)?token=abc123"))
        await server.setCookie("session=abc123")
        await server.script(path, .status(404), .status(401))
        await server.always(path, .body(try harness.absolutePlaylist(live: true), contentType: "application/vnd.apple.mpegurl"))

        let states = Recorded(await engine.states())
        let presentation = Recorded(await engine.presentation())
        let tracks = Recorded(await engine.tracks())
        let position = Recorded(await engine.position())
        let cues = Recorded(await engine.subtitleCues())
        var thrown: [String] = []
        for _ in 0..<2 {
            do {
                try await engine.load(url)
            } catch {
                thrown.append(String(reflecting: error))
            }
        }
        try await engine.load(url)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        #expect(await eventually(timeout: .seconds(20)) { engine.state.isReconnecting || engine.state == .buffering })
        await engine.stop()

        let reported =
            thrown + states.values.map { String(reflecting: $0) } + presentation.values.map { String(reflecting: $0) }
            + tracks.values.map { String(reflecting: $0) } + position.values.map { String(reflecting: $0) }
            + cues.values.map { String(reflecting: $0) }
        #expect(thrown.count == 2)
        #expect(!lines.all.isEmpty)
        for text in reported + lines.all {
            for secret in Self.secrets {
                #expect(!text.contains(secret), "\(text)")
            }
        }
        for line in lines.all {
            #expect(line.contains("127.0.0.1:\(base.port ?? 0)/….m3u8"), "\(line)")
        }
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        #expect(!cookies.contains { $0.value.contains("abc123") })
        for file in Self.storedFiles() {
            guard let data = try? Data(contentsOf: file) else { continue }
            for secret in Self.secrets {
                #expect(data.range(of: Data(secret.utf8)) == nil, "\(file.lastPathComponent)")
            }
        }
        await server.stop()
    }

    /// The app's temporary files and caches.
    static func storedFiles() -> [URL] {
        var roots = [FileManager.default.temporaryDirectory]
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            #if os(iOS)
                roots.append(caches)
            #else
                if let bundle = Bundle.main.bundleIdentifier { roots.append(caches.appending(path: bundle)) }
            #endif
        }
        var files: [URL] = []
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
            else {
                continue
            }
            for case let url as URL in walker {
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values?.isRegularFile == true, (values?.fileSize ?? 0) < 20_000_000 { files.append(url) }
            }
        }
        return files
    }
}

/// Builds playlists against a running server for tests that make their own engine.
struct PlayerHarnessPlaylist {
    let server: FixtureServer
    let base: URL

    /// The fixture HLS playlist with full segment addresses. A live one has
    /// no end tag, so the player waits for segments that never come.
    func absolutePlaylist(live: Bool = false) throws -> Data {
        let text = try String(contentsOf: server.root.appending(path: "hls/index.m3u8"), encoding: .utf8)
        let lines = text.split(separator: "\n").compactMap { line -> String? in
            if live, line.hasPrefix("#EXT-X-ENDLIST") || line.hasPrefix("#EXT-X-PLAYLIST-TYPE") { return nil }
            return line.hasSuffix(".ts") ? base.appending(path: "hls/\(line)").absoluteString : String(line)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }
}
