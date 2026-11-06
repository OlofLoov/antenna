import Foundation

/// One short look at a stream before an engine opens it: the status, the
/// first bytes and whether the server can skip. Both engines probe the same
/// way, so the same cause gives the same `PlaybackFailure` on either path.
public struct StreamProbe: Sendable, Equatable {
    public var status: Int
    public var contentType: String?
    /// True when the server answered the byte range or says it accepts ranges.
    public var acceptsRanges: Bool
    public var sniff: StreamSniff

    /// How many bytes a probe reads before it lets the connection go.
    public static let headSize = 2048

    public init(status: Int, contentType: String?, acceptsRanges: Bool, sniff: StreamSniff) {
        self.status = status
        self.contentType = contentType
        self.acceptsRanges = acceptsRanges
        self.sniff = sniff
    }

    /// Asks for the first bytes of `url` and closes the connection once it
    /// has them. Throws a `PlaybackFailure` for a refusal or a network
    /// error, and `CancellationError` when cancelled.
    public static func run(_ url: URL, session: URLSession) async throws -> StreamProbe {
        try StreamAddress.check(url)
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(headSize - 1)", forHTTPHeaderField: "Range")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = false
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            if error.code == .cancelled, Task.isCancelled { throw CancellationError() }
            throw PlaybackFailure(error, host: url.host())
        }
        guard let http = response as? HTTPURLResponse else { throw PlaybackFailure.unreadable }
        if let failure = PlaybackFailure(httpStatus: http.statusCode) {
            bytes.task.cancel()
            throw failure
        }
        var head = Data()
        head.reserveCapacity(headSize)
        do {
            for try await byte in bytes {
                head.append(byte)
                if head.count >= headSize { break }
            }
        } catch let error as URLError {
            if error.code == .cancelled, Task.isCancelled { throw CancellationError() }
            if head.isEmpty { throw PlaybackFailure(error, host: url.host()) }
        }
        bytes.task.cancel()
        try Task.checkCancellation()
        let ranges = http.statusCode == 206 || http.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        return StreamProbe(
            status: http.statusCode, contentType: http.value(forHTTPHeaderField: "Content-Type"), acceptsRanges: ranges,
            sniff: StreamSniff(head))
    }
}

/// The network setup both engines fetch streams through.
public enum PlaybackNetwork {
    /// How long a stream may take to answer before it fails as timed out.
    public static let connectTimeout = Duration.seconds(8)

    /// An ephemeral session with no cache, no cookies and no credential
    /// store, so nothing about a stream address is kept on disk.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = Double(connectTimeout.components.seconds)
        return URLSession(configuration: configuration)
    }
}
