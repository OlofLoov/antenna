import Foundation
import Testing

@testable import AntennaCore

/// Answers `player_api.php` by its `action` query item and counts the
/// requests per action, so one host can serve a whole live load.
final class XtreamActionStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var bodies: [String: (Int, Data)] = [:]
    nonisolated(unsafe) private static var counts: [String: Int] = [:]

    static func register(host: String, action: String?, status: Int = 200, body: String) {
        lock.withLock { bodies["\(host)|\(action ?? "")"] = (status, Data(body.utf8)) }
    }

    static func count(host: String, action: String?) -> Int {
        lock.withLock { counts["\(host)|\(action ?? "")"] ?? 0 }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [XtreamActionStub.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else { return }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value
        let key = "\(host)|\(action ?? "")"
        let reply = Self.lock.withLock {
            Self.counts[key, default: 0] += 1
            return Self.bodies[key]
        }
        guard let reply, let response = HTTPURLResponse(url: url, statusCode: reply.0, httpVersion: "HTTP/1.1", headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite struct XtreamTimeZoneTests {
    static func client(host: String) throws -> XtreamClient {
        XtreamClient(
            credentials: XtreamCredentials(server: try #require(URL(string: "http://\(host):8080")), username: "u", password: "p"),
            session: XtreamActionStub.session())
    }

    static func serveLive(host: String) {
        XtreamActionStub.register(host: host, action: "get_live_categories", body: #"[{"category_id":"1","category_name":"News"}]"#)
        XtreamActionStub.register(
            host: host, action: "get_live_streams", body: #"[{"stream_id":42,"name":"A","category_id":"1","tv_archive":1}]"#)
    }

    @Test("xtream-live-source/server-time-zone: the account information names the zone")
    func decodesZone() throws {
        let info = try JSONDecoder().decode(
            XtreamAccountInfo.self, from: Data(#"{"user_info":{"auth":1},"server_info":{"timezone":"Europe/Stockholm"}}"#.utf8))
        #expect(info.serverInfo?.timezone == "Europe/Stockholm")
        let bare = try JSONDecoder().decode(XtreamAccountInfo.self, from: Data(#"{"user_info":{"auth":1}}"#.utf8))
        #expect(bare.serverInfo == nil)
        let odd = try JSONDecoder().decode(XtreamAccountInfo.self, from: Data(#"{"user_info":{"auth":1},"server_info":[]}"#.utf8))
        #expect(odd.serverInfo == nil)
    }

    @Test("xtream-live-source/server-time-zone: time zone in the account information, asked for once per load")
    func oncePerLoad() async throws {
        let host = "tz-once.panel"
        Self.serveLive(host: host)
        XtreamActionStub.register(
            host: host, action: nil, body: #"{"user_info":{"auth":1},"server_info":{"timezone":"Europe/Stockholm"}}"#)
        let load = try await Self.client(host: host).liveLoad()
        #expect(load.timeZoneName == "Europe/Stockholm")
        #expect(load.channels.map(\.name) == ["A"])
        #expect(load.channels.first?.group == "News")
        #expect(load.channels.first?.catchupMode == .xc)
        #expect(XtreamActionStub.count(host: host, action: nil) == 1)

        let zones = XtreamTimeZones()
        let source = UUID()
        await zones.loaded(source, timeZoneName: load.timeZoneName)
        let zone = await zones.timeZone(for: source) {
            Issue.record("asked again with a zone known"); return nil
        }
        #expect(zone?.identifier == "Europe/Stockholm")
    }

    @Test("xtream-live-source/server-time-zone: a failed account call leaves the zone nil and the channels load")
    func failedAccount() async throws {
        let host = "tz-failed.panel"
        Self.serveLive(host: host)
        XtreamActionStub.register(host: host, action: nil, status: 500, body: "")
        let load = try await Self.client(host: host).liveLoad()
        #expect(load.timeZoneName == nil)
        #expect(load.channels.count == 1)
    }

    @Test("xtream-live-source/server-time-zone: time zone missing is asked for again on first need, once")
    func askedOnFirstNeed() async throws {
        let host = "tz-missing.panel"
        Self.serveLive(host: host)
        XtreamActionStub.register(host: host, action: nil, status: 500, body: "")
        let client = try Self.client(host: host)
        let zones = XtreamTimeZones()
        let source = UUID()
        await zones.loaded(source, timeZoneName: try await client.liveLoad().timeZoneName)
        #expect(XtreamActionStub.count(host: host, action: nil) == 1)

        XtreamActionStub.register(
            host: host, action: nil, body: #"{"user_info":{"auth":1},"server_info":{"timezone":"Europe/Stockholm"}}"#)
        let fetch: @Sendable () async -> String? = { try? await client.accountInfo().serverInfo?.timezone }
        #expect(await zones.timeZone(for: source, fetch: fetch)?.identifier == "Europe/Stockholm")
        #expect(XtreamActionStub.count(host: host, action: nil) == 2)
        _ = await zones.timeZone(for: source, fetch: fetch)
        #expect(XtreamActionStub.count(host: host, action: nil) == 2)
    }

    @Test("xtream-live-source/server-time-zone: a panel with no zone is not asked again until the next load")
    func noRepeatedAsks() async {
        let zones = XtreamTimeZones()
        let source = UUID()
        await zones.loaded(source, timeZoneName: nil)
        let asks = Counter()
        let fetch: @Sendable () async -> String? = {
            await asks.add()
            return nil
        }
        #expect(await zones.timeZone(for: source, fetch: fetch) == nil)
        #expect(await zones.timeZone(for: source, fetch: fetch) == nil)
        #expect(await asks.value == 1)
        await zones.loaded(source, timeZoneName: nil)
        _ = await zones.timeZone(for: source, fetch: fetch)
        #expect(await asks.value == 2)
        await zones.loaded(source, timeZoneName: "Mars/Olympus")
        #expect(await zones.timeZone(for: source, fetch: fetch) == nil)
    }

    actor Counter {
        private(set) var value = 0
        func add() { value += 1 }
    }
}
