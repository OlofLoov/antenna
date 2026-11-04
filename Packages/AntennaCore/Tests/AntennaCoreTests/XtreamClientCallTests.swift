import Foundation
import Testing

@testable import AntennaCore

/// The nine `player_api.php` calls, so criteria can be parameterised over them.
enum XtreamCall: String, CaseIterable, Sendable {
    case liveCategories, liveStreams, accountInfo, vodCategories, vodStreams, vodInfo, seriesCategories, series, seriesInfo

    /// Runs the call. `withID` passes a category or title id where the call takes one.
    func run(on client: XtreamClient, withID: Bool = false) async throws {
        switch self {
        case .liveCategories: _ = try await client.liveCategories()
        case .liveStreams: _ = try await client.liveStreams(categoryID: withID ? "3" : nil)
        case .accountInfo: _ = try await client.accountInfo()
        case .vodCategories: _ = try await client.vodCategories()
        case .vodStreams: _ = try await client.vodStreams(categoryID: withID ? "3" : nil)
        case .vodInfo: _ = try await client.vodInfo(streamID: 55)
        case .seriesCategories: _ = try await client.seriesCategories()
        case .series: _ = try await client.series(categoryID: withID ? "3" : nil)
        case .seriesInfo: _ = try await client.seriesInfo(seriesID: 7)
        }
    }

    /// The query after `action=`, as AC-1 states it, for a run with and without an id.
    func expectedTail(withID: Bool) -> String? {
        switch self {
        case .accountInfo: nil
        case .liveCategories: "action=get_live_categories"
        case .vodCategories: "action=get_vod_categories"
        case .seriesCategories: "action=get_series_categories"
        case .liveStreams: "action=get_live_streams" + (withID ? "&category_id=3" : "")
        case .vodStreams: "action=get_vod_streams" + (withID ? "&category_id=3" : "")
        case .series: "action=get_series" + (withID ? "&category_id=3" : "")
        case .vodInfo: "action=get_vod_info&vod_id=55"
        case .seriesInfo: "action=get_series_info&series_id=7"
        }
    }

    /// A 200 body each call accepts.
    var okBody: String {
        switch self {
        case .accountInfo, .vodInfo, .seriesInfo: #"{"user_info":{"auth":1}}"#
        default: "[]"
        }
    }
}

@Suite struct XtreamClientCallTests {
    private func client(host: String, reply: StubURLProtocol.Reply, username: String = "u", password: String = "p") throws
        -> XtreamClient
    {
        StubURLProtocol.register(host: host, reply: reply)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let server = try #require(URL(string: "http://\(host):8080"))
        return XtreamClient(
            credentials: XtreamCredentials(server: server, username: username, password: password),
            session: URLSession(configuration: configuration))
    }

