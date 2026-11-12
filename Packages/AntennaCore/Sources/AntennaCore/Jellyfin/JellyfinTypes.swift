import Foundation

/// What a Jellyfin sign-in needs. The username and password come from the
/// source's Keychain item.
///
/// `description`, `debugDescription` and `dump` show the server's host only:
/// no port, path, username or password
/// (jellyfin-live-tv-source/secrets-never-show-up-in-messages-or-logs).
public struct JellyfinCredentials: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// The base address: scheme and host, optionally a port and a path such
    /// as `/jellyfin`.
    public var server: URL
    public var username: String
    public var password: String

    public init(server: URL, username: String, password: String) {
        self.server = server
        self.username = username
        self.password = password
    }

    /// The host, lower-cased. Channel ids are built from it.
    public var host: String { server.host(percentEncoded: false)?.lowercased() ?? "" }

    public var description: String { host }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}

/// How this device names itself to the server. The app makes `id` once per
/// device. `name` names the platform ("Apple TV", "iPhone", "iPad", "Mac"),
/// never the user's own device name.
///
/// Prints as `name` only.
public struct JellyfinDevice: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var id: String
    public var name: String
    public var appVersion: String

    public init(id: String, name: String, appVersion: String) {
        self.id = id
        self.name = name
        self.appVersion = appVersion
    }

    public var description: String { name }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["name": name]) }
}

/// What a sign-in hands back: this device's key and the ids it belongs to.
///
/// Never prints the key.
public struct JellyfinSession: Sendable, Hashable, Codable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var token: String
    public var userID: String
    public var serverID: String

    public init(token: String, userID: String, serverID: String) {
        self.token = token
        self.userID = userID
        self.serverID = serverID
    }

    public var description: String { "JellyfinSession(…)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Where one source's sign-in key is kept on this device. One store serves
/// one source. Errors it throws reach the caller unchanged.
public protocol JellyfinSessionStore: Sendable {
    func load() async throws -> JellyfinSession?
    func save(_ session: JellyfinSession) async throws
    func clear() async throws
}

/// A session store that keeps the key in memory for the life of the
/// process.
public actor JellyfinMemorySessionStore: JellyfinSessionStore {
    private var session: JellyfinSession?

    public init(_ session: JellyfinSession? = nil) {
        self.session = session
    }

    public func load() -> JellyfinSession? { session }
    public func save(_ session: JellyfinSession) { self.session = session }
    public func clear() { session = nil }
}

/// What `/System/Info/Public` says about the server.
public struct JellyfinServerInfo: Sendable, Hashable {
    public var id: String
    public var name: String?
    public var version: String

    public init(id: String, name: String?, version: String) {
        self.id = id
        self.name = name
        self.version = version
    }
}

/// One decoded row of `/LiveTv/Channels`.
public struct JellyfinChannel: Sendable, Hashable {
    public var id: String
    public var name: String
    /// The channel number when the server gives a whole number.
    public var number: Int?
    public var isRadio: Bool
    public var primaryImageTag: String?

    public init(id: String, name: String, number: Int?, isRadio: Bool, primaryImageTag: String?) {
        self.id = id
        self.name = name
        self.number = number
        self.isRadio = isRadio
        self.primaryImageTag = primaryImageTag
    }
}

extension JellyfinClient {
    /// Why a Jellyfin call failed
    /// (jellyfin-live-tv-source/different-failures-get-different-errors).
    /// Values hold no address, username, password, key or response body.
    public enum JellyfinError: Error, Sendable, Equatable {
        /// The server answered with this status, other than 401 and 403.
        case badStatus(Int)
        /// 401: the password or this device's key was turned down.
        case unauthorized
        /// 403: the account may not sign in from this device, or may not use
        /// Live TV.
        case forbidden
        /// The request failed before an answer arrived. Only the code is kept.
        case transport(URLError.Code)
        /// The answer was not the JSON expected. `path` names the part that
        /// was missing or of the wrong kind, never anything from the answer.
        case decoding(path: String)
        /// The server's certificate is self-signed, from an unknown
        /// authority, expired or not yet valid.
        case untrustedCertificate

        static let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
        static let certificateCodes: Set<URLError.Code> = [
            .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot,
        ]

        /// True for a transport failure that means no connection.
        public var isOffline: Bool {
            if case .transport(let code) = self { return Self.offlineCodes.contains(code) }
            return false
        }
    }
}
