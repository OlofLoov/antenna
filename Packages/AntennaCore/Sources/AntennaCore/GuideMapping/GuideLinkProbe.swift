import Foundation

/// Reads the start of a typed guide link before it is saved, and refuses it
/// only when it is plainly not a guide
/// (guide-sources-and-channel-mapping/add-a-guide-link). Anything it cannot
/// decide, offline and slow servers included, is left for the download to
/// report. The link may hold a login, so nothing here logs it.
public struct GuideLinkProbe: Sendable {
    /// What the start of the link says.
    public enum Verdict: Sendable, Equatable {
        /// XMLTV or gzip.
        case guide
        /// No answer in time, no connection, a server error, or bytes that
        /// cannot decide. The link is saved.
        case uncertain
        /// Plainly not a guide. The link is not saved.
        case refused(GuideLinkInput.Problem)
    }

    /// The status code and up to the first few kilobytes of the body. The
    /// body may be empty when the status is not 2xx.
    public typealias Fetch = @Sendable (URL) async throws -> (status: Int, head: Data)

    public var timeout: Duration
    public var fetch: Fetch

    public init(timeout: Duration = .seconds(5), fetch: @escaping Fetch = GuideLinkProbe.live()) {
        self.timeout = timeout
        self.fetch = fetch
    }

    /// The verdict for `url`, within `timeout`.
    public func check(_ url: URL) async -> Verdict {
        let fetch = fetch
        let timeout = timeout
        return await withTaskGroup(of: Verdict?.self) { group in
            group.addTask {
                guard let (status, head) = try? await fetch(url) else { return .uncertain }
                return Self.classify(status: status, head: head)
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first ?? .uncertain
        }
    }

    /// Reads at most `limit` bytes with a session set up like guide
    /// downloads, then stops the request.
    public static func live(session: URLSession = probeSession, limit: Int = 4096) -> Fetch {
        { url in
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            let (bytes, response) = try await session.bytes(for: request)
            defer { bytes.task.cancel() }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            var head = Data()
            guard (200..<300).contains(status) else { return (status, head) }
            for try await byte in bytes {
                head.append(byte)
                if head.count >= limit { break }
            }
            return (status, head)
        }
    }

    /// The guide download configuration with a short request timeout.
    public static let probeSession: URLSession = {
        let configuration = URLSessionConfiguration.guide
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    /// 404 and 410 are not found, 401 and 403 refused, any other non-2xx
    /// uncertain. A 2xx body is a guide when, after a byte order mark and
    /// whitespace, it starts with gzip's magic bytes, `<?xml`, `<tv` or
    /// `<!DOCTYPE tv`; a web page when it starts with `<!DOCTYPE html` or
    /// `<html`; uncertain when it is empty, starts with a comment or is cut
    /// off before it can tell; and otherwise not a guide.
    static func classify(status: Int, head: Data) -> Verdict {
        switch status {
        case 404, 410: return .refused(.notFound)
        case 401, 403: return .refused(.unauthorized)
        case 200..<300: break
        default: return .uncertain
        }
        var bytes = head[...]
        if bytes.starts(with: [0xef, 0xbb, 0xbf]) { bytes = bytes.dropFirst(3) }
        if bytes.starts(with: [0x1f, 0x8b]) { return .guide }
        bytes = bytes.drop { [0x20, 0x09, 0x0a, 0x0d].contains($0) }
        guard !bytes.isEmpty else { return .uncertain }
        let start = String(decoding: bytes.prefix(16), as: UTF8.self).lowercased()
        let guides = ["<?xml", "<tv>", "<tv ", "<tv\n", "<tv\r", "<tv\t", "<!doctype tv"]
        let pages = ["<!doctype html", "<html"]
        if guides.contains(where: start.hasPrefix) { return .guide }
        if pages.contains(where: start.hasPrefix) { return .refused(.webPage) }
        if start.hasPrefix("<!--") { return .uncertain }
        let cutOff = bytes.count < 16 && (guides + pages).contains { $0.hasPrefix(start) }
        return cutOff ? .uncertain : .refused(.notGuide)
    }
}
