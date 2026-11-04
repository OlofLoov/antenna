import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamClientTests {
    private func credentials(_ server: String) throws -> XtreamCredentials {
        XtreamCredentials(server: try #require(URL(string: server)), username: "u", password: "p")
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    /// A client whose session answers every request to `host` with `status` and `body`.
    private func stubbedClient(host: String, status: Int, body: String) throws -> XtreamClient {
        StubURLProtocol.register(host: host, status: status, body: Data(body.utf8))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return XtreamClient(credentials: try credentials("http://\(host):8080"), session: URLSession(configuration: configuration))
    }

    @Test("0003/AC-1 request shape, with and without a category")
    func requestShape() async throws {
        let client = try stubbedClient(host: "ac1.panel", status: 200, body: "[]")

        _ = try await client.liveStreams(categoryID: "3")
        _ = try await client.liveStreams()

        let urls = StubURLProtocol.requests(host: "ac1.panel").map(\.url?.absoluteString)
        #expect(
            urls == [
                "http://ac1.panel:8080/player_api.php?username=u&password=p&action=get_live_streams&category_id=3",
                "http://ac1.panel:8080/player_api.php?username=u&password=p&action=get_live_streams",
            ])
        #expect(StubURLProtocol.requests(host: "ac1.panel").allSatisfy { $0.httpMethod == "GET" })
    }

    @Test("0003/AC-2 loose numeric types decode")
    func looseNumericTypes() throws {
        let streams = try decode(
            [XtreamLiveStream].self,
            #"[{"num":"7","name":"BBC One","stream_id":"42","category_id":3,"tv_archive":"1","tv_archive_duration":"3"}]"#)
        let stream = try #require(streams.first)
        #expect(stream.num == 7)
        #expect(stream.streamID == 42)
        #expect(stream.tvArchive == 1)
        #expect(stream.tvArchiveDuration == 3)
        #expect(stream.categoryID == "3")
    }

    @Test("0003/AC-3 category id as number or string")
    func categoryIDNumberOrString() throws {
        let categories = try decode(
            [XtreamCategory].self,
            #"[{"category_id":7,"category_name":"A"},{"category_id":"8","category_name":"B"}]"#)
        #expect(categories.map(\.categoryID) == ["7", "8"])
    }

    @Test("0003/AC-4 live stream URL for .ts and .m3u8")
    func liveStreamURL() throws {
        let client = XtreamClient(credentials: try credentials("http://panel:8080"))
        let stream = try decode(XtreamLiveStream.self, #"{"name":"BBC One","stream_id":42}"#)
        #expect(client.streamURL(for: stream).absoluteString == "http://panel:8080/live/u/p/42.ts")
        #expect(client.streamURL(for: stream, container: .m3u8).absoluteString.hasSuffix("42.m3u8"))
    }

    @Test("0003/AC-5 guide URL")
    func guideURL() throws {
        let client = XtreamClient(credentials: try credentials("http://panel:8080"))
        #expect(client.xmltvURL().absoluteString == "http://panel:8080/xmltv.php?username=u&password=p")
    }

    @Test("0003/AC-6 channel mapping")
    func channelMapping() throws {
        let client = XtreamClient(credentials: try credentials("http://panel:8080"))
        let stream = try decode(
            XtreamLiveStream.self,
            #"{"stream_id":42,"name":"BBC One","num":7,"stream_icon":"","epg_channel_id":"","tv_archive":1,"tv_archive_duration":3}"#)
        let channel = client.channel(from: stream, categoryName: "UK")
        #expect(channel.id == "xtream#panel#42")
        #expect(channel.name == "BBC One")
        #expect(channel.number == 7)
        #expect(channel.group == "UK")
        #expect(channel.epgID == nil)
        #expect(channel.logoURL == nil)
        #expect(channel.hasCatchup)
        #expect(channel.catchupDays == 3)
    }

    enum Endpoint: String, CaseIterable, Sendable { case liveCategories, liveStreams, accountInfo }

    @Test("0003/AC-7 non-2xx response is a typed error", arguments: Endpoint.allCases)
    func nonSuccessStatus(endpoint: Endpoint) async throws {
        let host = "ac7-\(endpoint.rawValue.lowercased()).panel"
        let client = try stubbedClient(host: host, status: 403, body: "Forbidden")
        await #expect {
            switch endpoint {
            case .liveCategories: _ = try await client.liveCategories()
            case .liveStreams: _ = try await client.liveStreams()
            case .accountInfo: _ = try await client.accountInfo()
            }
        } throws: { error in
            guard case XtreamClient.XtreamError.badStatus(let code) = error else { return false }
            return code == 403
        }
    }

    @Test("0003/AC-8 malformed JSON throws a DecodingError")
    func malformedJSON() async throws {
        let client = try stubbedClient(host: "ac8.panel", status: 200, body: "<html><body>Please log in</body></html>")
        await #expect(throws: DecodingError.self) {
            _ = try await client.liveStreams()
        }
    }

    @Test("0003/AC-9 account info decodes loose types")
    func accountInfoLooseTypes() throws {
        let info = try decode(
            XtreamAccountInfo.self,
            #"{"user_info":{"username":"u","exp_date":1767225600,"max_connections":"2"}}"#)
        #expect(info.userInfo.expDate == "1767225600")
        #expect(info.userInfo.maxConnections == "2")
    }

    @Test("0003/AC-10 ids are stable per server and stream")
    func stableIDs() throws {
        let client = XtreamClient(credentials: try credentials("http://panel:8080"))
        let first = try decode(XtreamLiveStream.self, #"{"name":"A","stream_id":42}"#)
        let again = try decode(XtreamLiveStream.self, #"{"name":"A","stream_id":"42"}"#)
        let other = try decode(XtreamLiveStream.self, #"{"name":"B","stream_id":43}"#)

        #expect(client.channel(from: first, categoryName: nil).id == client.channel(from: again, categoryName: nil).id)
        #expect(client.channel(from: first, categoryName: nil).id != client.channel(from: other, categoryName: nil).id)

        let https = XtreamClient(credentials: try credentials("https://panel:443"))
        #expect(https.channel(from: first, categoryName: nil).id == client.channel(from: first, categoryName: nil).id)
    }

    @Test func routerSplitsHLSFromTS() throws {
        #expect(EngineRouter.route(for: try #require(URL(string: "http://x/a.m3u8"))) == .system)
        #expect(EngineRouter.route(for: try #require(URL(string: "http://x/a.ts"))) == .demuxer)
        #expect(EngineRouter.route(for: try #require(URL(string: "http://x/live/u/p/42"))) == .demuxer)
    }
}

/// Answers requests per host from a registered status and body, and records each request.
/// Tests use distinct hosts so they can run in parallel.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct Stub {
        var status: Int
        var body: Data
        var requests: [URLRequest] = []
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]

    static func register(host: String, status: Int, body: Data) {
        lock.withLock { stubs[host] = Stub(status: status, body: body) }
    }

    static func requests(host: String) -> [URLRequest] {
        lock.withLock { stubs[host]?.requests ?? [] }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let stub: Stub? = Self.lock.withLock {
            Self.stubs[host]?.requests.append(request)
            return Self.stubs[host]
        }
        guard let stub, let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
