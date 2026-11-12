import Foundation
import Testing

@testable import AntennaCore

/// A Channels DVR server on a stubbed session, answering by path.
struct FakeChannelsDVR {
    let host: String
    let client: ChannelsDVRClient

    init(
        host: String, credential: HTTPBasicCredential? = nil,
        handler: @escaping @Sendable (_ path: String, URLRequest) -> StalkerStubProtocol.Reply
    ) throws {
        self.host = host
        StalkerStubProtocol.register(host: host) { request in handler(request.url?.path() ?? "", request) }
        let configuration = URLSessionConfiguration.channelsDVR
        configuration.protocolClasses = [StalkerStubProtocol.self]
        client = ChannelsDVRClient(
            server: try #require(ChannelsDVRClient.serverURL(from: host)), credential: credential,
            session: URLSession(configuration: configuration))
    }

    var requests: [URLRequest] { StalkerStubProtocol.requests(host: host) }

    static let status = #"{"version":"2022.08.16.2108","prerelease":true,"booted":true,"subscription":"active"}"#

    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/ChannelsDVR"))
        return try Data(contentsOf: url)
    }
}

@Suite struct ChannelsDVRStatusTests {
    @Test("channels-dvr-source/connect-says-what-it-found decodes a full and a short status")
    func decodesStatus() throws {
        let full = try ChannelsDVRClient.decodeStatus(Data(FakeChannelsDVR.status.utf8))
        #expect(full.versionText == "2022.08.16.2108")
        #expect(full.version == ChannelsDVRVersion(year: 2022, month: 8, day: 16, build: 2108))
        #expect(full.prerelease == true && full.booted == true && full.subscription == "active")
        let short = try ChannelsDVRClient.decodeStatus(Data(#"{"version":"2025.03.01.0012"}"#.utf8))
        #expect(short.prerelease == nil && short.booted == nil && short.subscription == nil)
        let dev = try ChannelsDVRClient.decodeStatus(Data(#"{"version":"2025.03.01.0012-dev"}"#.utf8))
        #expect(dev.versionText == "2025.03.01.0012-dev" && dev.version?.build == 12)
        let custom = try ChannelsDVRClient.decodeStatus(Data(#"{"version":"custom"}"#.utf8))
        #expect(custom.versionText == "custom" && custom.version == nil)
    }

    @Test(
        "channels-dvr-source/connect-says-what-it-found not a Channels DVR status",
        arguments: ["{}", "[]", #""2022.08.16""#, #"{"ver":"1"}"#, #"{"version":123}"#, "<html><body>Router</body></html>", ""])
    func notAStatus(body: String) {
        #expect(throws: ChannelsDVRError.notAChannelsServer) { try ChannelsDVRClient.decodeStatus(Data(body.utf8)) }
    }

    enum Expected: Sendable { case accepted, failed(ChannelsDVRError) }

    struct Row: Sendable {
        var name: String
        var reply: StalkerStubProtocol.Reply
        var expected: Expected

        init(_ name: String, _ reply: StalkerStubProtocol.Reply, _ expected: Expected) {
            self.name = name
            self.reply = reply
            self.expected = expected
        }
    }

    static let outcomes: [Row] = [
        Row("working", .http(200, FakeChannelsDVR.status), .accepted),
        Row("starting", .http(200, #"{"version":"2022.08.16.2108","booted":false}"#), .failed(.starting)),
        Row("odd version", .http(200, #"{"version":"nightly"}"#), .accepted),
        Row("a web page", .http(200, "<html>router</html>"), .failed(.notAChannelsServer)),
        Row("booted false only", .http(200, #"{"booted":false}"#), .failed(.notAChannelsServer)),
        Row("404", .http(404, "not found"), .failed(.notAChannelsServer)),
        Row("401", .http(401, ""), .failed(.unauthorized)),
        Row("403", .http(403, ""), .failed(.unauthorized)),
        Row("500", .http(500, ""), .failed(.httpStatus(500))),
        Row("503", .http(503, ""), .failed(.httpStatus(503))),
        Row("no network", .failure(.notConnectedToInternet), .failed(.offline)),
        Row("connection lost", .failure(.networkConnectionLost), .failed(.offline)),
        Row("refused", .failure(.cannotConnectToHost), .failed(.unreachable(.cannotConnectToHost))),
        Row("no such host", .failure(.cannotFindHost), .failed(.unreachable(.cannotFindHost))),
        Row("timed out", .failure(.timedOut), .failed(.unreachable(.timedOut))),
        Row("TLS", .failure(.secureConnectionFailed), .failed(.transport(.secureConnectionFailed))),
    ]

    @Test("channels-dvr-source/connect-says-what-it-found each outcome of the status check", arguments: outcomes.indices)
    func statusOutcome(index: Int) async throws {
        let row = Self.outcomes[index]
        let (name, reply, expected) = (row.name, row.reply, row.expected)
        let server = try FakeChannelsDVR(host: "status-\(index).dvr.test") { _, _ in reply }
        switch expected {
        case .accepted:
            let status = try await server.client.status()
            #expect(!status.versionText.isEmpty, "\(name)")
        case .failed(let error):
            await #expect(throws: error, "\(name)") { try await server.client.status() }
        }
        #expect(server.requests.count == 1)
        #expect(server.requests.first?.url?.path() == "/status")
        #expect(server.requests.first?.timeoutInterval == 10)
    }

    @Test("channels-dvr-source/connect-says-what-it-found a sleeping server fails this load and the next tries again")
    func sleepingServer() async throws {
        let calls = Counter()
        let server = try FakeChannelsDVR(host: "sleepy.dvr.test") { _, _ in
            calls.next() == 0 ? .failure(.timedOut) : .http(200, FakeChannelsDVR.status)
        }
        await #expect(throws: ChannelsDVRError.unreachable(.timedOut)) { try await server.client.status() }
        #expect(try await server.client.status().versionText == "2022.08.16.2108")
    }

    @Test("channels-dvr-source/connect-says-what-it-found a remote-access login page fails as not a server")
    func loginPage() async throws {
        let server = try FakeChannelsDVR(host: "remote.dvr.test") { path, _ in
            path == "/status" ? .redirect("http://remote.dvr.test/login") : .http(200, "<html><form>Sign in</form></html>")
        }
        await #expect(throws: ChannelsDVRError.notAChannelsServer) { try await server.client.status() }
    }

    @Test("channels-dvr-source/connect-says-what-it-found cancellation is not a Channels DVR error")
    func cancellation() async throws {
        let server = try FakeChannelsDVR(host: "hang.dvr.test") { _, _ in .hang }
        let task = Task { try await server.client.status() }
        while server.requests.isEmpty { await Task.yield() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("channels-dvr-source/reach-a-remote-server-behind-a-password sends the credential with every request, or none")
    func credentialOnEveryRequest() async throws {
        let credential = try #require(HTTPBasicCredential(username: "alice", password: "pa:ss"))
        let lineup = String(decoding: try FakeChannelsDVR.fixture("channels.m3u"), as: UTF8.self)
        let handler: @Sendable (String, URLRequest) -> StalkerStubProtocol.Reply = { path, _ in
            path == "/status" ? .http(200, FakeChannelsDVR.status) : .http(200, lineup)
        }
        let remote = try FakeChannelsDVR(host: "proxy.dvr.test", credential: credential, handler: handler)
        _ = try await remote.client.status()
        _ = try await remote.client.channels()
        let expected = "Basic " + Data("alice:pa:ss".utf8).base64EncodedString()
        #expect(remote.requests.count == 2)
        #expect(remote.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == expected })

        let home = try FakeChannelsDVR(host: "home.dvr.test", handler: handler)
        _ = try await home.client.status()
        _ = try await home.client.channels()
        #expect(home.requests.count == 2)
        #expect(home.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }
}

/// Counts calls across the stub's threads.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            defer { value += 1 }
            return value
        }
    }
}
