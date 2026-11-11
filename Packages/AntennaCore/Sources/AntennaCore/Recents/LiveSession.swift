import Foundation

/// Where the user left iPhone, iPad or Mac: the tab and the Live group they
/// picked (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
/// The channel that played is the last channel, stored on its own.
public struct LiveSession: Codable, Hashable, Sendable {
    /// The tabs a session can name. The app decides which of them it restores.
    public enum Tab: String, Codable, Sendable {
        case live, guide, movies, series, search, settings
    }

    /// A Live group in a form that survives a relaunch.
    public struct Group: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case favorites, recents, all, named, ungrouped
        }

        public var kind: Kind
        public var sourceID: UUID?
        public var name: String?

        public init(_ group: CatalogueGroup) {
            switch group {
            case .favorites: kind = .favorites
            case .recents: kind = .recents
            case .all: kind = .all
            case .named(let source, let name):
                kind = .named
                sourceID = source
                self.name = name
            case .ungrouped(let source):
                kind = .ungrouped
                sourceID = source
            }
        }

        /// Nil when a named or ungrouped group lost its source or name.
        public var group: CatalogueGroup? {
            switch kind {
            case .favorites: .favorites
            case .recents: .recents
            case .all: .all
            case .named: sourceID.flatMap { id in name.map { .named(id, $0) } }
            case .ungrouped: sourceID.map(CatalogueGroup.ungrouped)
            }
        }
    }

    public var tab: Tab?
    public var group: Group?

    public init(tab: Tab? = nil, group: CatalogueGroup? = nil) {
        self.tab = tab
        self.group = group.map(Group.init)
    }

    /// Forgets the group when it belongs to `source`
    /// (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
    public mutating func remove(source: UUID) {
        if group?.sourceID == source { group = nil }
    }

    /// The session stored as `data`; an empty session when `data` is nil or
    /// cannot be read.
    public init(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            self.init()
            return
        }
        self = decoded
    }

    public var data: Data? {
        try? JSONEncoder().encode(self)
    }
}
