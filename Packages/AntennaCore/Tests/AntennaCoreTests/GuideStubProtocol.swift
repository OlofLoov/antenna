import Foundation
import Testing

/// Serves guide downloads from a table keyed by host. A reply sends its body
/// in the chunks given, with the headers given; `.hang` never answers until
/// the task is cancelled. Records each request, and whether loading was
/// stopped, per host. Give each test its own hosts.
final class GuideStubProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        /// With `finish` false the body is sent and the response never
        /// ends, so the task stops only when the client cancels it.
        case http(status: Int = 200, headers: [String: String] = [:], chunks: [Data], finish: Bool = true)
        case failure(URLError.Code)
        case hang
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [String: Reply] = [:]
    nonisolated(unsafe) private static var recorded: [String: [URLRequest]] = [:]
    nonisolated(unsafe) private static var stopped: Set<String> = []

    static func register(host: String, _ reply: Reply) {
        lock.withLock { replies[host] = reply }
    }

    /// A 200 reply with `body` cut into `chunkSize` pieces and, when
    /// `contentLength` is true, a Content-Length header.
    static func register(host: String, body: Data, chunkSize: Int = 1024, contentLength: Bool = true, finish: Bool = true) {
        let chunks = stride(from: 0, to: body.count, by: chunkSize).map { body.subdata(in: $0..<min(body.count, $0 + chunkSize)) }
        register(host: host, .http(headers: contentLength ? ["Content-Length": "\(body.count)"] : [:], chunks: chunks, finish: finish))
    }

    static func requests(host: String) -> [URLRequest] {
        lock.withLock { recorded[host] ?? [] }
    }

    static func wasStopped(host: String) -> Bool {
        lock.withLock { stopped.contains(host) }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.guide
        configuration.protocolClasses = [GuideStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let reply = Self.lock.withLock {
            Self.recorded[host, default: []].append(request)
            return Self.replies[host]
        }
        switch reply {
        case .http(let status, let headers, let chunks, let finish):
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks { client?.urlProtocol(self, didLoad: chunk) }
            if finish { client?.urlProtocolDidFinishLoading(self) }
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
        }
    }

    override func stopLoading() {
        guard let host = request.url?.host() else { return }
        _ = Self.lock.withLock { Self.stopped.insert(host) }
    }
}

/// A fresh empty directory under the temporary directory.
func temporaryGuideDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "antenna-guide-tests-\(UUID().uuidString)")
}

/// The contents of `Fixtures/Guide/<name>`.
func guideFixture(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Guide") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

/// Waits up to five seconds for `condition`.
func eventually(_ condition: () async -> Bool) async throws {
    for _ in 0..<1000 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("timed out")
}
