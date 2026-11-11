import Foundation

/// The words at the top of a movie or series page
/// (title-detail-and-episode-picker/what-the-title-is-about). Every field
/// the provider leaves out, or sends blank, is nil or left out of its list,
/// never "Unknown".
public struct TitleMetadata: Sendable, Hashable {
    /// "Movie · Thriller", or "Movie" without a category.
    public var eyebrow: String
    public var name: String
    /// Year, length or seasons, genre and "★ 7.4", in that order.
    public var facts: [String]
    /// "4K" and the age badge for a movie, the age badge for a series.
    public var badges: [String]
    public var description: String?
    public var cast: String?
    public var director: String?
    /// The first backdrop, the page's art when present.
    public var backdropURL: URL?
    public var trailerURL: URL?

    /// "2024 · 2 h 08 min · Thriller · ★ 7.4", nil when there are no facts.
    public var detailsLine: String? {
        facts.isEmpty ? nil : facts.joined(separator: " · ")
    }

    /// What the page shows before the details arrive: the eyebrow and name.
    public init(title: ShelfTitle) {
        eyebrow = Self.eyebrow(title)
        name = title.name
        facts = []
        badges = []
    }

    /// A movie's page once `get_vod_info` answered. The rating is the info
    /// call's, else the list row's.
    public init(movie title: ShelfTitle, info: VODInfo) {
        self.init(title: title)
        let rating = info.rating ?? title.rating
        facts = [info.year.map(String.init), ShelfText.length(info.duration), Self.present(info.genre), rating.flatMap(Self.rating)]
            .compactMap(\.self)
        badges = [ShelfText.is4K(title.name) ? "4K" : nil, ShelfText.ageBadge(info.ageRating)].compactMap(\.self)
        description = Self.present(info.plot)
        cast = Self.present(info.cast)
        director = Self.present(info.director)
        backdropURL = info.backdropURLs.first
        trailerURL = info.trailerURL
    }

    /// A series' page once `get_series_info` answered. The seasons count
    /// is the number of numbered season groups.
    public init(series title: ShelfTitle, info: SeriesInfo, groups: [SeasonGroup]) {
        self.init(title: title)
        let rating = info.rating ?? title.rating
        facts = [
            info.year.map(String.init), ShelfText.seasons(SeasonGroup.seasonCount(groups)), Self.present(info.genre),
            rating.flatMap(Self.rating),
        ]
        .compactMap(\.self)
        badges = [ShelfText.ageBadge(info.ageRating)].compactMap(\.self)
        description = Self.present(info.plot)
        cast = Self.present(info.cast)
        director = Self.present(info.director)
        backdropURL = info.backdropURLs.first
        trailerURL = info.trailerURL
    }

    /// "★ 7.4", one decimal; nil for 0 or less or not finite.
    public static func rating(_ value: Double) -> String? {
        guard value.isFinite, value > 0 else { return nil }
        let tenths = Int((value * 10).rounded())
        return "★ \(tenths / 10).\(tenths % 10)"
    }

    static func eyebrow(_ title: ShelfTitle) -> String {
        let kind = title.kind == .movie ? "Movie" : "Series"
        return ([kind] + [present(title.category)].compactMap(\.self)).joined(separator: " · ")
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
    public static func status(_ episode: Episode, progress: WatchProgress?) -> String? {
        switch progress?.state {
        case .watched:
            return "Watched"
        case .inProgress:
            return [ShelfText.length(episode.duration), progress.flatMap(ShelfText.left)].compactMap(\.self).joined(separator: " · ")
        default:
            return ShelfText.length(episode.duration)
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
    public static func accessibilityLabel(_ episode: Episode, progress: WatchProgress?, upNext: Bool) -> String {
        let number = episode.number.map { "Episode \($0)" }
        let title = episode.title == number ? nil : episode.title
        let length = ShelfText.length(episode.duration)
        let state: String? =
            switch progress?.state {
            case .watched: "watched"
            case .inProgress: progress.flatMap(ShelfText.left)
            default: nil
            }
        return [number, title, length, state, upNext ? "up next" : nil].compactMap(\.self).joined(separator: ", ")
    }

    /// "1 episode could not be read from the provider's list." or the
    /// plural; nil when none were dropped.
    public static func skipped(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1
            ? "1 episode could not be read from the provider's list."
            : "\(count) episodes could not be read from the provider's list."
    }
}
