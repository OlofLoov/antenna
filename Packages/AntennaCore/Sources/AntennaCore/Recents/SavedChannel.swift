import Foundation

/// The last channel as a device saves it for launch: enough to tune it
/// before its source's list loads, with every login taken out of its links
/// (session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads,
/// session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login).
public struct SavedChannel: Codable, Hashable, Sendable {
    /// A username and password a source's links carry. Never encoded, and
    /// printed and dumped as `Login(redacted)`.
    public struct Login: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        public var username: String
        public var password: String

        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }

        /// The `username` and `password` query values of a playlist link;
        /// nil unless both are there and not empty.
        public init?(playlistLink url: URL) {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let username = items.first(where: { $0.name == "username" })?.value, !username.isEmpty,
                let password = items.first(where: { $0.name == "password" })?.value, !password.isEmpty
            else { return nil }
            self.init(username: username, password: password)
        }

        public var description: String { "Login(redacted)" }
        public var debugDescription: String { description }
        public var customMirror: Mirror { Mirror(self, children: [:]) }
    }

    public var sourceID: UUID
    public var channelID: String
    public var name: String
    public var number: Int?
    public var minorNumber: Int?
    public var group: String?
    public var epgID: String?
    public var logo: SavedLink?
    public var link: SavedLink

    /// Nil when the channel has no key (see `LastChannelKey`), asks for
    /// headers of its own, or its stream link cannot be kept without a login
    /// (see `SavedLink`). A logo link that cannot be kept is left out.
    public init?(_ channel: Channel, logins: [Login]) {
        guard let key = LastChannelKey(channel), channel.headers == nil,
            let link = SavedLink(channel.streamURL, logins: logins)
        else { return nil }
        sourceID = key.sourceID
        channelID = key.channelID
        name = channel.name
        number = channel.number
        minorNumber = channel.minorNumber
        group = channel.group
        epgID = channel.epgID
        logo = channel.logoURL.flatMap { SavedLink($0, logins: logins) }
        self.link = link
    }

    public var key: LastChannelKey {
        LastChannelKey(sourceID: sourceID, channelID: channelID)
    }

    /// The channel with `logins` put back in its links, tagged with its
    /// source. Nil when the stream link names a login `logins` lacks.
    public func channel(logins: [Login]) -> Channel? {
        guard let url = link.url(logins: logins) else { return nil }
        return Channel(
            id: channelID, name: name, streamURL: url, group: group, logoURL: logo?.url(logins: logins), epgID: epgID,
            number: number, minorNumber: minorNumber, sourceID: sourceID)
    }

    /// True when `lhs` and `rhs` play the same stream: the same link, or
    /// links that differ only in how a login is percent-encoded.
    public static func sameStream(_ lhs: Channel, _ rhs: Channel, logins: [Login]) -> Bool {
        if lhs.streamURL == rhs.streamURL { return true }
        guard let first = SavedLink(lhs.streamURL, logins: logins) else { return false }
        return first == SavedLink(rhs.streamURL, logins: logins)
    }

    /// The channel stored as `data`; nil when `data` is nil or cannot be read.
    public init?(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = decoded
    }

    public var data: Data? {
        try? JSONEncoder().encode(self)
    }
}
