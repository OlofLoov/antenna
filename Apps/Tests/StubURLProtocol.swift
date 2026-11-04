import Foundation

/// Answers requests from a canned table keyed by host and the `action` query
/// item, so one Xtream host can serve categories and streams differently.
/// A host with no entry fails with `URLError(.cannotFindHost)`. Every request
/// is recorded per host and per session tag, answered or not. Give each test
/// its own host and tag.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct Response {
        var status: Int
        var body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Response] = [:]
    nonisolated(unsafe) private static var recorded: [String: [URLRequest]] = [:]
    nonisolated(unsafe) private static var tagged: [String: Int] = [:]
    private static let tagHeader = "X-Stub-Tag"

    static func register(host: String, action: String? = nil, status: Int = 200, body: String) {
        lock.withLock { responses[key(host, action)] = Response(status: status, body: Data(body.utf8)) }
    }

    static func requests(host: String) -> [URLRequest] {
        lock.withLock { recorded[host] ?? [] }
    }

    /// How many requests a session made with `session(tag:)` has sent.
    static func requestCount(tag: String) -> Int {
        lock.withLock { tagged[tag] ?? 0 }
    }

    /// A session whose every request goes through this stub, counted under `tag`.
    static func session(tag: String = "") -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [tagHeader: tag]
        return URLSession(configuration: configuration)
    }

    private static func key(_ host: String, _ action: String?) -> String {
        "\(host)|\(action ?? "")"
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "action" }?.value
        let response: Response? = Self.lock.withLock {
            Self.recorded[host, default: []].append(request)
            if let tag = request.value(forHTTPHeaderField: Self.tagHeader) { Self.tagged[tag, default: 0] += 1 }
            return Self.responses[Self.key(host, action)]
        }
        guard let response,
            let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
