import Foundation

/// The words at the top of a movie or series page
/// (title-detail-and-episode-picker/what-the-title-is-about). Every field
/// the provider leaves out, or sends blank, is nil or left out of its list,
/// never "Unknown".
public struct TitleMetadata: Sendable, Hashable {
    /// "Movie · Thriller", or "Movie" without a category.
    public var eyebrow: String
    public var name: String
    public var kind: ShelfTitle.Kind
    /// "2024".
    public var year: String?
    /// "2 h 08 min" for a movie, "3 seasons" for a series.
    public var length: String?
    public var genre: String?
    /// The provider's "★ 7.4".
    public var rating: String?
    /// Scores from other sites in the page's order; empty when there is no
    /// match or lookups are off (title-detail-and-episode-picker/scores-from-other-sites).
    public var scores: [Score] = []
    /// True when the scores came from `MockTitleLookup`.
    public var scoresAreSample = false

    /// Year, length or seasons, genre and "★ 7.4", in that order. The
    /// provider's rating leaves when scores from other sites show
    /// (title-detail-and-episode-picker/what-the-title-is-about).
    public var facts: [String] {
        [year, length, genre, scores.isEmpty ? rating : nil].compactMap(\.self)
    }
    /// "4K" and the age badge for a movie, the age badge for a series.
    public var badges: [String]
    public var description: String?
    public var cast: String?
    public var director: String?
    /// The first backdrop, the page's art when present.
    public var backdropURL: URL?
    public var trailerURL: URL?

    /// "2024 · 2 h 08 min · Thriller · ★ 7.4", nil when there are no facts.
    public var detailsLine: String? { detailsLine(.autoupdatingCurrent) }

    /// `detailsLine` with the separator of `locale`'s language.
    public func detailsLine(_ locale: Locale) -> String? {
        facts.isEmpty ? nil : facts.joinedAsDetail(locale)
    }

    /// What the page shows before the details arrive: the eyebrow, the name,
    /// and the cast and directors when the list row gave them.
    public init(title: ShelfTitle, locale: Locale = .autoupdatingCurrent) {
        eyebrow = Self.eyebrow(title, locale: locale)
        name = title.name
        kind = title.kind
        badges = []
        cast = Self.present(title.cast)
        director = Self.present(title.director)
    }

    /// A movie's page once `get_vod_info` answered. The rating is the info
    /// call's, else the list row's.
    public init(movie title: ShelfTitle, info: VODInfo, locale: Locale = .autoupdatingCurrent) {
        self.init(title: title, locale: locale)
        let rating = info.rating ?? title.rating
        year = info.year.map(String.init)
        length = ShelfText.length(info.duration, locale: locale)
        genre = Self.present(info.genre)
        self.rating = rating.flatMap { Self.rating($0, locale: locale) }
        badges = [ShelfText.is4K(title.name) ? "4K" : nil, ShelfText.ageBadge(info.ageRating)].compactMap(\.self)
        description = Self.present(info.plot)
        cast = Self.present(info.cast) ?? Self.present(title.cast)
        director = Self.present(info.director) ?? Self.present(title.director)
        backdropURL = info.backdropURLs.first
        trailerURL = info.trailerURL
    }

    /// A series' page once `get_series_info` answered. The seasons count
    /// is the number of numbered season groups.
    public init(series title: ShelfTitle, info: SeriesInfo, groups: [SeasonGroup], locale: Locale = .autoupdatingCurrent) {
        self.init(title: title, locale: locale)
        let rating = info.rating ?? title.rating
        year = info.year.map(String.init)
        length = ShelfText.seasons(SeasonGroup.seasonCount(groups), locale: locale)
        genre = Self.present(info.genre)
        self.rating = rating.flatMap { Self.rating($0, locale: locale) }
        badges = [ShelfText.ageBadge(info.ageRating)].compactMap(\.self)
        description = Self.present(info.plot)
        cast = Self.present(info.cast) ?? Self.present(title.cast)
        director = Self.present(info.director) ?? Self.present(title.director)
        backdropURL = info.backdropURLs.first
        trailerURL = info.trailerURL
    }

