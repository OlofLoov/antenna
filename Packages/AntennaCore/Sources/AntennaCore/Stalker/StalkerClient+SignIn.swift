import Foundation

/// The portal's account details from `get_main_info`.
public struct StalkerAccountInfo: Sendable, Equatable {
    /// `end_date` read in UTC, a date-only value as midnight UTC. Nil when
    /// absent, zero or unreadable.
    public var expiresAt: Date?

    public init(expiresAt: Date?) {
        self.expiresAt = expiresAt
    }
}

extension StalkerClient {
    struct Hello {
        var token: String
        var random: String
    }

    /// Where the portal's API may be, in the order tried.
    static func candidates(for portal: URL) -> [URL] {
        if portal.lastPathComponent == "stalker_portal" {
            return [portal.appending(path: "server/load.php")]
        }
        return [
            portal.appending(path: "stalker_portal/server/load.php"), portal.appending(path: "server/load.php"),
            portal.appending(path: "portal.php"),
        ]
    }

    private static let handshakeItems = [("type", "stb"), ("action", "handshake"), ("token", "")]

    /// The handshake. Without an endpoint, tries each candidate in order
    /// and keeps the first that hands out a session key.
    func handshake() async throws -> Hello {
        if let endpoint {
            let (status, data) = try await fetch(request(StalkerWire.url(endpoint: endpoint, items: Self.handshakeItems), token: nil))
            switch try StalkerWire.read(status: status, data: data) {
            case .rejected: throw StalkerError.notAuthorized
            case .payload(let js):
                guard let hello = Self.hello(js) else { throw StalkerError.notAuthorized }
                return hello
            }
        }
        var lastServerError: Int?
        var refused = false
        for candidate in Self.candidates(for: credentials.portal.url) {
            let (status, data) = try await fetch(request(StalkerWire.url(endpoint: candidate, items: Self.handshakeItems), token: nil))
            if (200..<300).contains(status) {
                let object = StalkerWire.json(StalkerWire.trimmed(data)) as? [String: Any]
                if let object, let hello = object["js"].flatMap(Self.hello) {
                    endpoint = candidate
                    return hello
                }
                if object != nil || StalkerWire.trimmed(data).elementsEqual("Authorization failed.".utf8) { refused = true }
            } else if (500..<600).contains(status) {
                lastServerError = status
            } else if (status == 401 || status == 403) && !StalkerWire.looksLikeHTML(data) {
                refused = true
            }
        }
        if let lastServerError { throw StalkerError.serverError(status: lastServerError) }
        throw refused ? StalkerError.notAuthorized : StalkerError.noPortal
    }

    private static func hello(_ js: Any) -> Hello? {
        guard let object = js as? [String: Any], let token = StalkerWire.string(object["token"]), !token.isEmpty else { return nil }
        return Hello(token: token, random: StalkerWire.string(object["random"]) ?? "")
    }

    /// `do_auth` with the login and password. Anything but `true` is a
    /// refusal.
    func authorize(token: String) async throws {
        let items = [
            ("type", "stb"), ("action", "do_auth"), ("login", credentials.login ?? ""), ("password", credentials.password),
            ("device_id", identity.deviceID), ("device_id2", identity.deviceID),
        ]
        let js = try await signedInRead(items, token: token)
        let accepted = (js as? Bool) == true || StalkerWire.int(js) == 1 || (js as? String) == "true"
        guard accepted else { throw StalkerError.notAuthorized }
    }

    /// `get_profile` with the device identity. A `block_msg`, or a non-zero
    /// `status` with a `msg`, refuses the device with that message; a
    /// non-zero `status` alone refuses it as not authorized.
    func profile(token: String, random: String) async throws {
        let js = try await signedInRead(profileItems(random: random), token: token)
        guard let object = js as? [String: Any] else { return }
        let message = [StalkerWire.string(object["block_msg"]), StalkerWire.string(object["msg"])]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        let status = StalkerWire.int(object["status"]) ?? 0
        if let message, status != 0 || StalkerWire.string(object["block_msg"])?.isEmpty == false {
            throw StalkerError.deviceRefused(message: redact(message))
        }
        if status != 0 { throw StalkerError.notAuthorized }
    }

    func profileItems(random: String) -> [(String, String)] {
        [
            ("type", "stb"), ("action", "get_profile"), ("hd", "1"), ("ver", device.version), ("num_banks", "2"),
            ("sn", identity.serialNumber), ("stb_type", device.stbType), ("client_type", "STB"), ("image_version", device.imageVersion),
            ("video_out", "hdmi"), ("device_id", identity.deviceID), ("device_id2", identity.deviceID), ("signature", identity.signature),
            ("auth_second_step", "1"), ("hw_version", device.hardwareVersion), ("not_valid_token", "0"),
            ("metrics", metrics(random: random)),
            ("hw_version_2", identity.serialNumber), ("timestamp", String(Int(now().timeIntervalSince1970))),
            ("api_signature", device.apiSignature), ("prehash", ""),
        ]
    }

    /// The `metrics` JSON, keys in a fixed order and no whitespace.
    func metrics(random: String) -> String {
        func quoted(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let pairs = [
            ("mac", credentials.mac.text), ("sn", identity.serialNumber), ("type", "STB"), ("model", device.stbType), ("uid", ""),
            ("random", random),
        ]
        return "{" + pairs.map { quoted($0) + ":" + quoted($1) }.joined(separator: ",") + "}"
    }

    /// A call made during sign-in with the key just handed out. A rejection
    /// is final here, since renewing would start the same sign-in again.
    private func signedInRead(_ items: [(String, String)], token: String) async throws -> Any {
        guard let endpoint else { throw StalkerError.noPortal }
        let (status, data) = try await fetch(request(StalkerWire.url(endpoint: endpoint, items: items), token: token))
        switch try StalkerWire.read(status: status, data: data) {
        case .rejected: throw StalkerError.notAuthorized
        case .payload(let js): return js
        }
    }

    /// `text` with the MAC, login, password and session key replaced by "…".
    func redact(_ text: String) -> String {
        StalkerWire.redact(
            text, mac: credentials.mac,
            secrets: [credentials.password, credentials.login ?? "", identity.serialNumber, identity.deviceID, identity.signature])
    }

    /// `get_main_info`.
    public func accountInfo() async throws -> StalkerAccountInfo {
        let payload = try await call([("type", "account_info"), ("action", "get_main_info")])
        let object = payload.value as? [String: Any]
        return StalkerAccountInfo(expiresAt: Self.endDate(StalkerWire.string(object?["end_date"])))
    }

    /// `yyyy-MM-dd HH:mm:ss` or `yyyy-MM-dd` in UTC, or whole seconds since 1970.
    static func endDate(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if let seconds = Int(text) { return seconds > 0 ? Date(timeIntervalSince1970: TimeInterval(seconds)) : nil }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .gmt
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
