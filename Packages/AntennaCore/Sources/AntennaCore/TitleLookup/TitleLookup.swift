import Foundation

/// Finds the movie database entry for one title (title-metadata). The
/// Code Crave lookup service will answer it; until that exists, Debug
/// builds can use `MockTitleLookup` and Release builds have no lookup.
public protocol TitleLookup: Sendable {
    /// The match for `query`, nil when the database has no confident match.
    /// Throws when the database could not be asked.
    func match(_ query: TitleLookupQuery) async throws -> TitleMatch?
}

/// What a lookup sends: a title's kind, cleaned name, year and the
/// database ids its provider gave, and nothing else
/// (title-metadata/only-what-is-needed-is-looked-up).
public struct TitleLookupQuery: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case movie, tv
    }

    public var kind: Kind
    public var name: String
    public var year: Int?
    public var tmdbID: Int?
    public var imdbID: String?

    public init(kind: Kind, name: String, year: Int? = nil, tmdbID: Int? = nil, imdbID: String? = nil) {
        self.kind = kind
        self.name = name
        self.year = year
        self.tmdbID = tmdbID
        self.imdbID = imdbID
    }

    /// `title`'s name cleaned of provider tags. The year is the provider's
    /// when it gave one, else the one in the name.
    public init(_ title: ShelfTitle, year: Int? = nil, tmdbID: Int? = nil, imdbID: String? = nil) {
        let cleaned = TitleName.clean(title.name)
        self.init(
            kind: title.kind == .movie ? .movie : .tv, name: cleaned.name, year: year ?? cleaned.year, tmdbID: tmdbID, imdbID: imdbID)
    }
}

/// One database entry and what it brings to a title page.
public struct TitleMatch: Sendable, Hashable, Codable {
    public var tmdbID: Int
    public var details: TitleDetails
    /// In any order; `Score.ordered` gives the page's order.
    public var scores: [Score]
    /// True for `MockTitleLookup`'s made-up answers, which the page marks
    /// as a sample.
    public var isSample: Bool

    public init(tmdbID: Int, details: TitleDetails = TitleDetails(), scores: [Score] = [], isSample: Bool = false) {
        self.tmdbID = tmdbID
        self.details = details
        self.scores = scores
        self.isSample = isSample
    }
}

/// The fields the database can fill when the provider left them out
/// (title-metadata/details-the-provider-left-out-come-from-the-database).
public struct TitleDetails: Sendable, Hashable, Codable {
    public var plot: String?
    public var year: Int?
    /// Seconds.
    public var duration: TimeInterval?
    public var genre: String?
    public var backdropURL: URL?
    public var cast: String?
    public var director: String?

    public init(
        plot: String? = nil, year: Int? = nil, duration: TimeInterval? = nil, genre: String? = nil, backdropURL: URL? = nil,
        cast: String? = nil, director: String? = nil
    ) {
        self.plot = plot
        self.year = year
        self.duration = duration
        self.genre = genre
        self.backdropURL = backdropURL
        self.cast = cast
        self.director = director
    }
}

/// A title's score on one site, as the service sends it: a value on the
/// site's scale (title-detail-and-episode-picker/scores-from-other-sites).
public struct Score: Sendable, Hashable, Codable {
    /// The sites in the page's fixed order.
    public enum Site: String, Sendable, Hashable, Codable, CaseIterable {
        case imdb, rottenTomatoes, metacritic, tmdb

        /// "IMDb", "Rotten Tomatoes", "Metacritic", "TMDB".
        public var name: String {
            switch self {
            case .imdb: "IMDb"
            case .rottenTomatoes: "Rotten Tomatoes"
            case .metacritic: "Metacritic"
            case .tmdb: "TMDB"
            }
        }
    }

    public var site: Site
    public var value: Double
    public var scale: Double

    public init(site: Site, value: Double, scale: Double) {
        self.site = site
        self.value = value
        self.scale = scale
    }

    /// "7.8" for IMDb, "81" for Metacritic, "92%" for Rotten Tomatoes and
    /// "74%" for TMDB; nil for a value that is not a score.
    public var text: String? {
        guard let share else { return nil }
        switch site {
        case .imdb:
            let tenths = Int((share * 100).rounded())
            return "\(tenths / 10).\(tenths % 10)"
        case .metacritic:
            return "\(Int((share * 100).rounded()))"
        case .rottenTomatoes, .tmdb:
            return "\(Int((share * 100).rounded()))%"
        }
    }

    /// What VoiceOver reads: "TMDB user score 74 percent", in the
    /// language of `locale`.
    public func spoken(_ locale: Locale = .autoupdatingCurrent) -> String? {
        guard let share, let text else { return nil }
        let words = Words(locale)
        let percent = Int((share * 100).rounded())
        switch site {
        case .imdb: return words("IMDb \(text) out of 10")
        case .metacritic: return words("Metacritic \(percent) out of 100")
        case .rottenTomatoes: return words("Rotten Tomatoes \(percent) percent")
        case .tmdb: return words("TMDB user score \(percent) percent")
        }
    }

    /// The value as a share of the scale; nil when it is 0, negative, over
    /// the scale or not a number.
    private var share: Double? {
        guard value.isFinite, scale.isFinite, scale > 0, value > 0, value <= scale else { return nil }
        return value / scale
    }

    /// One score per site in the fixed order IMDb, Rotten Tomatoes,
    /// Metacritic, TMDB, leaving out sites with no usable score.
    public static func ordered(_ scores: [Score]) -> [Score] {
        Site.allCases.compactMap { site in scores.first { $0.site == site && $0.text != nil } }
    }
}
