import Foundation

/// Stalker (Ministra) portal client, speaking the portal protocol as a
/// MAG250 set-top box.
///
/// One instance holds one session key and shares it between every caller:
/// concurrent callers that find no session wait on a single sign-in
/// (stalker-portal-source/channels-guide-and-playback-share-one-sign-in),
/// and a turned-down key is renewed once before the call fails
/// (stalker-portal-source/an-expired-session-renews-itself-once). Keep one
/// instance per source for the life of the process.
///
/// Every call throws `StalkerError` or `CancellationError`. The session
/// key is never written to disk. `description`, `debugDescription` and
/// `dump` show the portal's host only.
public actor StalkerClient {
    public nonisolated let credentials: StalkerCredentials
    let session: URLSession
    let device: StalkerDevice
    let identity: StalkerIdentity
    let now: @Sendable () -> Date
    let timeZone: TimeZone
    let redirects = StalkerRedirects()

    /// The `load.php` or `portal.php` that answered the first handshake.
    /// Kept for the life of the instance.
    var endpoint: URL?
    private var token: String?
    /// Bumped on each completed sign-in, so a rejection seen with an older
    /// key does not throw away a newer one.
    private var generation = 0
    private var signingIn: Task<Signed, any Error>?

    struct Signed: Sendable {
        var token: String
        var generation: Int
    }

    public init(
        credentials: StalkerCredentials,
        session: URLSession = URLSession(configuration: .stalker),
        device: StalkerDevice = .mag250,
        timeZone: TimeZone = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.credentials = credentials
        self.session = session
        self.device = device
        self.identity = StalkerIdentity(mac: credentials.mac)
        self.timeZone = timeZone
        self.now = now
    }

    /// Signs in when no session is open: handshake, `do_auth` when there is
    /// a login, then the profile. Concurrent callers share one sign-in.
    public func signIn() async throws {
        _ = try await currentSession()
    }

    /// Forgets the session key, so the next call signs in again. The guide
    /// calls this when the portal turns down a download it made with
    /// `epgRequest(period:)`.
    public func invalidateToken() {
        guard signingIn == nil else { return }
        token = nil
    }

    // MARK: Session

    func currentSession() async throws -> Signed {
        if let token { return Signed(token: token, generation: generation) }
        if let signingIn { return try await signingIn.value }
        let task = Task { try await self.performSignIn() }
        signingIn = task
        return try await task.value
    }

    private func performSignIn() async throws -> Signed {
        defer { signingIn = nil }
        let hello = try await handshake()
        if credentials.login != nil {
            try await authorize(token: hello.token)
        }
        try await profile(token: hello.token, random: hello.random)
        generation += 1
        token = hello.token
        return Signed(token: hello.token, generation: generation)
    }

    /// Drops the key the caller was turned down with, unless a newer one
    /// replaced it already.
    private func discard(_ signed: Signed) {
        guard signed.generation == generation, signingIn == nil else { return }
        token = nil
    }

    /// One call after sign-in. A rejection signs in again and repeats the
    /// call once; a second rejection throws `.notAuthorized`.
    func call(_ items: [(String, String)], timeout: TimeInterval = 30) async throws -> StalkerPayload {
        var renewed = false
        while true {
            let signed = try await currentSession()
            guard let endpoint else { throw StalkerError.noPortal }
            let request = request(StalkerWire.url(endpoint: endpoint, items: items), token: signed.token, timeout: timeout)
            let (status, data) = try await fetch(request)
            switch try StalkerWire.read(status: status, data: data) {
            case .payload(let value):
                return StalkerPayload(value: value)
            case .rejected:
                if renewed { throw StalkerError.notAuthorized }
                renewed = true
                discard(signed)
            }
        }
    }

    func request(_ url: URL, token: String?, timeout: TimeInterval = 30) -> URLRequest {
        StalkerWire.request(
            url: url, portal: credentials.portal, mac: credentials.mac, device: device, timeZone: timeZone, token: token, timeout: timeout)
    }

    /// One GET. Transport failures become `.transport` with the code only.
    func fetch(_ request: URLRequest) async throws -> (status: Int, data: Data) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: redirects)
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled { throw CancellationError() }
            throw StalkerError.transport(error.code)
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            throw StalkerError.transport(.unknown)
        }
        try Task.checkCancellation()
        return ((response as? HTTPURLResponse)?.statusCode ?? -1, data)
    }
}

extension StalkerClient: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public nonisolated var description: String { credentials.description }
    public nonisolated var debugDescription: String { description }
    public nonisolated var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}

/// The value under `js`, kept inside the client while it is read.
struct StalkerPayload: @unchecked Sendable {
    let value: Any
}
