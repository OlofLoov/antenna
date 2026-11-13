import Foundation

/// One source's guide choices as they sync: the order of its guides, which
/// are turned off, the links the user added and the hand-picked matches
/// (guide-sources-and-channel-mapping/settings-follow-you-to-every-device).
///
/// Every entry carries the time it last changed, and a removal is kept as a
/// tombstone, so two devices' copies merge entry by entry. Nothing here holds
/// a secret: an added link with a login keeps only its scheme, host and port,
/// and the whole link lives in the Keychain.
public struct GuideSettings: Codable, Sendable, Equatable {
    /// A guide turned on or off.
    public struct Flag: Codable, Sendable, Equatable {
        public var enabled: Bool
        public var modifiedAt: Date

        public init(enabled: Bool, modifiedAt: Date) {
            self.enabled = enabled
            self.modifiedAt = modifiedAt
        }
    }

    /// A link the user added. `plain` is the whole link when it holds no
    /// login, query or deep path; otherwise the link is in the Keychain.
    public struct Link: Codable, Sendable, Equatable {
        public var scheme: String
        public var host: String
        public var port: Int?
        public var plain: URL?
        public var addedAt: Date
        public var modifiedAt: Date
        public var removed: Bool

        public init(
            scheme: String, host: String, port: Int? = nil, plain: URL? = nil, addedAt: Date, modifiedAt: Date? = nil, removed: Bool = false
        ) {
            self.scheme = scheme
            self.host = host
            self.port = port
            self.plain = plain
            self.addedAt = addedAt
            self.modifiedAt = modifiedAt ?? addedAt
            self.removed = removed
        }
    }

    /// A channel's match. `entryID` is the guide entry picked by hand; nil
    /// means the user undid a match by name and wants none. A removed match
    /// is a tombstone: the channel goes back to its own guide id.
    public struct Match: Codable, Sendable, Equatable {
        public var entryID: String?
        public var modifiedAt: Date
        public var removed: Bool

        public init(entryID: String?, modifiedAt: Date, removed: Bool = false) {
            self.entryID = entryID
            self.modifiedAt = modifiedAt
            self.removed = removed
        }
    }

    /// Guide references as `GuideReference.storageKey`, top first. Guides
    /// missing from it follow in their default order.
    public var order: [String]
    public var orderModifiedAt: Date?
    /// Per `GuideReference.storageKey`.
    public var flags: [String: Flag]
    /// Per added link id.
    public var links: [String: Link]
    /// Per channel id.
    public var matches: [String: Match]

    public init(
        order: [String] = [], orderModifiedAt: Date? = nil, flags: [String: Flag] = [:], links: [String: Link] = [:],
        matches: [String: Match] = [:]
    ) {
        self.order = order
        self.orderModifiedAt = orderModifiedAt
        self.flags = flags
        self.links = links
        self.matches = matches
    }

    /// Settings with nothing chosen.
    public static let empty = GuideSettings()

    private enum CodingKeys: String, CodingKey {
        case order, orderModifiedAt, flags, links, matches
    }

    /// Missing fields read as empty, so a payload written by a later version
    /// with fewer or more fields still decodes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decodeIfPresent([String].self, forKey: .order) ?? []
        orderModifiedAt = try container.decodeIfPresent(Date.self, forKey: .orderModifiedAt)
        flags = try container.decodeIfPresent([String: Flag].self, forKey: .flags) ?? [:]
        links = try container.decodeIfPresent([String: Link].self, forKey: .links) ?? [:]
        matches = try container.decodeIfPresent([String: Match].self, forKey: .matches) ?? [:]
    }

    /// Hand-picked entries and undone name matches per channel id, without
    /// tombstones. A nil value means "no match by name".
    public var activeMatches: [String: String?] {
        var result: [String: String?] = [:]
        for (channelID, match) in matches where !match.removed {
            result[channelID] = .some(match.entryID)
        }
        return result
    }

    /// Moves each active match under an old id that `ids` names to its new
    /// id, stamped `date`, and leaves a tombstone under the old id so a merge
    /// with an older copy does not bring it back. A new id that already has
    /// an active match keeps it. A new id holding a stream link is not
    /// taken. Returns true when something changed
    /// (source-management/switching-to-xtream-keeps-what-was-remembered-per-channel).
    @discardableResult
    public mutating func moveMatches(_ ids: [String: String], at date: Date) -> Bool {
        var changed = false
        for (old, match) in matches where !match.removed {
            guard let new = ids[old], new != old, !new.contains("://") else { continue }
            if matches[new].map({ $0.removed }) ?? true {
                matches[new] = Match(entryID: match.entryID, modifiedAt: date)
            }
            matches[old] = Match(entryID: nil, modifiedAt: date, removed: true)
            changed = true
        }
        return changed
    }

    /// Added links that were not removed, oldest first.
    public var activeLinks: [(id: String, link: Link)] {
        links.filter { !$0.value.removed }.map { (id: $0.key, link: $0.value) }
            .sorted { ($0.link.addedAt, $0.id) < ($1.link.addedAt, $1.id) }
    }
}
