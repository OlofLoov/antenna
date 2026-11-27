import Foundation

/// One thing a phone, iPad or Mac asks an Apple TV to play
/// (play-on-apple-tv/a-request-holds-no-link-and-no-login). It names the
/// source by its id and the item by keys the sender derives from the
/// provider's ids, never the ids themselves, since a playlist channel's id
/// holds its stream link and an Xtream id holds the server's host. A
/// request carries no link, address, username, password or token, and
/// prints its kind and ids only.
public struct PlayRequest: Sendable, Hashable, Codable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The format this build writes and reads.
    public static let currentVersion = 1

    /// What to play, by key.
    public enum Item: Sendable, Hashable {
        /// A channel live.
        case channel(key: String)
        /// A programme in the guide: live while it airs, its catch-up
        /// recording from its start once it has ended.
        case programme(channelKey: String, start: Date, end: Date)
        /// A film, from its saved place unless the request gives a position.
        case movie(key: String)
        /// One episode of a series.
        case episode(seriesKey: String, episodeKey: String)
    }

    public var version: Int
    public var id: UUID
    /// The sending device's id.
    public var sender: UUID
    /// The sending device's name, as "Anna's iPhone".
    public var senderName: String
    /// The Apple TV's device id.
    public var target: UUID
    /// The source's id, the same on every device of the account.
    public var source: UUID
    public var item: Item
    /// Seconds into a film or episode; nil plays from the TV's saved place.
    public var startPosition: TimeInterval?
    /// The item's name for the TV's banner and offer, as "Salt Road".
    public var displayTitle: String
    public var created: Date

    public init(
        version: Int = Self.currentVersion, id: UUID = UUID(), sender: UUID, senderName: String, target: UUID, source: UUID,
        item: Item, startPosition: TimeInterval? = nil, displayTitle: String, created: Date
    ) {
        self.version = version
        self.id = id
        self.sender = sender
        self.senderName = senderName
        self.target = target
        self.source = source
        self.item = item
        self.startPosition = startPosition
        self.displayTitle = displayTitle
        self.created = created
    }

    public var description: String { "PlayRequest(v\(version), \(id), \(item))" }
    public var debugDescription: String { description }
}

// MARK: Expiry

extension PlayRequest {
    /// How long a live channel, or a programme on now, waits for a TV.
    public static let liveLifetime: TimeInterval = 300
    /// How long a film, an episode or a catch-up recording waits.
    public static let titleLifetime: TimeInterval = 21_600

    /// True for a channel or a programme that had not ended when sent
    /// (play-on-apple-tv/requests-expire-and-leave-no-trace).
    public var isLive: Bool {
        switch item {
        case .channel: true
        case .programme(_, _, let end): end > created
        case .movie, .episode: false
        }
    }

    /// When the request stops being worth offering: 5 minutes after it was
    /// sent for live TV, 6 hours for anything else.
    public var expires: Date {
        created.addingTimeInterval(isLive ? Self.liveLifetime : Self.titleLifetime)
    }

    /// True once `now` is at or past `expires`.
    public func isExpired(at now: Date) -> Bool {
        now >= expires
    }
}

// MARK: Coding

extension PlayRequest {
    private enum Keys: String, CodingKey {
        case version = "v"
        case id, sender, senderName, target, source, item, start, title, created
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        version = try container.decode(Int.self, forKey: .version)
        id = try container.decode(UUID.self, forKey: .id)
        sender = try container.decode(UUID.self, forKey: .sender)
        senderName = try container.decode(String.self, forKey: .senderName)
        target = try container.decode(UUID.self, forKey: .target)
        source = try container.decode(UUID.self, forKey: .source)
        item = try container.decode(Item.self, forKey: .item)
        startPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .start)
        displayTitle = try container.decode(String.self, forKey: .title)
        created = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .created))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(sender, forKey: .sender)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(target, forKey: .target)
        try container.encode(source, forKey: .source)
        try container.encode(item, forKey: .item)
        try container.encodeIfPresent(startPosition, forKey: .start)
        try container.encode(displayTitle, forKey: .title)
        try container.encode(created.timeIntervalSince1970, forKey: .created)
    }

    /// The request as JSON, the bytes a network frame and an iCloud record carry.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Reads a request this build or an older one wrote. A newer version
    /// throws `PlayMessage.DecodeError.unsupportedVersion`.
    public init(decoding data: Data) throws(PlayMessage.DecodeError) {
        let version: Int
        do {
            version = try JSONDecoder().decode(Versioned.self, from: data).version
        } catch {
            throw .malformed
        }
        guard version <= Self.currentVersion else {
            throw .unsupportedVersion(requestID: try? JSONDecoder().decode(Identified.self, from: data).id)
        }
        do {
            self = try JSONDecoder().decode(PlayRequest.self, from: data)
        } catch {
            throw .malformed
        }
    }

    private struct Versioned: Decodable {
        var version: Int
        enum CodingKeys: String, CodingKey { case version = "v" }
    }

    private struct Identified: Decodable {
        var id: UUID
    }
}

extension PlayRequest.Item: Codable, CustomStringConvertible {
    private enum Keys: String, CodingKey {
        case kind, channel, start, end, title, series, episode
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "channel":
            self = .channel(key: try container.decode(String.self, forKey: .channel))
        case "programme":
            self = .programme(
                channelKey: try container.decode(String.self, forKey: .channel),
                start: Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .start)),
                end: Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .end)))
        case "movie":
            self = .movie(key: try container.decode(String.self, forKey: .title))
        case "episode":
            self = .episode(
                seriesKey: try container.decode(String.self, forKey: .series),
                episodeKey: try container.decode(String.self, forKey: .episode))
        case let kind:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown item kind \(kind)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .channel(let key):
            try container.encode("channel", forKey: .kind)
            try container.encode(key, forKey: .channel)
        case .programme(let channelKey, let start, let end):
            try container.encode("programme", forKey: .kind)
            try container.encode(channelKey, forKey: .channel)
            try container.encode(start.timeIntervalSince1970, forKey: .start)
            try container.encode(end.timeIntervalSince1970, forKey: .end)
        case .movie(let key):
            try container.encode("movie", forKey: .kind)
            try container.encode(key, forKey: .title)
        case .episode(let seriesKey, let episodeKey):
            try container.encode("episode", forKey: .kind)
            try container.encode(seriesKey, forKey: .series)
            try container.encode(episodeKey, forKey: .episode)
        }
    }

    public var description: String {
        switch self {
        case .channel(let key): "channel \(key)"
        case .programme(let channelKey, let start, _): "programme \(channelKey)@\(Int(start.timeIntervalSince1970))"
        case .movie(let key): "movie \(key)"
        case .episode(let seriesKey, let episodeKey): "episode \(seriesKey)/\(episodeKey)"
        }
    }
}
