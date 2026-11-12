import Foundation
import Testing

@testable import AntennaCore

/// Answers Stalker requests from a handler registered per host and records
/// every request in order. Give each test its own host.
final class StalkerStubProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case http(Int, String)
        case redirect(String)
        case failure(URLError.Code)
        /// Never answers until the task is cancelled.
        case hang
    }

    typealias Handler = @Sendable (URLRequest) -> Reply

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var recorded: [String: [URLRequest]] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock {
            handlers[host] = handler
            recorded[host] = []
        }
    }

    static func requests(host: String) -> [URLRequest] {
        lock.withLock { recorded[host] ?? [] }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.stalker
        configuration.protocolClasses = [StalkerStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let handler = Self.lock.withLock {
            Self.recorded[host, default: []].append(request)
            return Self.handlers[host]
        }
        switch handler?(request) {
        case .http(let status, let body):
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .redirect(let location):
            guard let target = URL(string: location),
                let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": location])
            else { return }
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code, userInfo: [NSURLErrorFailingURLErrorKey: url]))
        case .hang:
            break
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
        }
    }

    override func stopLoading() {}
}

/// A scripted portal: answers by `action`, and counts calls per action.
final class FakePortal: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var tokenNumber = 0
    /// Answers for `action`, given how many times it was asked before.
    private var scripts: [String: @Sendable (Int, URLRequest) -> StalkerStubProtocol.Reply] = [:]
    /// The path the API answers under.
    let apiPath: String

    init(apiPath: String = "/stalker_portal/server/load.php") {
        self.apiPath = apiPath
    }

    func on(_ action: String, _ reply: @escaping @Sendable (Int, URLRequest) -> StalkerStubProtocol.Reply) {
        lock.withLock { scripts[action] = reply }
    }

    func count(_ action: String) -> Int {
        lock.withLock { counts[action] ?? 0 }
    }

    /// The default answers: a fresh token per handshake, an empty profile,
    /// `do_auth` true, and `{"js":[]}` for anything else.
    func handle(_ request: URLRequest) -> StalkerStubProtocol.Reply {
        guard let url = request.url, url.path() == apiPath else { return .http(404, "<html>not found</html>") }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value ?? ""
        let (index, script): (Int, (@Sendable (Int, URLRequest) -> StalkerStubProtocol.Reply)?) = lock.withLock {
            let index = counts[action] ?? 0
            counts[action] = index + 1
            return (index, scripts[action])
        }
        if let script { return script(index, request) }
        switch action {
        case "handshake":
            let token = lock.withLock {
                tokenNumber += 1
                return "T\(tokenNumber)"
            }
            return .http(200, #"{"js":{"token":"\#(token)","random":"r-42"}}"#)
        case "get_profile": return .http(200, #"{"js":{"id":"1","status":0}}"#)
        case "do_auth": return .http(200, #"{"js":true}"#)
        default: return .http(200, #"{"js":[]}"#)
        }
    }

    /// Registers this portal under `host` and returns a client for it.
    func client(
        host: String, portal: String? = nil, mac: String = "00:1A:79:12:34:56", password: String = "", login: String? = nil,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> StalkerClient {
        StalkerStubProtocol.register(host: host) { [self] in handle($0) }
        let address = try #require(StalkerPortal(portal ?? "http://\(host)/c/"))
        let credentials = StalkerCredentials(portal: address, mac: try #require(MACAddress(mac)), password: password, login: login)
        return StalkerClient(
            credentials: credentials, session: StalkerStubProtocol.session(),
            timeZone: try #require(TimeZone(identifier: "Europe/Stockholm")),
            now: { now })
    }
}

extension URLRequest {
    /// The decoded query items in order.
    var queryPairs: [String] {
        guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [] }
        return items.map { "\($0.name)=\($0.value ?? "")" }
    }

    var action: String? {
        guard let url else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value
    }

    var bearer: String? {
        value(forHTTPHeaderField: "Authorization")
    }
}
