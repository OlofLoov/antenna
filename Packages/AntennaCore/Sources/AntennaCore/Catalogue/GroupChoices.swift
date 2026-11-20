import Foundation

/// The groups a group list offers for what the user typed: the iPhone
/// Groups sheet and the iPad and Mac sidebar
/// (live-tv-on-iphone-ipad-mac/find-a-group-among-many). A name matches the
/// way `ChannelFilter` matches a channel: case and accents ignored, every
/// typed word somewhere in it. A blank query offers every group.
public struct GroupChoices: Sendable, Equatable {
    /// One group in the list.
    public struct Choice: Sendable, Hashable {
        public let group: CatalogueGroup
        /// The group's place in `Catalogue.groups`; nil for a locked group,
        /// which that list leaves out.
        public let index: Int?

        public init(group: CatalogueGroup, index: Int?) {
            self.group = group
            self.index = index
        }
    }

    /// Favorites, Recents, New and All channels, whichever the catalogue
    /// lists and the query matches, in that order.
    public let builtIn: [Choice]
    /// The source groups and own groups that match, in the catalogue's order.
    public let groups: [Choice]
    /// The locked groups that match while the locks are closed, in the
    /// user's order.
    public let locked: [Choice]

    /// `label` gives the name a group shows, so a built-in group matches by
    /// its name in the app's language and a renamed group by its new name.
    public init<Token>(_ catalogue: Catalogue<Token>, query: String, label: (CatalogueGroup) -> String) {
        let filter = ChannelFilter(query)
        let listed = catalogue.groups.enumerated().filter { filter.matches(name: label($0.element), number: nil) }.map {
            Choice(group: $0.element, index: $0.offset)
        }
        builtIn = listed.filter(\.group.isBuiltIn)
        groups = listed.filter { !$0.group.isBuiltIn }
        locked = catalogue.lockedGroups.filter { filter.matches(name: label($0), number: nil) }.map { Choice(group: $0, index: nil) }
    }

    /// True when no group matches.
    public var isEmpty: Bool { builtIn.isEmpty && groups.isEmpty && locked.isEmpty }
}

extension CatalogueGroup {
    /// True for the groups the app makes itself, which head every group list:
    /// Favorites, Recents, New and All channels.
    public var isBuiltIn: Bool {
        switch self {
        case .favorites, .recents, .new, .all: true
        case .named, .ungrouped, .own: false
        }
    }
}
