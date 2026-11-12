import Foundation

/// What the user changed about the group list: hidden, locked, renamed and
/// reordered groups, and the groups they made. The app builds it from its
/// synced records; the catalogue applies it so every screen that lists
/// groups follows it (group-management capability).
///
/// `GroupRules()` changes nothing: every catalogue query gives the same
/// result as a catalogue built without rules.
public struct GroupRules: Hashable, Sendable {
    /// A channel the user put in their own group, by its id and source.
    public struct Member: Hashable, Sendable {
        public var channelID: String
        public var sourceID: UUID

        public init(channelID: String, sourceID: UUID) {
            self.channelID = channelID
            self.sourceID = sourceID
        }
    }

    /// A group the user made, with its channels in the user's order.
    public struct OwnGroup: Hashable, Sendable {
        public var id: UUID
        public var name: String
        public var members: [Member]

        public init(id: UUID, name: String, members: [Member] = []) {
            self.id = id
            self.name = name
            self.members = members
        }
    }

    /// Groups left out of the channel lists. `.favorites` and `.recents`
    /// are ignored.
    public var hidden: Set<CatalogueGroup>
    /// Groups whose channels are out of reach while locks are closed.
    /// `.favorites`, `.recents` and `.all` are ignored.
    public var locked: Set<CatalogueGroup>
    /// The user's names for provider groups. Empty or whitespace-only names
    /// are ignored, so the provider's name shows.
    public var names: [CatalogueGroup: String]
    /// Sort positions the user set. Groups with a position come first,
    /// lowest first; the rest follow in their usual order.
    public var order: [CatalogueGroup: Int]
    /// The user's own groups, in creation order.
    public var ownGroups: [OwnGroup]
    /// True while the locks are open on this device.
    public var locksOpen: Bool

    public init(
        hidden: Set<CatalogueGroup> = [], locked: Set<CatalogueGroup> = [], names: [CatalogueGroup: String] = [:],
        order: [CatalogueGroup: Int] = [:], ownGroups: [OwnGroup] = [], locksOpen: Bool = false
    ) {
        self.hidden = hidden
        self.locked = locked
        self.names = names
        self.order = order
        self.ownGroups = ownGroups
        self.locksOpen = locksOpen
    }

    /// True when these rules change no catalogue query.
    var isEmpty: Bool {
        hidden.subtracting([.favorites, .recents]).isEmpty && effectiveLocks.isEmpty && names.isEmpty && order.isEmpty
            && ownGroups.isEmpty
    }

    /// The locks that apply now: none while open, and never on Favorites,
    /// Recents or All channels.
    var effectiveLocks: Set<CatalogueGroup> {
        locksOpen ? [] : locked.subtracting([.favorites, .recents, .all])
    }

    /// Whether `channelID` may be saved into an own group. An id that holds
    /// a link may carry the provider login, so it is refused. M3U ids hold
    /// none since m3u-playlists/stable-and-unique-ids.
    public static func canSave(channelID: String) -> Bool {
        !channelID.contains("://")
    }
}
