import Foundation

/// A title on My list (watch-progress-sync/add-and-remove-from-my-list).
public struct ListEntry: Sendable, Hashable {
    /// The record's own id, the last tie-break between copies.
    public var id: String
    /// A movie `xtream#<host>#vod#<id>` or a series `xtream#<host>#series#<id>`.
    public var titleID: String
    public var sourceID: UUID?
    public var addedAt: Date

    public init(id: String, titleID: String, sourceID: UUID?, addedAt: Date) {
        self.id = id
        self.titleID = titleID
        self.sourceID = sourceID
        self.addedAt = addedAt
    }

    /// What the entry names, for the movies and series lists.
    public enum Kind: Sendable, Hashable {
        case movie, series
    }

    /// Nil for a title of any other kind, kept but in neither list
    /// (watch-progress-sync/my-list-shows-movies-and-series-separately).
    public var kind: Kind? {
        switch XtreamTitleID(parsing: titleID)?.kind {
        case .vod: .movie
        case .series: .series
        default: nil
        }
    }

    /// False for a damaged record with no title or no source.
    public var isUsable: Bool {
        !titleID.isEmpty && sourceID != nil
    }

    /// One entry per title and source: the earliest added, then the lower id.
    public static func resolve(_ copies: [ListEntry]) -> Resolution<ListEntry> {
        Resolution(copies, usable: \.isUsable, key: { ActivityKey(titleID: $0.titleID, sourceID: $0.sourceID) }) { lhs, rhs in
            lhs.addedAt != rhs.addedAt ? lhs.addedAt < rhs.addedAt : lhs.id < rhs.id
        }
    }

    /// The entries of `kind`, most recently added first.
    public static func list(_ kind: Kind, in entries: [ListEntry]) -> [ListEntry] {
        entries.filter { $0.kind == kind }.sorted { lhs, rhs in
            lhs.addedAt != rhs.addedAt ? lhs.addedAt > rhs.addedAt : lhs.id < rhs.id
        }
    }
}
