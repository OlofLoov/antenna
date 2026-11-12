import Foundation

/// The logins an iPhone, iPad or Mac seals for an Apple TV
/// (apple-tv-login-from-iphone/every-kind-of-source-with-a-login):
/// `{"v":1,"logins":[{"source":"<uuid>","username":"…","password":"…","login":"…"}]}`.
/// Each login matches the Keychain item for its source: a Stalker portal
/// keeps the MAC address in `username` and its optional portal login in
/// `login`. Printing it shows counts only.
public struct LoginPayload: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The version this build writes and reads.
    public static let version = 1

    /// One source's login.
    public struct Login: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        public var source: UUID
        public var username: String
        public var password: String
        /// A Stalker portal's own login, when it has one.
        public var login: String?

        public init(source: UUID, username: String, password: String, login: String? = nil) {
            self.source = source
            self.username = username
            self.password = password
            self.login = login
        }

        public var description: String { "Login" }
        public var debugDescription: String { description }
    }

    public var version: Int
    public var logins: [Login]

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case logins
    }

    public init(logins: [Login]) {
        version = Self.version
        self.logins = logins
    }

    /// Why sealed bytes did not read as a payload.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// From a newer Antenna.
        case unknownVersion(Int)
        /// Not a payload at all.
        case damaged
    }

    /// The JSON this build seals.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // A struct of strings and a UUID always encodes.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads an opened payload. Rejects any version but 1.
    public init(decoding data: Data) throws(Error) {
        struct Version: Decodable {
            var version: Int
            enum CodingKeys: String, CodingKey { case version = "v" }
        }
        guard let read = try? JSONDecoder().decode(Version.self, from: data) else { throw .damaged }
        guard read.version == Self.version else { throw .unknownVersion(read.version) }
        guard let payload = try? JSONDecoder().decode(Self.self, from: data) else { throw .damaged }
        self = payload
    }

    public var description: String {
        logins.count == 1 ? "LoginPayload(1 login)" : "LoginPayload(\(logins.count) logins)"
    }

    public var debugDescription: String { description }
}

/// Which sources a code on the Apple TV asks logins for
/// (apple-tv-login-from-iphone/every-kind-of-source-with-a-login): those
/// without a login on this device, of a kind with a login, a Channels DVR
/// server only when it has a proxy login, the first eight in sort order.
public enum LoginRequestPlan {
    /// One stored source as the TV sees it.
    public struct Candidate: Equatable, Sendable {
        public var id: UUID
        public var kind: SourceKind
        /// True when the record names a Keychain item.
        public var hasCredentialKey: Bool
        /// True when that item is on this device.
        public var hasLogin: Bool
        public var sortOrder: Int

        public init(id: UUID, kind: SourceKind, hasCredentialKey: Bool, hasLogin: Bool, sortOrder: Int) {
            self.id = id
            self.kind = kind
            self.hasCredentialKey = hasCredentialKey
            self.hasLogin = hasLogin
            self.sortOrder = sortOrder
        }
    }

    /// True for a kind whose login a code can carry. Channels DVR has one
    /// only when the record names a Keychain item.
    public static func carriesLogin(_ kind: SourceKind, hasCredentialKey: Bool) -> Bool {
        switch kind {
        case .xtream, .stalker, .jellyfin: true
        case .channelsDVR: hasCredentialKey
        case .m3u, .m3uFile: false
        }
    }

    /// The sources to ask for, at most eight, in sort order.
    public static func sources(_ candidates: [Candidate]) -> [UUID] {
        candidates
            .filter { !$0.hasLogin && carriesLogin($0.kind, hasCredentialKey: $0.hasCredentialKey) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(SetupLink.sourceLimit)
            .map(\.id)
    }
}
