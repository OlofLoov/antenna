import Foundation

/// A movie or series as the Movies and Series sections show it, from any
/// Xtream source (movies-and-series-browsing).
public struct ShelfTitle: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case movie, series
    }

    /// The title id, `xtream#<host>#vod#<id>` or `xtream#<host>#series#<id>`.
    public var id: String
    public var kind: Kind
    public var sourceID: UUID
    public var name: String
    public var posterURL: URL?
    /// When a movie was added or a series last changed; the order of the
    /// banner and Recently added.
    public var added: Date?
    /// The provider's category name, nil when the row has none.
    public var category: String?
    /// A movie's file extension for its playable address, such as "mkv".
    public var containerExtension: String?
    /// The list row's rating, nil when the provider sends none. The page
    /// prefers the info call's.
    public var rating: Double?

    public init(
        id: String, kind: Kind, sourceID: UUID, name: String, posterURL: URL? = nil, added: Date? = nil, category: String? = nil,
        containerExtension: String? = nil, rating: Double? = nil
    ) {
        self.rating = rating
        self.id = id
        self.kind = kind
        self.sourceID = sourceID
        self.name = name
        self.posterURL = posterURL
        self.added = added
        self.category = category
        self.containerExtension = containerExtension
    }

    /// A movie row, its category named from `categories` (category id to name).
    public init(movie: VODItem, sourceID: UUID, categories: [String: String]) {
        self.init(
            id: movie.id, kind: .movie, sourceID: sourceID, name: movie.name, posterURL: movie.posterURL, added: movie.added,
            category: movie.categoryID.flatMap { categories[$0] }, containerExtension: movie.containerExtension, rating: movie.rating)
    }

    /// A series row; series order by when they last changed
    /// (movies-and-series-browsing/series-work-the-same-way).
    public init(series: Series, sourceID: UUID, categories: [String: String]) {
        self.init(
            id: series.id, kind: .series, sourceID: sourceID, name: series.name, posterURL: series.posterURL, added: series.lastModified,
            category: series.categoryID.flatMap { categories[$0] }, rating: series.rating)
    }

    /// The key progress and My list use for this title.
    public var activityKey: ActivityKey {
        ActivityKey(titleID: id, sourceID: sourceID)
    }

    /// Dated titles newest first, then undated ones in the order given.
    static func newestFirst(_ titles: [ShelfTitle]) -> [ShelfTitle] {
        // Sorts dates with indices, not whole titles: 50 000 titles sort in milliseconds.
        var dated: [(added: Double, index: Int)] = []
        dated.reserveCapacity(titles.count)
        var undated: [Int] = []
        for (index, title) in titles.enumerated() {
            if let added = title.added {
                dated.append((added.timeIntervalSinceReferenceDate, index))
            } else {
                undated.append(index)
            }
        }
        dated.sort { $0.added != $1.added ? $0.added > $1.added : $0.index < $1.index }
        var sorted: [ShelfTitle] = []
        sorted.reserveCapacity(titles.count)
        for entry in dated { sorted.append(titles[entry.index]) }
        for index in undated { sorted.append(titles[index]) }
        return sorted
    }
}
