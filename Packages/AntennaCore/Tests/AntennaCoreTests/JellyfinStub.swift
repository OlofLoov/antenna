import Foundation
import Testing

@testable import AntennaCore

/// The contents of `Fixtures/Jellyfin/<name>`.
func jellyfinFixture(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Jellyfin") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

/// Answers Jellyfin requests from a handler registered per host and records
/// every request, body included, in order. Give each test its own host.
final class JellyfinStubProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case http(Int, Data)
        case failure(URLError.Code)
    }

    struct Recorded: Sendable {
        var request: URLRequest
        var body: Data

        var path: String { request.url?.path() ?? "" }
        var authorization: String? { request.value(forHTTPHeaderField: "Authorization") }
        var json: [String: Any]? { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] }
        var query: [String: String] {
            guard let url = request.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
            return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        }
    }

    typealias Handler = @Sendable (Recorded) -> Reply

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var recorded: [String: [Recorded]] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock {
            handlers[host] = handler
            recorded[host] = []
        }
    }

    static func requests(host: String) -> [Recorded] {
        lock.withLock { recorded[host] ?? [] }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JellyfinStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let entry = Recorded(request: request, body: Self.body(of: request))
        let handler = Self.lock.withLock {
            Self.recorded[host, default: []].append(entry)
            return Self.handlers[host]
        }
        switch handler?(entry) {
        case .http(let status, let body):
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code, userInfo: [NSURLErrorFailingURLErrorKey: url]))
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
        }
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// A scripted Jellyfin server. It hands out a fresh key per sign-in, turns
/// down any key it did not hand out or has revoked, and serves `channelCount`
/// generated channels and one programme per asked-for channel.
final class FakeJellyfin: @unchecked Sendable {
    typealias Script = @Sendable (_ index: Int, _ request: JellyfinStubProtocol.Recorded) -> JellyfinStubProtocol.Reply?

    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var scripts: [String: Script] = [:]
    private var issued = 0
    private var valid: Set<String> = []
    var password = "s3cret"
    var channelCount = 3
    /// The total the channel pages report; nil leaves it out.
    var reportedTotal: Int??
    let userID = "user-1"

    /// Overrides the answer for requests whose path ends in `path`. A nil
    /// reply falls back to the default answer.
    func on(_ path: String, _ script: @escaping Script) {
        lock.withLock { scripts[path] = script }
    }

    func count(_ path: String) -> Int {
        lock.withLock { counts[path] ?? 0 }
    }

    /// Turns down every key handed out so far.
    func revokeAll() {
        lock.withLock { valid.removeAll() }
    }

    func isValid(_ token: String) -> Bool {
        lock.withLock { valid.contains(token) }
    }

    func handle(_ recorded: JellyfinStubProtocol.Recorded) -> JellyfinStubProtocol.Reply {
        let endpoint = ["System/Info/Public", "Users/AuthenticateByName", "LiveTv/Channels", "LiveTv/Programs"].first {
            recorded.path.hasSuffix("/" + $0)
        }
        guard let endpoint else { return .http(404, Data("<html>not found</html>".utf8)) }
        let (index, script) = lock.withLock {
            let index = counts[endpoint] ?? 0
            counts[endpoint] = index + 1
            return (index, scripts[endpoint])
        }
        if let reply = script?(index, recorded) { return reply }
        switch endpoint {
        case "System/Info/Public":
            return .http(200, (try? jellyfinFixture("server-info.json")) ?? Data())
        case "Users/AuthenticateByName":
            guard recorded.json?["Pw"] as? String == password else { return .http(401, Data()) }
            let token = lock.withLock {
                issued += 1
                valid.insert("K\(issued)")
                return "K\(issued)"
            }
            let body = #"{"User":{"Id":"\#(userID)"},"AccessToken":"\#(token)","ServerId":"server-1"}"#
            return .http(200, Data(body.utf8))
        default:
            guard let token = Self.token(recorded.authorization), isValid(token) else { return .http(401, Data()) }
            return endpoint == "LiveTv/Channels" ? channelPage(recorded) : programmePage(recorded)
        }
    }

    private func channelPage(_ recorded: JellyfinStubProtocol.Recorded) -> JellyfinStubProtocol.Reply {
        let start = Int(recorded.query["StartIndex"] ?? "") ?? 0
        let limit = Int(recorded.query["Limit"] ?? "") ?? 100
        let end = min(start + limit, channelCount)
        let rows = (start..<max(start, end)).map { #"{"Name":"Channel \#($0)","Id":"ch-\#($0)","ChannelNumber":"\#($0 + 1)"}"# }
        let total = reportedTotal ?? .some(channelCount)
        let tail = total.map { #","TotalRecordCount":\#($0)"# } ?? ""
        return .http(200, Data(#"{"Items":[\#(rows.joined(separator: ","))]\#(tail)}"#.utf8))
    }

    private func programmePage(_ recorded: JellyfinStubProtocol.Recorded) -> JellyfinStubProtocol.Reply {
        let ids = recorded.json?["ChannelIds"] as? [String] ?? []
        let rows = ids.map {
            #"{"Name":"On \#($0)","ChannelId":"\#($0)","Id":"p-\#($0)","StartDate":"2026-11-12T11:00:00Z","EndDate":"2026-11-12T13:00:00Z"}"#
        }
        return .http(200, Data(#"{"Items":[\#(rows.joined(separator: ","))],"TotalRecordCount":\#(rows.count)}"#.utf8))
    }

    /// The `Token="…"` value of a MediaBrowser header.
    static func token(_ header: String?) -> String? {
        guard let header, let range = header.range(of: #"Token=""#) else { return nil }
        let rest = header[range.upperBound...]
        return rest.firstIndex(of: "\"").map { String(rest[..<$0]) }
    }

    /// Registers this server under `host` and returns a client for it.
    func client(
        host: String, server: String? = nil, username: String = "alice", password: String? = nil,
        store: any JellyfinSessionStore = JellyfinMemorySessionStore()
    ) throws -> JellyfinClient {
        JellyfinStubProtocol.register(host: host) { [self] in handle($0) }
        let url = try #require(URL(string: server ?? "http://\(host):8096"))
        return JellyfinClient(
            credentials: JellyfinCredentials(server: url, username: username, password: password ?? self.password),
            device: JellyfinDevice(id: "device-1", name: "iPhone", appVersion: "1.0"), sessionStore: store,
            session: JellyfinStubProtocol.session())
    }
}

/// A session store that counts each use and can be made to fail.
actor CountingSessionStore: JellyfinSessionStore {
    struct Failure: Error {}

    private(set) var session: JellyfinSession?
    private(set) var loads = 0
    private(set) var saves = 0
    private(set) var clears = 0
    var failLoads = false

    init(_ session: JellyfinSession? = nil) {
        self.session = session
    }

    func failLoading() { failLoads = true }

    func load() throws -> JellyfinSession? {
        loads += 1
        if failLoads { throw Failure() }
        return session
    }

    func save(_ session: JellyfinSession) {
        saves += 1
        self.session = session
    }

    func clear() {
        clears += 1
        session = nil
    }
}
