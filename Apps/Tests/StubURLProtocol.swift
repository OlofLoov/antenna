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
    nonisolated(unsafe) private static var failures: [String: URLError.Code] = [:]
    nonisolated(unsafe) private static var tagged: [String: Int] = [:]
    nonisolated(unsafe) private static var order: [String: [String]] = [:]

    private static let tagHeader = "X-Stub-Tag"

    static func register(host: String, action: String? = nil, status: Int = 200, body: String) {
        lock.withLock { responses[key(host, action)] = Response(status: status, body: Data(body.utf8)) }
    }

    /// Makes every request to `host` fail with `code`, as when offline.
    static func fail(host: String, with code: URLError.Code) {
        lock.withLock { failures[host] = code }
    }

    static func requests(host: String) -> [URLRequest] {
        lock.withLock { recorded[host] ?? [] }
    }

    /// The hosts a session made with `session(tag:)` asked, in the order asked.
    static func hosts(tag: String) -> [String] {
        lock.withLock { order[tag] ?? [] }
    }

    /// Stops failing `host`.
    static func recover(host: String) {
        lock.withLock { failures[host] = nil }
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
        let (response, failure): (Response?, URLError.Code?) = Self.lock.withLock {
            Self.recorded[host, default: []].append(request)
            if let tag = request.value(forHTTPHeaderField: Self.tagHeader) {
                Self.tagged[tag, default: 0] += 1
                Self.order[tag, default: []].append(host)
            }
            return (Self.responses[Self.key(host, action)], Self.failures[host])
        }
        if let failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
            return
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
