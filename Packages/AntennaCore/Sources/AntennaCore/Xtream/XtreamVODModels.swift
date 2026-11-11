import Foundation

extension XtreamClient {
    /// A decoded list together with the number of rows the decoder dropped.
    ///
    /// `items` keeps server order. `skipped` counts rows that were not objects,
    /// lacked an id or a name, had an id that is not an integer, or repeated an
    /// earlier row's id.
    public struct DecodedList<T: Sendable & Hashable>: Sendable, Hashable {
        /// The usable rows in server order, no two with the same id.
        public var items: [T]
        /// Rows dropped as broken or duplicate.
        public var skipped: Int

        public init(items: [T], skipped: Int) {
            self.items = items
            self.skipped = skipped
        }
    }
}

/// A movie row from `get_vod_streams`.
public struct VODItem: Sendable, Hashable, Identifiable {
    /// Title id, `xtream#<host>#vod#<streamID>`. Stable across responses and devices.
    public var id: String
    /// Raw Xtream id, used for requests and playable URLs.
    public var streamID: Int
    /// As the panel sent it. May be empty.
    public var name: String
    /// From `stream_icon`. Only `http` or `https` URLs with a host.
    public var posterURL: URL?
    /// When the panel added the movie. Nil unless `added` is a positive integer of seconds since 1970.
    public var added: Date?
    /// Nil when the panel sends 0 or no usable number.
    public var rating: Double?
    /// File extension for `movieURL(streamID:extension:)`, such as "mkv".
    public var containerExtension: String?
    /// Matches `XtreamCategory.categoryID`. Nil when the row has none.
    public var categoryID: String?

    /// Builds a row. `decodeVODList(_:host:)` is the usual source.
    public init(
        id: String, streamID: Int, name: String, posterURL: URL? = nil, added: Date? = nil, rating: Double? = nil,
        containerExtension: String? = nil, categoryID: String? = nil
    ) {
        self.id = id
        self.streamID = streamID
        self.name = name
        self.posterURL = posterURL
        self.added = added
        self.rating = rating
        self.containerExtension = containerExtension
        self.categoryID = categoryID
    }
}

/// Details for one movie from `get_vod_info`. Every field is nil, or empty for
/// `backdropURLs`, when the panel does not send a usable value.
public struct VODInfo: Sendable, Hashable {
    /// From `info.plot`.
    public var plot: String?
    /// From the first non-empty of `releasedate`, `release_date` and `releaseDate`. Nil for "0000".
    public var year: Int?
    /// Seconds, from `duration_secs` or else `duration` as `hh:mm:ss` or `mm:ss`. Never 0.
    public var duration: TimeInterval?
    /// From `info.genre`.
    public var genre: String?
    /// From `info.age`, as the panel wrote it.
    public var ageRating: String?
    /// Only `http` or `https` URLs with a host, in server order.
    public var backdropURLs: [URL]
    /// From `movie_data.container_extension`.
    public var containerExtension: String?
    /// From `info.cast`, else `info.actors`, as the panel wrote it.
    public var cast: String?
    /// From `info.director`.
    public var director: String?
    /// From `info.rating`. Nil when the panel sends 0 or no usable number.
    public var rating: Double?
    /// From `info.youtube_trailer`, else `info.trailer`: a web address as is, an
    /// 11-character YouTube id as `https://www.youtube.com/watch?v=<id>`, anything else nil.
    public var trailerURL: URL?

    /// Builds a value. `decodeVODInfo(_:host:)` is the usual source.
    public init(
        plot: String? = nil, year: Int? = nil, duration: TimeInterval? = nil, genre: String? = nil, ageRating: String? = nil,
        backdropURLs: [URL] = [], containerExtension: String? = nil, cast: String? = nil, director: String? = nil,
        rating: Double? = nil, trailerURL: URL? = nil
    ) {
        self.plot = plot
        self.year = year
        self.duration = duration
        self.genre = genre
        self.ageRating = ageRating
        self.backdropURLs = backdropURLs
        self.containerExtension = containerExtension
        self.cast = cast
        self.director = director
        self.rating = rating
        self.trailerURL = trailerURL
    }
}

/// A series row from `get_series`.
public struct Series: Sendable, Hashable, Identifiable {
    /// Title id, `xtream#<host>#series#<seriesID>`.
    public var id: String
    /// Raw Xtream id, used for `seriesInfo(seriesID:)`.
    public var seriesID: Int
    /// As the panel sent it. May be empty.
    public var name: String
    /// From `cover`; only `http` or `https` URLs with a host.
    public var posterURL: URL?
    /// From `last_modified`, with the rules of `VODItem.added`.
    public var lastModified: Date?
    /// Matches `XtreamCategory.categoryID`. Nil when the row has none.
    public var categoryID: String?

    /// Builds a row. `decodeSeriesList(_:host:)` is the usual source.
    public init(
        id: String, seriesID: Int, name: String, posterURL: URL? = nil, lastModified: Date? = nil, categoryID: String? = nil
    ) {
        self.id = id
        self.seriesID = seriesID
        self.name = name
        self.posterURL = posterURL
        self.lastModified = lastModified
        self.categoryID = categoryID
    }
}

