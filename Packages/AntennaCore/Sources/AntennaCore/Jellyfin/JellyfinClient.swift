import Foundation

/// Jellyfin client for a server's Live TV: the server check, sign-in,
/// channels, guide and stream addresses.
///
/// Each device signs in with its own id and keeps the key the server hands
/// back in `sessionStore`; after that only the key is sent
/// (jellyfin-live-tv-source/signing-in-remembers-this-device). A call reads
/// the store once. A turned-down key leads to one new sign-in and the
/// turned-down request is repeated; a second refusal discards the key
/// (jellyfin-live-tv-source/a-revoked-sign-in-renews-itself-once).
///
/// Every call throws `JellyfinError`, `CancellationError`, or an error the
/// session store threw. `description`, `debugDescription` and `dump` show
/// the server's host only.
public struct JellyfinClient: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let credentials: JellyfinCredentials
    public let device: JellyfinDevice
    let sessionStore: any JellyfinSessionStore
    let session: URLSession

    public init(
        credentials: JellyfinCredentials, device: JellyfinDevice, sessionStore: any JellyfinSessionStore, session: URLSession = .shared
    ) {
        self.credentials = credentials
        self.device = device
        self.sessionStore = sessionStore
        self.session = session
    }

    public var description: String { credentials.description }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }

    // MARK: Server check and sign-in

    /// `GET /System/Info/Public`, sent with no password and no key
    /// (jellyfin-live-tv-source/connect-checks-it-is-really-a-jellyfin-server).
    public func serverInfo() async throws -> JellyfinServerInfo {
        let data = try await send(request(path: "System/Info/Public", token: nil))
        return try Self.decodeServerInfo(data)
    }

    /// Signs in with the username and password, keeps the key in the
    /// session store and returns it. The only call that sends the password.
    @discardableResult
    public func authenticate() async throws -> JellyfinSession {
        var request = request(path: "Users/AuthenticateByName", token: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Username": credentials.username, "Pw": credentials.password])
        let signed = try Self.decodeSession(try await send(request))
        try Task.checkCancellation()
        try await sessionStore.save(signed)
        return signed
    }

    /// Reads `/System/Info/Public`. Needs `Id` and `Version`.
    public static func decodeServerInfo(_ data: Data) throws -> JellyfinServerInfo {
        let object = try JellyfinWire.object(data)
        guard let id = JellyfinWire.string(object["Id"]), !id.isEmpty else { throw JellyfinError.decoding(path: "Id") }
        guard let version = JellyfinWire.string(object["Version"]), !version.isEmpty else {
            throw JellyfinError.decoding(path: "Version")
        }
        let name = JellyfinWire.string(object["ServerName"])
        return JellyfinServerInfo(id: id, name: name?.isEmpty == false ? name : nil, version: version)
    }

    /// Reads the answer to `AuthenticateByName`. Needs `AccessToken`,
    /// `User.Id` and `ServerId`.
    public static func decodeSession(_ data: Data) throws -> JellyfinSession {
        let object = try JellyfinWire.object(data)
        guard let token = JellyfinWire.string(object["AccessToken"]), !token.isEmpty else {
            throw JellyfinError.decoding(path: "AccessToken")
        }
        guard let user = JellyfinWire.string((object["User"] as? [String: Any])?["Id"]), !user.isEmpty else {
            throw JellyfinError.decoding(path: "User.Id")
        }
        guard let server = JellyfinWire.string(object["ServerId"]), !server.isEmpty else {
            throw JellyfinError.decoding(path: "ServerId")
        }
        return JellyfinSession(token: token, userID: user, serverID: server)
    }

    // MARK: Signed-in calls

    /// One call's hold on the key. The store is read once when the call
    /// starts, and only a turned-down key changes it.
    struct Signed {
        let client: JellyfinClient
        private(set) var session: JellyfinSession
        /// True once a turned-down key led to a new sign-in, so a second
        /// refusal is final.
        private var renewed = false

        /// Reads the store, and signs in when it holds no key.
        init(_ client: JellyfinClient) async throws {
            self.client = client
            if let saved = try await client.sessionStore.load() {
                session = saved
            } else {
                session = try await client.authenticate()
            }
        }

        /// Sends the request `build` makes with the key. A 401 signs in once
        /// more and repeats this request; a second 401, or a sign-in that is
        /// turned down, clears the stored key and throws `.unauthorized`.
        mutating func send(_ build: (JellyfinSession) throws -> URLRequest) async throws -> Data {
            while true {
                do {
                    return try await client.send(try build(session))
                } catch JellyfinError.unauthorized {
                    guard !renewed else { return try await discard() }
                    renewed = true
                    do {
                        session = try await client.authenticate()
                    } catch JellyfinError.unauthorized {
                        return try await discard()
                    }
                }
            }
        }

        private func discard() async throws -> Data {
            try await client.sessionStore.clear()
            throw JellyfinError.unauthorized
        }
    }

    // MARK: Requests

    /// `server` with its path, then `path`. A trailing slash on the server
    /// is dropped.
    func url(path: String, query: [URLQueryItem] = []) -> URL {
        Self.url(server: credentials.server, path: path, query: query)
    }

    static func url(server: URL, path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: server, resolvingAgainstBaseURL: false) ?? URLComponents()
        var base = components.percentEncodedPath
        while base.hasSuffix("/") { base.removeLast() }
        components.percentEncodedPath = base + "/" + path
        components.percentEncodedQuery = query.isEmpty ? nil : JellyfinWire.query(query)
        components.fragment = nil
        return components.url ?? server
    }

    /// A GET with the `Authorization` header, carrying `token` when given.
    func request(path: String, query: [URLQueryItem] = [], token: String?) -> URLRequest {
        var request = URLRequest(url: url(path: path, query: query), timeoutInterval: 30)
        request.setValue(JellyfinWire.authorization(device: device, token: token), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Sends one request and returns the body of a 2xx answer.
    func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled { throw CancellationError() }
            if JellyfinError.certificateCodes.contains(error.code) { throw JellyfinError.untrustedCertificate }
            throw JellyfinError.transport(error.code)
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            throw JellyfinError.transport(.unknown)
        }
        try Task.checkCancellation()
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200..<300: return data
        case 401: throw JellyfinError.unauthorized
        case 403: throw JellyfinError.forbidden
        default: throw JellyfinError.badStatus(status)
        }
    }
}
