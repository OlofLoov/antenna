import Foundation
import Network

/// A web server on 127.0.0.1 for playback tests. It serves the synthetic
/// streams in `Fixtures` (made by `scripts/make-stream-fixtures.sh`) and can
/// refuse, stall or cut a request when a test scripts it.
///
/// Every response closes its connection, so `openConnections` and
/// `peakConnections` count what a client holds at once.
///
/// A path under `/live/` serves the same files, except that a playlist there
/// is rewritten as a live playlist: a three segment window that moves on by
/// one segment every target duration and loops the fixture's segments.
public actor FixtureServer {
    /// What the server does with the next request for a path.
    public enum Behavior: Sendable, Equatable {
        /// The file, honoring a byte range.
        case serve
        /// The whole file with 200 and no `Accept-Ranges`, for a server that cannot skip.
        case ignoreRanges
        /// This status code and a short body.
        case status(Int)
        /// Close the connection without answering.
        case refuse
        /// Send the headers and this many bytes, then nothing more while the connection stays open.
        case stall(afterBytes: Int)
        /// Send the headers and this many bytes, then close the connection.
        case cut(afterBytes: Int)
        /// These bytes with this content type, in place of any file.
        case body(Data, contentType: String)
    }

    /// One request as the server received it.
    public struct Request: Sendable, Equatable {
        public var method: String
        /// The path without the query.
        public var path: String
        public var query: String?
        /// Header names lowercased.
        public var headers: [String: String]
        /// The paths of the other requests whose connections were still open
        /// when this one arrived.
        public var openAtArrival: [String] = []
    }

    public enum ServerError: Error, Equatable {
        case fixturesMissing
        case couldNotListen
    }

    /// The folder with the synthetic streams.
    public static func fixtures() throws -> URL {
        guard let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else { throw ServerError.fixturesMissing }
        return url
    }

    public nonisolated let root: URL
    public private(set) var baseURL: URL?
    public private(set) var requests: [Request] = []
    public private(set) var openConnections = 0
    public private(set) var peakConnections = 0

    private let queue = DispatchQueue(label: "se.codecrave.antenna.fixture-server")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var pathsByConnection: [ObjectIdentifier: String] = [:]
    private var scripted: [String: [Behavior]] = [:]
    private var fallback: [String: Behavior] = [:]
    private var started = ContinuousClock.now

    public init(root: URL? = nil) throws {
        self.root = try root ?? Self.fixtures()
    }

    /// Starts listening on a free port and returns `http://127.0.0.1:<port>/`.
    public func start() async throws -> URL {
        if let baseURL { return baseURL }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return connection.cancel() }
            Task { await self.accept(connection) }
        }
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.run { continuation.resume(returning: listener.port?.rawValue ?? 0) }
                case .failed, .cancelled:
                    once.run { continuation.resume(throwing: ServerError.couldNotListen) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        guard port != 0, let url = URL(string: "http://127.0.0.1:\(port)/") else { throw ServerError.couldNotListen }
        self.listener = listener
        started = .now
        baseURL = url
        return url
    }

    /// Closes the listener and every open connection.
    public func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections = [:]
        pathsByConnection = [:]
        baseURL = nil
    }

    /// The next requests for `path` get these behaviors in order, then `serve`
    /// or whatever `always` set.
    public func script(_ path: String, _ behaviors: Behavior...) {
        scripted[normalized(path), default: []].append(contentsOf: behaviors)
    }

    /// Every request for `path` gets `behavior` once its script runs out.
    public func always(_ path: String, _ behavior: Behavior) {
        fallback[normalized(path)] = behavior
    }

    /// Drops the script and the `always` behavior for every path.
    public func serveEverything() {
        scripted = [:]
        fallback = [:]
    }

    /// The paths whose connections are open now.
    public var openPaths: [String] { pathsByConnection.values.sorted() }

    /// Forgets the requests seen so far and the connection peak.
    public func resetLog() {
        requests = []
        peakConnections = openConnections
    }

    /// The requests for `path` seen so far.
    public func requests(for path: String) -> [Request] {
        let path = normalized(path)
        return requests.filter { $0.path == path }
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) async {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        openConnections += 1
        peakConnections = max(peakConnections, openConnections)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                guard let self else { return }
                Task { await self.closed(key) }
            default:
                break
            }
        }
        connection.start(queue: queue)
        do {
            guard let head = try await Self.readHead(connection), var request = Self.parse(head) else {
                connection.cancel()
                return
            }
            request.openAtArrival = pathsByConnection.filter { $0.key != key }.map(\.value).sorted()
            pathsByConnection[key] = request.path
            requests.append(request)
            try await respond(to: request, on: connection)
        } catch {
            connection.cancel()
        }
    }

    private func closed(_ key: ObjectIdentifier) {
        guard connections.removeValue(forKey: key) != nil else { return }
        pathsByConnection[key] = nil
        openConnections -= 1
    }

    private func nextBehavior(for path: String) -> Behavior {
        if var queue = scripted[path], !queue.isEmpty {
            let next = queue.removeFirst()
            scripted[path] = queue
            return next
        }
        return fallback[path] ?? .serve
    }

    private func respond(to request: Request, on connection: NWConnection) async throws {
        let behavior = nextBehavior(for: request.path)
        switch behavior {
        case .refuse:
            connection.cancel()
            return
        case .status(let code):
            let body = Data("status \(code)\n".utf8)
            try await Self.send(connection, head: Self.head(status: code, type: "text/plain", length: body.count), body: body)
            connection.cancel()
            return
        case .body(let data, let type):
            try await Self.send(connection, head: Self.head(status: 200, type: type, length: data.count), body: data)
            connection.cancel()
            return
        case .serve, .ignoreRanges, .stall, .cut:
            break
        }
        guard let file = content(for: request.path) else {
            let body = Data("not found\n".utf8)
            try await Self.send(connection, head: Self.head(status: 404, type: "text/plain", length: body.count), body: body)
            connection.cancel()
            return
        }
        let type = Self.contentType(for: request.path)
        var status = 200
        var slice = file
        var extra: [String] = []
        if behavior != .ignoreRanges {
            extra.append("Accept-Ranges: bytes")
            if let range = request.headers["range"].flatMap({ Self.byteRange($0, length: file.count) }) {
                status = 206
                slice = file.subdata(in: range)
                extra.append("Content-Range: bytes \(range.lowerBound)-\(range.upperBound - 1)/\(file.count)")
            }
        }
        let head = Self.head(status: status, type: type, length: slice.count, extra: extra)
        switch behavior {
        case .stall(let bytes):
            try await Self.send(connection, head: head, body: slice.prefix(bytes))
            // Keep reading so a client that hangs up is seen as closed.
            while try await Self.receive(connection) != nil {}
            connection.cancel()
        case .cut(let bytes):
            try await Self.send(connection, head: head, body: slice.prefix(bytes))
            connection.cancel()
        default:
            try await Self.send(connection, head: head, body: request.method == "HEAD" ? Data() : slice)
            connection.cancel()
        }
    }

}