/// Details and episodes for one series from `get_series_info`.
public struct SeriesInfo: Sendable, Hashable {
    /// From `info`, with the rules of the matching `VODInfo` field.
    public var plot: String?
    /// From `info`, with the rules of `VODInfo.year`.
    public var year: Int?
    /// From `info.genre`.
    public var genre: String?
    /// From `info.age`.
    public var ageRating: String?
    /// From `info.backdrop_path`, with the rules of `VODInfo.backdropURLs`.
    public var backdropURLs: [URL]
    /// With the rules of `VODInfo.cast`.
    public var cast: String?
    /// With the rules of `VODInfo.director`.
    public var director: String?
    /// With the rules of `VODInfo.rating`.
    public var rating: Double?
    /// With the rules of `VODInfo.trailerURL`.
    public var trailerURL: URL?
    /// Flat, sorted by season then number, nil first, ties in server order.
    public var episodes: [Episode]
    /// Number of distinct non-nil `Episode.season` values.
    public var seasonCount: Int { Set(episodes.compactMap(\.season)).count }
    /// Episodes dropped as broken or duplicate.
    public var skippedEpisodes: Int

    /// Builds a value. `decodeSeriesInfo(_:host:)` is the usual source.
    public init(
        plot: String? = nil, year: Int? = nil, genre: String? = nil, ageRating: String? = nil, backdropURLs: [URL] = [],
        cast: String? = nil, director: String? = nil, rating: Double? = nil, trailerURL: URL? = nil, episodes: [Episode] = [],
        skippedEpisodes: Int = 0
    ) {
        self.plot = plot
        self.year = year
        self.genre = genre
        self.ageRating = ageRating
        self.backdropURLs = backdropURLs
        self.cast = cast
        self.director = director
        self.rating = rating
        self.trailerURL = trailerURL
        self.episodes = episodes
        self.skippedEpisodes = skippedEpisodes
    }
}

/// One episode of a series.
public struct Episode: Sendable, Hashable, Identifiable {
    /// Title id, `xtream#<host>#episode#<episodeID>`.
    public var id: String
    /// Raw Xtream id, used for `episodeURL(episodeID:extension:)`.
    public var episodeID: Int
    /// The episode's own `season`, else its season key in the response, else nil.
    public var season: Int?
    /// From `episode_num`. Nil when absent or not numeric.
    public var number: Int?
    /// Never empty. Falls back to "Episode <number>" or "Episode".
    public var title: String
    /// File extension for `episodeURL(episodeID:extension:)`.
    public var containerExtension: String?
    /// Seconds, with the rule of `VODInfo.duration` over the episode's `info`.
    public var duration: TimeInterval?
    /// From `info.plot`, else `info.overview`. Nil when absent or blank.
    public var plot: String?
    /// From `info.movie_image`, else `info.cover_big`, with the rules of `VODItem.posterURL`.
    public var thumbnailURL: URL?

    /// Builds an episode. `decodeSeriesInfo(_:host:)` is the usual source.
    public init(
        id: String, episodeID: Int, season: Int? = nil, number: Int? = nil, title: String, containerExtension: String? = nil,
        duration: TimeInterval? = nil, plot: String? = nil, thumbnailURL: URL? = nil
    ) {
        self.plot = plot
        self.thumbnailURL = thumbnailURL
        self.id = id
        self.episodeID = episodeID
        self.season = season
        self.number = number
        self.title = title
        self.containerExtension = containerExtension
        self.duration = duration
    }
}

/// The storage id of an Xtream title, `xtream#<host>#<rawID>` for live
/// channels and `xtream#<host>#<kind>#<rawID>` for the other kinds.
///
/// Ids use the server host only, so scheme and port do not change them.
public struct XtreamTitleID: Sendable, Hashable, CustomStringConvertible {
    /// What the id names. `live` ids have no kind segment.
    public enum Kind: String, Sendable, Hashable {
        case live, vod, series, episode
    }

    /// The server host, without scheme or port.
    public var host: String
    public var kind: Kind
    /// The Xtream `stream_id`, `series_id` or episode `id`.
    public var rawID: Int

    /// Builds an id from its parts.
    public init(host: String, kind: Kind, rawID: Int) {
        self.host = host
        self.kind = kind
        self.rawID = rawID
    }

    /// Nil unless the string is one of the four id shapes with a non-empty host and an integer raw id
    /// written as `description` writes it, so a parsed id always prints back to the same string.
    public init?(parsing string: String) {
        let parts = string.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count == 3 || parts.count == 4, parts[0] == "xtream", !parts[1].isEmpty,
            let rawID = Int(parts[parts.count - 1])
        else { return nil }
        if parts.count == 3 {
            kind = .live
        } else {
            guard let parsed = Kind(rawValue: String(parts[2])), parsed != .live else { return nil }
            kind = parsed
        }
        host = String(parts[1])
        self.rawID = rawID
        guard description == string else { return nil }
    }

    /// The id string, as stored and as used for `Identifiable`.
    public var description: String {
        kind == .live ? "xtream#\(host)#\(rawID)" : "xtream#\(host)#\(kind.rawValue)#\(rawID)"
    }
}