    /// The page with what a database match adds: every field the provider
    /// left out filled from `match`, and its scores. Provider fields win
    /// (title-metadata/details-the-provider-left-out-come-from-the-database).
    /// A series keeps its own seasons count. Nil leaves the page as it is.
    public func merging(_ match: TitleMatch?, locale: Locale = .autoupdatingCurrent) -> TitleMetadata {
        guard let match else { return self }
        var merged = self
        let details = match.details
        merged.year = year ?? details.year.map(String.init)
        if kind == .movie { merged.length = length ?? ShelfText.length(details.duration, locale: locale) }
        merged.genre = genre ?? Self.present(details.genre)
        merged.description = description ?? Self.present(details.plot)
        merged.cast = cast ?? Self.present(details.cast)
        merged.director = director ?? Self.present(details.director)
        merged.backdropURL = backdropURL ?? details.backdropURL
        merged.scores = Score.ordered(match.scores)
        merged.scoresAreSample = match.isSample && !merged.scores.isEmpty
        return merged
    }

    /// "★ 7.4", one decimal; nil for 0 or less or not finite. The banner
    /// and the title page both write the provider's rating with it, with
    /// the decimal separator and digits of `locale`
    /// (localization/numbers-use-the-region-s-digits-and-separators).
    public static func rating(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String? {
        decimal(value, locale: locale).map { "★ \($0)" }
    }

    /// "rated 7.4 out of 10", what VoiceOver reads for `rating(_:)`, in
    /// the language of `locale`.
    public static func spokenRating(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String? {
        decimal(value, locale: locale).map { Words(locale)("rated \($0) out of 10") }
    }

    /// "7.4": one decimal, nil for 0 or less or not finite.
    private static func decimal(_ value: Double, locale: Locale) -> String? {
        guard value.isFinite, value > 0 else { return nil }
        return Int((value * 10).rounded()).tenths(locale)
    }

    static func eyebrow(_ title: ShelfTitle, locale: Locale = .autoupdatingCurrent) -> String {
        let kind = title.kind == .movie ? Words(locale)("Movie") : Words(locale)("Series")
        return ([kind] + [present(title.category)].compactMap(\.self)).joinedAsDetail(locale)
    }

    /// The text trimmed, or nil when nothing is left.
    static func present(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// The line under an episode's title and what VoiceOver reads for it
/// (title-detail-and-episode-picker/what-each-episode-shows).
public enum EpisodeText {
    /// "Watched" for a finished episode, "44 min · 21 min left" in progress,
    /// "44 min" otherwise; nil with no length and nothing to say.
    public static func status(_ episode: Episode, progress: WatchProgress?, locale: Locale = .autoupdatingCurrent) -> String? {
        switch progress?.state {
        case .watched:
            return Words(locale)("Watched")
        case .inProgress:
            return [ShelfText.length(episode.duration, locale: locale), progress.flatMap { ShelfText.left($0, locale: locale) }]
                .compactMap(\.self).joinedAsDetail(locale)
        default:
            return ShelfText.length(episode.duration, locale: locale)
        }
    }

    /// The bar's fill from 0 to 1: full when watched, the share in
    /// progress, nil when the episode looks unwatched.
    public static func fraction(_ progress: WatchProgress?) -> Double? {
        guard let progress, let length = progress.knownDuration else { return nil }
        switch progress.state {
        case .watched: return 1
        case .inProgress: return min(1, progress.position / length)
        case .notStarted: return nil
        }
    }

    /// "Episode 4, Low Water, 44 min, 21 min left, up next".
    public static func accessibilityLabel(
        _ episode: Episode, progress: WatchProgress?, upNext: Bool, locale: Locale = .autoupdatingCurrent
    ) -> String {
        let words = Words(locale)
        let number = episode.number.map { words("Episode \(String($0))") }
        let title = episode.title == number || episode.title == episode.number.map({ "Episode \($0)" }) ? nil : episode.title
        let length = ShelfText.length(episode.duration, locale: locale)
        let state: String? =
            switch progress?.state {
            case .watched: words("watched")
            case .inProgress: progress.flatMap { ShelfText.left($0, locale: locale) }
            default: nil
            }
        return [number, title, length, state, upNext ? words("up next") : nil].compactMap(\.self).joined(separator: ", ")
    }

    /// "1 episode could not be read from the provider's list." or the
    /// plural; nil when none were dropped.
    public static func skipped(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String? {
        guard count > 0 else { return nil }
        return Words(locale)("\(count) episodes could not be read from the provider's list.")
    }
}
