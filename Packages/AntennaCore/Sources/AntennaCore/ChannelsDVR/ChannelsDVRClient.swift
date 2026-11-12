import Foundation

extension URLSessionConfiguration {
    /// The configuration Channels DVR requests use: no URL cache and no cookies.
    public static var channelsDVR: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return configuration
    }
}

/// Talks to one Channels DVR server: its status, its channel lineup and the
/// address of its guide.
///
/// Every request carries the proxy credential when there is one, and none
/// without. Calls throw `ChannelsDVRError` or `CancellationError`.
/// `description`, `debugDescription` and `dump` show the host only, never
/// the port or the credential.
public struct ChannelsDVRClient: Sendable {
    public static let defaultPort = 8089
    /// Seven days, in seconds, asked of the guide export.
    public static let guideDuration = 604_800

    static let statusTimeout: TimeInterval = 10
    static let lineupTimeout: TimeInterval = 30

    /// The tidy server address from `serverURL(from:)`.
    public let server: URL
    public let credential: HTTPBasicCredential?
    let session: URLSession

    public init(server: URL, credential: HTTPBasicCredential? = nil, session: URLSession = URLSession(configuration: .channelsDVR)) {
        self.server = server
        self.credential = credential
        self.session = session
    }

    // MARK: Addresses

    /// `http://` and port 8089 when the text had neither a scheme nor a
    /// port, the host lowercased, a path kept, and query, fragment and
    /// trailing slash dropped. Nil for another scheme, no host, a username
    /// or password in the text, or an IPv6 address without brackets
    /// (channels-dvr-source/type-the-address-the-way-channels-dvr-shows-it).
    public static func serverURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        var scheme = "http"
        var rest = Substring(trimmed)
        let typedScheme = trimmed.range(of: "://")
        if let typedScheme {
            scheme = trimmed[..<typedScheme.lowerBound].lowercased()
            guard scheme == "http" || scheme == "https" else { return nil }
            rest = trimmed[typedScheme.upperBound...]
        }
        let authorityEnd = rest.firstIndex { "/?#".contains($0) } ?? rest.endIndex
        let authority = rest[..<authorityEnd]
        var path = String(rest[authorityEnd...].prefix { $0 != "?" && $0 != "#" })
        while path.hasSuffix("/") { path.removeLast() }

        guard let (host, typedPort) = hostAndPort(authority) else { return nil }
        let port = typedPort ?? (typedScheme == nil ? defaultPort : nil)
        let address = "\(scheme)://\(host)" + (port.map { ":\($0)" } ?? "") + path
        return URL(string: address)
    }

    /// The lowercased host, brackets kept for IPv6, and the port when typed.
    private static func hostAndPort(_ authority: Substring) -> (String, Int?)? {
        guard !authority.isEmpty, !authority.contains("@") else { return nil }
        let host: Substring
        let after: Substring
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { return nil }
            host = authority[...close]
            after = authority[authority.index(after: close)...]
            let inside = host.dropFirst().dropLast()
            guard inside.contains(":"), inside.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "." }) else { return nil }
        } else {
            let colon = authority.firstIndex(of: ":") ?? authority.endIndex
            host = authority[..<colon]
            after = authority[colon...]
            let allowed = host.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-._".contains($0)) }
            guard !host.isEmpty, allowed else { return nil }
        }
        guard !after.isEmpty else { return (host.lowercased(), nil) }
        let digits = after.dropFirst()
        guard after.first == ":", !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
            let port = Int(digits), (1...65_535).contains(port)
        else { return nil }
        return (host.lowercased(), port)
    }

    /// The lineup as an HLS playlist, which `AVPlayer` plays as it is.
    public func playlistURL() -> URL {
        server.appending(path: "devices/ANY/channels.m3u").appending(queryItems: [
            URLQueryItem(name: "format", value: "hls"), URLQueryItem(name: "codec", value: "copy"),
        ])
    }

    /// Seven days of guide as XMLTV.
    public func guideURL() -> URL {
        server.appending(path: "devices/ANY/guide/xmltv.xml").appending(queryItems: [
            URLQueryItem(name: "duration", value: String(Self.guideDuration))
        ])
    }

    public func statusURL() -> URL {
        server.appending(path: "status")
    }

    // MARK: Requests

    /// One GET of `/status`. A server that has not finished starting throws
    /// `.starting`; an answer that is not a Channels DVR status throws
    /// `.notAChannelsServer`. Any version is accepted
    /// (channels-dvr-source/connect-says-what-it-found).
    public func status() async throws -> ChannelsDVRStatus {
        let (status, data) = try await fetch(statusURL(), timeout: Self.statusTimeout)
        switch status {
        case 200..<300:
            let decoded = try Self.decodeStatus(data)
            if decoded.booted == false { throw ChannelsDVRError.starting }
            return decoded
        case 404: throw ChannelsDVRError.notAChannelsServer
        case 401, 403: throw ChannelsDVRError.unauthorized
        default: throw ChannelsDVRError.httpStatus(status)
        }
    }

    /// One GET of the lineup, and no status request. An empty playlist gives
    /// no channels and no error; a web page or an empty answer throws
    /// `.malformed` (channels-dvr-source/an-empty-or-wrong-lineup-is-handled).
    public func channels() async throws -> [Channel] {
        let (status, data) = try await fetch(playlistURL(), timeout: Self.lineupTimeout)
        switch status {
        case 200..<300: return try Self.channels(fromPlaylist: data)
        case 401, 403: throw ChannelsDVRError.unauthorized
        default: throw ChannelsDVRError.httpStatus(status)
        }
    }

    /// The GET every call makes, with the credential when there is one.
    public func request(_ url: URL, timeout: TimeInterval = 30) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        if let credential { request.setValue(credential.headerValue, forHTTPHeaderField: "Authorization") }
        return request
    }

    private func fetch(_ url: URL, timeout: TimeInterval) async throws -> (Int, Data) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request(url, timeout: timeout))
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled { throw CancellationError() }
            throw ChannelsDVRError(code: error.code)
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            throw ChannelsDVRError.transport(.unknown)
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw ChannelsDVRError.httpStatus(-1) }
        return (http.statusCode, data)
    }

    // MARK: Decoding

    /// A JSON object with a string `version`; anything else throws `.notAChannelsServer`.
    public static func decodeStatus(_ data: Data) throws -> ChannelsDVRStatus {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let version = object["version"] as? String
        else { throw ChannelsDVRError.notAChannelsServer }
        return ChannelsDVRStatus(
            versionText: version, prerelease: flag(object["prerelease"]), booted: flag(object["booted"]),
            subscription: object["subscription"] as? String)
    }

    /// A JSON `true` or `false`, nil for anything else, numbers included.
    private static func flag(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}

extension ChannelsDVRClient: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { server.host(percentEncoded: false) ?? "…" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}
