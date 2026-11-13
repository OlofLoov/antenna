import Foundation

/// What the banner says about a title beyond its list row: the year, the
/// length or number of seasons, the description and the age rating
/// (movies-and-series-browsing/new-titles-up-front). Read from the
/// provider's info call for the titles the banner shows.
public struct ShelfDetails: Sendable, Hashable {
    public var year: Int?
    /// A movie's length in seconds.
    public var duration: Double?
    /// A series' number of seasons.
    public var seasons: Int?
    public var plot: String?
    public var ageRating: String?
    /// The first backdrop the provider lists, the banner's art when present.
    public var backdropURL: URL?

    public init(
        year: Int? = nil, duration: Double? = nil, seasons: Int? = nil, plot: String? = nil, ageRating: String? = nil,
        backdropURL: URL? = nil
    ) {
        self.year = year
        self.duration = duration
        self.seasons = seasons
        self.plot = plot
        self.ageRating = ageRating
        self.backdropURL = backdropURL
    }

    public init(movie info: VODInfo) {
        self.init(
            year: info.year, duration: info.duration, plot: info.plot, ageRating: info.ageRating, backdropURL: info.backdropURLs.first)
    }

    public init(series info: SeriesInfo) {
        self.init(
            year: info.year, seasons: info.seasonCount, plot: info.plot, ageRating: info.ageRating,
            backdropURL: info.backdropURLs.first)
    }
}

/// The banner's words for one title.
public struct BannerText: Sendable, Hashable {
    /// "Recently added · Thriller", or "Recently added" without a category.
    public var eyebrow: String
    public var title: String
    /// The year and the length, or for a series the year and the seasons.
    public var facts: [String]
    /// "4K" and the age badge for a movie; a series shows none.
    public var badges: [String]
    public var description: String?

    public init(_ title: ShelfTitle, details: ShelfDetails?) {
        eyebrow = (["Recently added"] + [title.category].compactMap(\.self)).joined(separator: " · ")
        self.title = title.name
        let span = title.kind == .movie ? ShelfText.length(details?.duration) : details?.seasons.flatMap(ShelfText.seasons)
        facts = [details?.year.map(String.init), span].compactMap(\.self)
        if title.kind == .movie {
            badges = [ShelfText.is4K(title.name) ? "4K" : nil, ShelfText.ageBadge(details?.ageRating)].compactMap(\.self)
        } else {
            badges = []
        }
        let plot = details?.plot?.trimmingCharacters(in: .whitespacesAndNewlines)
        description = plot?.isEmpty == false ? plot : nil
    }
}

/// Which banner title shows, moved on by the clock or by hand
/// (movies-and-series-browsing/new-titles-up-front). Paging wraps at
/// either end.
public struct BannerPager: Sendable, Hashable {
    /// How long each title shows before the banner moves on by itself.
    public static let interval: Duration = .seconds(8)

    public private(set) var index = 0
    public private(set) var count = 0

    public init(count: Int = 0) {
        self.count = max(0, count)
    }

    /// Moves `steps` titles on, or back for a negative number, wrapping.
    public mutating func page(_ steps: Int) {
        guard count >= 1 else { return }
        index = ((index + steps) % count + count) % count
    }

    /// Shows the title at `index`, kept within the titles.
    public mutating func show(_ index: Int) {
        guard count >= 1 else { return }
        self.index = min(max(0, index), count - 1)
    }

    /// The number of titles changed; the shown one stays when it still exists.
    public mutating func resize(_ count: Int) {
        self.count = max(0, count)
        index = max(0, min(index, self.count - 1))
    }

    /// True when the banner should move on by itself: more than one title,
    /// nobody interacting with it and Reduce Motion off.
    public static func rotates(count: Int, interacting: Bool, reduceMotion: Bool) -> Bool {
        count > 1 && !interacting && !reduceMotion
    }
}

/// The picture behind a banner title
/// (movies-and-series-browsing/new-titles-up-front).
public enum BannerArt: Sendable, Hashable {
    /// A wide picture that fills the banner.
    case backdrop(URL)
    /// The 2:3 poster. A wide banner shows it sharp beside the copy, over a
    /// blurred copy of itself.
    case poster(URL)

    /// How long the banner waits for a title's info call before it settles
    /// for the poster.
    public static let patience: Duration = .seconds(1.5)

    /// The title's backdrop once its info call has answered with one, its
    /// poster once the call has answered without one or the banner has
    /// waited `patience`, and nil before that. While it is nil the banner
    /// keeps the picture it already shows.
    public static func choose(details: ShelfDetails?, answered: Bool, waited: Bool, poster: URL?) -> BannerArt? {
        if let backdrop = details?.backdropURL { return .backdrop(backdrop) }
        guard answered || waited else { return nil }
        return poster.map(BannerArt.poster)
    }

    public var url: URL {
        switch self {
        case .backdrop(let url), .poster(let url): url
        }
    }
}
