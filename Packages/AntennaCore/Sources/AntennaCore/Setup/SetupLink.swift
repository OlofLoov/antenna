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
        text = Base64URL.encode(Data(bytes))
    }

    /// Reads a code, nil unless it is the canonical encoding of 16 bytes.
    public init?(_ text: String) {
        guard Base64URL.decode(text, count: 16) != nil else { return nil }
        self.text = text
    }

    public var description: String { "PairingToken" }
}

/// The public half of the key an Apple TV makes for one code
/// (apple-tv-login-from-iphone/the-code-holds-no-secret): a Curve25519 key
/// in its 32-byte raw form, as 43 characters of base64url without padding.
/// Only the TV holding the private half can open what is sealed to it.
public struct SetupKey: Hashable, Sendable, CustomStringConvertible {
    /// The 43 characters.
    public let text: String
    /// The 32 bytes.
    public let bytes: Data

    /// Reads a key, nil unless it is the canonical encoding of 32 bytes.
    public init?(_ text: String) {
        guard let bytes = Base64URL.decode(text, count: 32) else { return nil }
        self.text = text
        self.bytes = bytes
    }

    /// A key from its 32 raw bytes; nil for any other length.
    public init?(bytes: Data) {
        guard bytes.count == 32 else { return nil }
        self.bytes = bytes
        text = Base64URL.encode(bytes)
    }

    public var description: String { "SetupKey" }
}

/// Base64url without padding, read only in its canonical form, so one
/// value has one spelling.
enum Base64URL {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// The `count` bytes `text` encodes, or nil when it is not their canonical encoding.
    static func decode(_ text: String, count: Int) -> Data? {
        let length = (count * 8 + 5) / 6
        guard text.count == length, text.allSatisfy({ alphabet.contains($0) }) else { return nil }
        // The bits after the last whole byte belong to no byte and must be zero.
        let spare = length * 6 - count * 8
        guard let last = text.last, let index = alphabet.firstIndex(of: last), index.isMultiple(of: 1 << spare) else { return nil }
        var padded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded), data.count == count else { return nil }
        return data
    }
}

/// The web link in the Apple TV's QR code and Handoff offer. Version 1,
/// `https://<host>/setup?v=1&t=<token>`, holds a version and a code.
/// Version 2 adds `k`, the public key the TV made for the code, and for a
/// sign-in code `s`, the sources it asks logins for
/// (apple-tv-login-from-iphone/the-code-holds-no-secret).
public struct SetupLink: Hashable, Sendable {
    /// The host serving the association file and the fallback page.
    /// An assumption until the hosting decision picks one.
    public static let host = "antenna.codecrave.se"
    /// The newest version this build writes and reads.
    public static let version = "2"
    /// The versions this build reads.
    public static let readable: Set<String> = ["1", "2"]
    /// The most sources one code asks for.
    public static let sourceLimit = 8
    /// The Handoff activity type for the setup offer.
    public static let activityType = "se.codecrave.antenna.setup"
    /// The Handoff activity's title.
    public static let activityTitle = "Set up Antenna on Apple TV"
    /// The key of a version 1 Handoff activity's user info.
    public static let tokenKey = "token"
    /// The key of a version 2 Handoff activity's user info.
    public static let linkKey = "link"

    public let token: PairingToken
    /// The TV's public key for this code; nil in a version 1 link.
    public let key: SetupKey?
    /// The sources a sign-in code asks for, in the TV's order; empty for the setup card.
    public let sources: [UUID]

    /// A version 1 link without a key, or version 2 with one. Sources
    /// past the eighth, or without a key, are dropped.
    public init(token: PairingToken, key: SetupKey? = nil, sources: [UUID] = []) {
        self.token = token
        self.key = key
        self.sources = key == nil ? [] : Array(sources.prefix(Self.sourceLimit))
    }

    /// Why a link is not one this build can open, in the order checked.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Another host or path, or a repeated `v`, `t`, `k` or `s`.
        case notASetupLink
        case missingVersion
        /// From a newer Antenna.
        case unsupportedVersion(String)
        case missingToken
        case malformedToken
        case missingKey
        case malformedKey
        /// An empty, malformed or repeated source, or more than eight.
        case malformedSources
    }

    /// True for a code from the Apple TV's sign-in, which asks for logins.
    public var asksForLogins: Bool { !sources.isEmpty }

    /// The link to encode: `v`, `t`, then `k` and `s` when present.
    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/setup"
        var items = [URLQueryItem(name: "v", value: key == nil ? "1" : Self.version), URLQueryItem(name: "t", value: token.text)]
        if let key { items.append(URLQueryItem(name: "k", value: key.text)) }
        if !sources.isEmpty { items.append(URLQueryItem(name: "s", value: sources.map(Self.encode).joined(separator: ","))) }
        components.queryItems = items
        // The parts above are all valid, so the URL always forms.
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// The Handoff activity's user info: the code alone for version 1,
    /// the link alone for version 2.
    public var userInfo: [String: String] {
        key == nil ? [Self.tokenKey: token.text] : [Self.linkKey: url.absoluteString]
    }

    /// Reads a setup link. The query items may come in any order, the
    /// host may be uppercase, unknown items are ignored and `/setup/` reads
    /// as `/setup`.
    public init(url: URL) throws(Error) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            components.host?.lowercased() == Self.host,
            components.path == "/setup" || components.path == "/setup/"
        else { throw .notASetupLink }
        let items = components.queryItems ?? []
        let named = { (name: String) in items.filter { $0.name == name } }
        let versions = named("v")
        let tokens = named("t")
        let keys = named("k")
        let lists = named("s")
        guard versions.count <= 1, tokens.count <= 1, keys.count <= 1, lists.count <= 1 else { throw .notASetupLink }
        guard let version = versions.first?.value else { throw .missingVersion }
        guard Self.readable.contains(version) else { throw .unsupportedVersion(version) }
        guard let text = tokens.first?.value else { throw .missingToken }
        guard let token = PairingToken(text) else { throw .malformedToken }
        guard version == "2" else {
            self.init(token: token)
            return
        }
        guard let keyText = keys.first?.value else { throw .missingKey }
        guard let key = SetupKey(keyText) else { throw .malformedKey }
        var sources: [UUID] = []
        if let list = lists.first {
            let parts = (list.value ?? "").split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            sources = parts.compactMap(Self.decode)
            guard sources.count == parts.count, Set(sources).count == sources.count, sources.count <= Self.sourceLimit else {
                throw .malformedSources
            }
        }
        self.init(token: token, key: key, sources: sources)
    }

    /// Reads a Handoff activity's user info: the link for version 2, the
    /// code for version 1. Nil when it holds neither.
    public init?(userInfo: [AnyHashable: Any]?) {
        if let text = userInfo?[Self.linkKey] as? String, let url = URL(string: text), let link = try? SetupLink(url: url) {
            self = link
            return
        }
        guard let text = userInfo?[Self.tokenKey] as? String, let token = PairingToken(text) else { return nil }
        self.init(token: token)
    }

    private static func encode(_ id: UUID) -> String {
        Base64URL.encode(withUnsafeBytes(of: id.uuid) { Data($0) })
    }

    private static func decode(_ text: String) -> UUID? {
        guard let data = Base64URL.decode(text, count: 16) else { return nil }
        var uuid: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutableBytes(of: &uuid) { $0.copyBytes(from: data) }
        return UUID(uuid: uuid)
    }
}
