import Foundation

/// HTTP headers a playlist asks for on a channel's stream, such as a
/// User-Agent the provider allows or a Referer
/// (m3u-playlists/stream-headers-from-the-playlist). A Referer can carry a
/// token, so `description` names the headers and never their values, and
/// nothing logs them.
public struct StreamHeaders: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// Values by header name, with `User-Agent`, `Referer` and `Origin`
    /// spelled that way whatever case the playlist used.
    public private(set) var fields: [String: String] = [:]

    public init(_ fields: [String: String] = [:]) {
        for (name, value) in fields { set(name, value) }
    }

    public var isEmpty: Bool { fields.isEmpty }
    public var userAgent: String? { fields["User-Agent"] }

    /// Sets `name` to `value`, both trimmed. An empty name or value is
    /// ignored. `referrer`, the spelling VLC options use, becomes `Referer`.
    public mutating func set(_ name: String, _ value: String) {
        let name = Self.canonical(name.trimmingCharacters(in: .whitespaces))
        let value = value.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty, !name.contains(where: \.isNewline), !value.contains(where: \.isNewline) else { return }
        fields[name] = value
    }

    /// These headers with `other`'s on top.
    public func merging(_ other: StreamHeaders) -> StreamHeaders {
        var merged = self
        for (name, value) in other.fields { merged.fields[name] = value }
        return merged
    }

    /// Sets every header on `request`, replacing a value it already has.
    public func apply(to request: inout URLRequest) {
        for (name, value) in fields { request.setValue(value, forHTTPHeaderField: name) }
    }

    public var description: String { "StreamHeaders(\(fields.keys.sorted().joined(separator: ", ")))" }
    public var debugDescription: String { description }
    /// Shows the header names only, so `dump` does not print a token either.
    public var customMirror: Mirror { Mirror(self, children: ["names": fields.keys.sorted()]) }

    private static func canonical(_ name: String) -> String {
        switch name.lowercased() {
        case "user-agent", "http-user-agent", "useragent": "User-Agent"
        case "referer", "referrer", "http-referrer", "http-referer": "Referer"
        case "origin", "http-origin": "Origin"
        default: name
        }
    }
}

/// The headers each stream address is asked for with, filled when a source's
/// channels load and read by both playback paths and the stream probe
/// (playback-engine/streams-are-asked-for-with-their-headers). An address
/// without headers of its own takes those of its source's server.
public final class StreamHeaderBook: @unchecked Sendable {
    public static let shared = StreamHeaderBook()

    private let lock = NSLock()
    /// Per source, the headers by stream address.
    private var addresses: [UUID: [String: StreamHeaders]] = [:]
    /// Per source, its server's origin and the headers every stream there gets.
    private var origins: [UUID: (origin: String, headers: StreamHeaders)] = [:]

    public init() {}

    /// Replaces the source's stream headers with those of `channels`, each
    /// on top of `base`, the source's own.
    public func register(_ channels: [Channel], source: UUID, base: StreamHeaders = StreamHeaders()) {
        var table: [String: StreamHeaders] = [:]
        for channel in channels {
            let headers = base.merging(channel.headers ?? StreamHeaders())
            guard !headers.isEmpty else { continue }
            table[channel.streamURL.absoluteString] = headers
        }
        lock.withLock { addresses[source] = table.isEmpty ? nil : table }
    }

    /// Gives every stream on `server`'s scheme, host and port `headers`, under
    /// what an address has of its own. Empty headers remove the entry.
    public func register(_ headers: StreamHeaders, server: URL, source: UUID) {
        guard let origin = Self.origin(server) else { return }
        lock.withLock { origins[source] = headers.isEmpty ? nil : (origin, headers) }
    }

    /// Forgets the source.
    public func remove(source: UUID) {
        lock.withLock {
            addresses[source] = nil
            origins[source] = nil
        }
    }

    /// The headers for `url`: its server's, then its own on top.
    public func headers(for url: URL) -> StreamHeaders {
        let address = url.absoluteString
        let origin = Self.origin(url)
        return lock.withLock {
            var result = StreamHeaders()
            if let origin, let entry = origins.values.first(where: { $0.origin == origin }) { result = entry.headers }
            if let own = addresses.values.lazy.compactMap({ $0[address] }).first { result = result.merging(own) }
            return result
        }
    }

    /// Sets the headers for the request's address on it.
    public func apply(to request: inout URLRequest) {
        guard let url = request.url else { return }
        headers(for: url).apply(to: &request)
    }

    private static func origin(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased() else { return nil }
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)://\(host):\(port)"
    }
}
