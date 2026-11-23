import Foundation

/// What a profile watched last on one device: a live channel, or a movie or
/// a series episode named by ids, never by a link
/// (session-restore-and-recently-watched/what-was-watched-last).
///
/// The JSON form is `{}` for a channel and
/// `{"title": {"sourceID": "<uuid>", "titleID": "<id>", "kind": "series", "episodeID": "<id>"}}`
/// for a title.
public struct LastWatched: Codable, Hashable, Sendable {
    /// A movie, or the series an episode belongs to with that episode.
    public struct Title: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case movie, series
        }

        public var sourceID: UUID
        public var titleID: String
        public var kind: Kind
        /// The episode that played, nil for a movie.
        public var episodeID: String?

        public init(sourceID: UUID, titleID: String, kind: Kind, episodeID: String? = nil) {
            self.sourceID = sourceID
            self.titleID = titleID
            self.kind = kind
            self.episodeID = episodeID
        }

        /// Nil when `title` is a series or its id holds a link.
        public init?(movie title: ShelfTitle) {
            guard title.kind == .movie, LastChannelKey.canStore(title.id) else { return nil }
            self.init(sourceID: title.sourceID, titleID: title.id, kind: .movie)
        }

        /// Nil when `series` is a movie or either id holds a link.
        public init?(episode: Episode, of series: ShelfTitle) {
            guard series.kind == .series, LastChannelKey.canStore(series.id), LastChannelKey.canStore(episode.id) else { return nil }
            self.init(sourceID: series.sourceID, titleID: series.id, kind: .series, episodeID: episode.id)
        }

        /// The section the title is listed in.
        public var shelfKind: ShelfTitle.Kind {
            kind == .movie ? .movie : .series
        }

        /// The key the title's section and its saved progress use.
        public var activityKey: ActivityKey {
            ActivityKey(titleID: titleID, sourceID: sourceID)
        }
    }

    /// Nil after a live channel.
    public var title: Title?

    public init(title: Title?) {
        self.title = title
    }

    /// A live channel was watched last.
    public static let live = LastWatched(title: nil)

    /// The value stored as `data`; nil when there is none, it cannot be
    /// read, or an id in it holds a link.
    public init?(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        if let title = decoded.title {
            guard LastChannelKey.canStore(title.titleID), title.episodeID.map(LastChannelKey.canStore) ?? true else { return nil }
        }
        self = decoded
    }

    public var data: Data? {
        try? JSONEncoder().encode(self)
    }
}
