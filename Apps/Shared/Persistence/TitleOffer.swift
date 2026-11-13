import AntennaCore
import Foundation

/// How many movies and episodes a playlist's last load had. Counts only,
/// never a link or a login.
struct TitleCounts: Codable, Equatable, Sendable {
    var movies: Int
    var episodes: Int
}

/// Which on-demand sections this device offers, the one rule every tab bar,
/// sidebar, launch choice and search chip reads
/// (m3u-playlists/playlist-titles-show-on-every-platform,
/// m3u-playlists/movies-and-series-show-by-what-the-sources-offer).
struct TitleOffer: Equatable, Sendable {
    var movies: Bool
    var series: Bool

    static let none = TitleOffer(movies: false, series: false)

    /// Movies, series or both.
    var any: Bool { movies || series }

    init(movies: Bool, series: Bool) {
        self.movies = movies
        self.series = series
    }

    /// An Xtream source offers both, whether or not it has answered. A
    /// playlist offers movies when its last load had movies and series when
    /// it had episodes. Other kinds offer nothing.
    init(_ sources: [(id: UUID, kind: SourceKind)], counts: (UUID) -> TitleCounts?) {
        var offer = TitleOffer.none
        for source in sources {
            switch source.kind {
            case .xtream:
                offer = TitleOffer(movies: true, series: true)
            case .m3u, .m3uFile:
                guard let counts = counts(source.id) else { continue }
                offer.movies = offer.movies || counts.movies > 0
                offer.series = offer.series || counts.episodes > 0
            default:
                continue
            }
            if offer.movies && offer.series { break }
        }
        self = offer
    }

    /// The offer for the stored sources, with each playlist's counts from
    /// `refresher`; without one only Xtream sources count.
    @MainActor init(records: [SourceRecord], refresher: SourceRefresher?) {
        self.init(records.map { ($0.id, $0.kind) }) { id in refresher?.status(of: id).titleCounts }
    }
}

extension SourceStatus {
    /// The movies and episodes of the last load, nil before one.
    var titleCounts: TitleCounts? {
        guard movies != nil || episodes != nil else { return nil }
        return TitleCounts(movies: movies ?? 0, episodes: episodes ?? 0)
    }
}