extension FixtureServer {
    // MARK: Content

    func normalized(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/" + path
    }

    func content(for path: String) -> Data? {
        let isLive = path.hasPrefix("/live/")
        let relative = String((isLive ? path.dropFirst("/live/".count) : path.dropFirst()))
        guard !relative.contains(".."), !relative.isEmpty else { return nil }
        let file = root.appending(path: relative)
        guard let data = try? Data(contentsOf: file) else { return nil }
        guard isLive, file.pathExtension == "m3u8", let playlist = String(data: data, encoding: .utf8) else { return data }
        let elapsed = ContinuousClock.now - started
        return Data(Self.livePlaylist(from: playlist, elapsed: elapsed).utf8)
    }

    /// A three segment live window over the segments of a finished playlist.
    public static func livePlaylist(from playlist: String, elapsed: Duration) -> String {
        var segments: [(duration: String, uri: String)] = []
        var target = "2"
        var pending: String?
        for line in playlist.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                target = String(line.dropFirst("#EXT-X-TARGETDURATION:".count))
            } else if line.hasPrefix("#EXTINF:") {
                pending = line
            } else if !line.hasPrefix("#"), let info = pending {
                segments.append((info, line))
                pending = nil
            }
        }
        guard !segments.isEmpty else { return playlist }
        let step = Double(target) ?? 2
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let first = Int(seconds / step)
        var lines = [
            "#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:\(target)", "#EXT-X-MEDIA-SEQUENCE:\(first)",
            "#EXT-X-DISCONTINUITY-SEQUENCE:\(first / segments.count)",
        ]
        for index in first..<(first + 3) {
            if index > first, index.isMultiple(of: segments.count) { lines.append("#EXT-X-DISCONTINUITY") }
            let segment = segments[index % segments.count]
            lines.append(segment.duration)
            lines.append(segment.uri)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func contentType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "m3u8": "application/vnd.apple.mpegurl"
        case "ts": "video/mp2t"
        case "mp4", "m4v": "video/mp4"
        case "mkv": "video/x-matroska"
        case "avi": "video/x-msvideo"
        case "aac": "audio/aac"
        case "mp3": "audio/mpeg"
        case "html": "text/html"
        default: "application/octet-stream"
        }
    }

    static func byteRange(_ header: String, length: Int) -> Range<Int>? {
        guard header.hasPrefix("bytes="), length > 0 else { return nil }
        let parts = header.dropFirst("bytes=".count).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let start = Int(parts[0]), start < length else { return nil }
        let end = parts[1].isEmpty ? length - 1 : min(Int(parts[1]) ?? (length - 1), length - 1)
        guard end >= start else { return nil }
        return start..<(end + 1)
    }

    // MARK: HTTP

    static func head(status: Int, type: String, length: Int, extra: [String] = []) -> String {
        let reason =
            switch status {
            case 200: "OK"
            case 206: "Partial Content"
            case 401: "Unauthorized"
            case 403: "Forbidden"
            case 404: "Not Found"
            case 429: "Too Many Requests"
            case 500: "Internal Server Error"
            case 503: "Service Unavailable"
            default: "Status"
            }
        let lines =
            ["HTTP/1.1 \(status) \(reason)", "Content-Type: \(type)", "Content-Length: \(length)", "Connection: close"] + extra
        return lines.joined(separator: "\r\n") + "\r\n\r\n"
    }

    static func parse(_ head: String) -> Request? {
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return nil }
        let target = String(parts[1])
        let pieces = target.split(separator: "?", maxSplits: 1).map(String.init)
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let path = pieces.first?.removingPercentEncoding ?? "/"
        return Request(method: String(parts[0]), path: path, query: pieces.count > 1 ? pieces[1] : nil, headers: headers)
    }

    static func readHead(_ connection: NWConnection) async throws -> String? {
        var buffer = Data()
        let end = Data("\r\n\r\n".utf8)
        while buffer.range(of: end) == nil {
            guard buffer.count < 64 * 1024, let chunk = try await receive(connection) else { return nil }
            buffer.append(chunk)
        }
        guard let range = buffer.range(of: end) else { return nil }
        return String(data: buffer[..<range.lowerBound], encoding: .utf8)
    }

    static func receive(_ connection: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: isComplete ? nil : Data())
                }
            }
        }
    }

    static func send(_ connection: NWConnection, head: String, body: Data) async throws {
        var data = Data(head.utf8)
        data.append(body)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                })
        }
    }
}

/// Runs a closure at most once, from any thread.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