    @Test("0016/AC-1 request shape with reserved characters in the password", arguments: XtreamCall.allCases, [false, true])
    func requestShape(call: XtreamCall, withID: Bool) async throws {
        let host = "ac1-\(call.rawValue.lowercased())-\(withID).panel"
        let client = try client(host: host, reply: .http(200, Data(call.okBody.utf8)), username: "alice-7f3e", password: "a&b/c+d")
        try await call.run(on: client, withID: withID)

        let requests = StubURLProtocol.requests(host: host)
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        let url = try #require(request.url)
        #expect(request.httpMethod == "GET")
        #expect(url.path() == "/player_api.php")
        let credentials = "username=alice-7f3e&password=a%26b%2Fc%2Bd"
        #expect(
            url.query(percentEncoded: true) == [credentials, call.expectedTail(withID: withID)].compactMap { $0 }.joined(separator: "&"))
    }

    @Test("0016/AC-1 guide URL encodes credentials the same way")
    func guideURL() throws {
        let server = try #require(URL(string: "http://h:8080"))
        let client = XtreamClient(credentials: XtreamCredentials(server: server, username: "alice-7f3e", password: "a&b/c+d"))
        #expect(client.xmltvURL().absoluteString == "http://h:8080/xmltv.php?username=alice-7f3e&password=a%26b%2Fc%2Bd")
    }

    @Test(
        "0016/AC-4b category lists fail whole with the coding path",
        arguments: [XtreamCall.vodCategories, .seriesCategories, .liveCategories])
    func categoryListFailsWhole(call: XtreamCall) async throws {
        let body = #"[{"category_id":1,"category_name":"A"},{"category_id":2},{"category_id":3,"category_name":"C"}]"#
        let client = try client(host: "ac4b-\(call.rawValue.lowercased()).panel", reply: .http(200, Data(body.utf8)))
        await #expect(throws: XtreamClient.XtreamError.decoding(path: "[1].category_name")) { try await call.run(on: client) }
    }

    @Test("0016/AC-4b no call lets DecodingError escape on an HTML body", arguments: XtreamCall.allCases)
    func htmlBody(call: XtreamCall) async throws {
        let client = try client(
            host: "ac4b-html-\(call.rawValue.lowercased()).panel", reply: .http(200, try xtreamFixture("html_login.html")))
        await #expect(throws: XtreamClient.XtreamError.decoding(path: "")) { try await call.run(on: client) }
    }

    @Test("0016/AC-12 whole-fail lists accept the empty shapes", arguments: [("object", "{}"), ("false", "false"), ("null", "null")])
    func wholeListEmptyShapes(name: String, body: String) async throws {
        let client = try client(host: "ac12-\(name).panel", reply: .http(200, Data(body.utf8)))
        #expect(try await client.liveCategories().isEmpty)
        #expect(try await client.liveStreams().isEmpty)
        #expect(try await client.vodCategories().isEmpty)
        #expect(try await client.seriesCategories().isEmpty)
    }

    static let transportCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut, .cannotFindHost, .secureConnectionFailed,
    ]

    @Test("0016/AC-10 transport failures carry the code and no URL", arguments: XtreamCall.allCases, transportCodes)
    func transportFailure(call: XtreamCall, code: URLError.Code) async throws {
        let host = "ac10-\(call.rawValue.lowercased())-\(-code.rawValue).panel"
        let client = try client(host: host, reply: .failure(code), username: "alice-7f3e", password: "s3cr3t-9b2a")
        let error = await #expect(throws: XtreamClient.XtreamError.self) { try await call.run(on: client) }
        #expect(error == .transport(code))
        let texts = [String(reflecting: try #require(error)), String(describing: (try #require(error) as NSError).userInfo)]
        for text in texts {
            #expect(!text.contains(host))
            #expect(!text.contains("alice-7f3e"))
            #expect(!text.contains("s3cr3t-9b2a"))
        }
    }

    @Test("0016/AC-10a cancellation throws CancellationError", .timeLimit(.minutes(1)), arguments: XtreamCall.allCases)
    func cancellation(call: XtreamCall) async throws {
        let host = "ac10a-\(call.rawValue.lowercased()).panel"
        let client = try client(host: host, reply: .hang)
        let task = Task { try await call.run(on: client) }
        while StubURLProtocol.requests(host: host).isEmpty { await Task.yield() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("0016/AC-11 401 and 403 are unauthorized", arguments: XtreamCall.allCases, [401, 403])
    func unauthorizedStatus(call: XtreamCall, status: Int) async throws {
        let client = try client(host: "ac11-\(call.rawValue.lowercased())-\(status).panel", reply: .http(status, Data("Denied".utf8)))
        await #expect(throws: XtreamClient.XtreamError.unauthorized) { try await call.run(on: client) }
    }

    @Test("0016/AC-11 other statuses stay badStatus", arguments: XtreamCall.allCases)
    func otherStatuses(call: XtreamCall) async throws {
        let name = call.rawValue.lowercased()
        let failing = try client(host: "ac11-\(name)-500.panel", reply: .http(500, Data("Oops".utf8)))
        await #expect(throws: XtreamClient.XtreamError.badStatus(500)) { try await call.run(on: failing) }
        let plain = try client(host: "ac11-\(name)-plain.panel", reply: .plain(Data(call.okBody.utf8)))
        await #expect(throws: XtreamClient.XtreamError.badStatus(-1)) { try await call.run(on: plain) }
    }

    @Test(
        "0016/AC-11 auth 0 in a 200 body is unauthorized", arguments: XtreamCall.allCases,
        [#"{"user_info":{"auth":0}}"#, #" {"user_info":{"auth":"0","status":"Active"}}"#])
    func authZero(call: XtreamCall, body: String) async throws {
        let host = "ac11-\(call.rawValue.lowercased())-auth\(body.contains("\"0\"") ? "s" : "n").panel"
        let client = try client(host: host, reply: .http(200, Data(body.utf8)))
        await #expect(throws: XtreamClient.XtreamError.unauthorized) { try await call.run(on: client) }
    }

    @Test("0016/AC-11 the probe runs in the decode functions", arguments: [#"{"user_info":{"auth":0}}"#, #"{"user_info":{"auth":"0"}}"#])
    func probeInDecode(body: String) {
        #expect(throws: XtreamClient.XtreamError.unauthorized) { _ = try XtreamClient.decodeVODList(Data(body.utf8), host: "h") }
    }

    @Test("0016/AC-11 array bodies are never probed")
    func arrayNotProbed() throws {
        let list = try XtreamClient.decodeVODList(Data(#"[{"user_info":{"auth":0}}]"#.utf8), host: "h")
        #expect(list == XtreamClient.DecodedList(items: [], skipped: 1))
    }

    static let authBodies = [
        "one": #"{"auth":1}"#, "onestring": #"{"auth":"1"}"#, "yes": #"{"auth":"yes"}"#, "null": #"{"auth":null}"#, "absent": "{}",
    ]

    @Test(
        "0016/AC-11 user_info.auth decodes loosely",
        arguments: [("one", 1), ("onestring", 1), ("yes", nil), ("null", nil), ("absent", nil)] as [(String, Int?)])
    func authField(name: String, expected: Int?) async throws {
        let userInfo = try #require(Self.authBodies[name])
        let client = try client(host: "ac11-auth-\(name).panel", reply: .http(200, Data("{\"user_info\":\(userInfo)}".utf8)))
        #expect(try await client.accountInfo().userInfo.auth == expected)
    }
}
