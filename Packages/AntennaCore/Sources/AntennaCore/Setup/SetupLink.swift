import Foundation

/// The random one-time code an Apple TV shows in its setup link
/// (iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code):
/// 16 random bytes in base64url without padding, 22 characters.
public struct PairingToken: Hashable, Sendable, CustomStringConvertible {
    /// The 22 characters.
    public let text: String

    /// A new code from the system's random source.
    public init() {
        var generator = SystemRandomNumberGenerator()
        self.init(using: &generator)
    }

    /// A new code from `generator`, so tests can repeat one.
    public init<Generator: RandomNumberGenerator>(using generator: inout Generator) {
        let bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        text = Self.encode(bytes)
    }

    /// Reads a code, nil unless it is the canonical encoding of 16 bytes.
    public init?(_ text: String) {
        guard text.count == 22, text.allSatisfy({ Self.alphabet.contains($0) }) else { return nil }
        // 22 characters carry 132 bits; the last 4 belong to no byte and must be zero.
        guard let last = text.last, let index = Self.alphabet.firstIndex(of: last), index.isMultiple(of: 16) else { return nil }
        self.text = text
    }

    public var description: String { "PairingToken" }

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    private static func encode(_ bytes: [UInt8]) -> String {
        Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// The web link in the Apple TV's QR code and Handoff offer:
/// `https://<host>/setup?v=1&t=<token>`. It holds a version and a code
/// and nothing else.
public struct SetupLink: Hashable, Sendable {
    /// The host serving the association file and the fallback page.
    /// An assumption until the hosting decision picks one.
    public static let host = "antenna.codecrave.se"
    /// The version this build writes and reads.
    public static let version = "1"
    /// The Handoff activity type for the setup offer.
    public static let activityType = "se.codecrave.antenna.setup"
    /// The Handoff activity's title.
    public static let activityTitle = "Set up Antenna on Apple TV"
    /// The one key of the Handoff activity's user info.
    public static let tokenKey = "token"

    public let token: PairingToken

    public init(token: PairingToken) {
        self.token = token
    }

    /// Why a link is not one this build can open, in the order checked.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Another host or path, or a repeated `v` or `t`.
        case notASetupLink
        case missingVersion
        /// From a newer Antenna.
        case unsupportedVersion(String)
        case missingToken
        case malformedToken
    }

    /// The link to encode, with `v` before `t`.
    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/setup"
        components.queryItems = [URLQueryItem(name: "v", value: Self.version), URLQueryItem(name: "t", value: token.text)]
        // The parts above are all valid, so the URL always forms.
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// The Handoff activity's user info: the code and nothing else.
    public var userInfo: [String: String] { [Self.tokenKey: token.text] }

    /// Reads a setup link. The query items may come in either order, the
    /// host may be uppercase, unknown items are ignored and `/setup/` reads
    /// as `/setup`.
    public init(url: URL) throws(Error) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            components.host?.lowercased() == Self.host,
            components.path == "/setup" || components.path == "/setup/"
        else { throw .notASetupLink }
        let items = components.queryItems ?? []
        let versions = items.filter { $0.name == "v" }
        let tokens = items.filter { $0.name == "t" }
        guard versions.count <= 1, tokens.count <= 1 else { throw .notASetupLink }
        guard let version = versions.first?.value else { throw .missingVersion }
        guard version == Self.version else { throw .unsupportedVersion(version) }
        guard let text = tokens.first?.value else { throw .missingToken }
        guard let token = PairingToken(text) else { throw .malformedToken }
        self.token = token
    }

    /// Reads the code from a Handoff activity's user info; nil when it holds no valid code.
    public init?(userInfo: [AnyHashable: Any]?) {
        guard let text = userInfo?[Self.tokenKey] as? String, let token = PairingToken(text) else { return nil }
        self.token = token
    }
}
