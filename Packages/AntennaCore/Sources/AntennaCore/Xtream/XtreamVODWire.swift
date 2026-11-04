import Foundation

// Wire shapes for the VOD and series actions. Internal: callers see the
// models in XtreamVODModels.swift. Every field but the row id and name is
// decoded loosely and becomes nil when it fails, so one odd field never
// drops its row.

struct VODRow: Decodable, ListRow {
    var streamID: Int
    var name: String
    var posterURL: URL?
    var added: Date?
    var rating: Double?
    var containerExtension: String?
    var categoryID: String?

    var rawID: Int { streamID }

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id", name, streamIcon = "stream_icon", added, rating
        case containerExtension = "container_extension", categoryID = "category_id"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamID = try requiredID(c, .streamID)
        name = try requiredName(c, .name)
        posterURL = Loose.webURL(c.nonEmptyString(.streamIcon))
        added = Loose.date(c.looseInt(.added, stringFirst: true))
        rating = c.looseDouble(.rating).flatMap { $0 > 0 ? $0 : nil }
        containerExtension = c.looseString(.containerExtension)
        categoryID = c.looseString(.categoryID)
    }
}

struct SeriesRow: Decodable, ListRow {
    var seriesID: Int
    var name: String
    var posterURL: URL?
    var lastModified: Date?
    var categoryID: String?

    var rawID: Int { seriesID }

    enum CodingKeys: String, CodingKey {
        case seriesID = "series_id", name, cover, lastModified = "last_modified", categoryID = "category_id"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seriesID = try requiredID(c, .seriesID)
        name = try requiredName(c, .name)
        posterURL = Loose.webURL(c.nonEmptyString(.cover))
        lastModified = Loose.date(c.looseInt(.lastModified, stringFirst: true))
        categoryID = c.looseString(.categoryID)
    }
}

/// The row id: must be present and decode to `Int`, or the row is skipped.
private func requiredID<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> Int {
    guard let id = c.looseInt(key) else {
        throw DecodingError.keyNotFound(key, .init(codingPath: c.codingPath, debugDescription: "missing or not an integer"))
    }
    return id
}

/// The row name: must be present as a string or number, or the row is skipped. May be empty.
private func requiredName<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> String {
    if let name = try? c.decodeIfPresent(String.self, forKey: key) { return name }
    if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return String(number) }
    throw DecodingError.keyNotFound(key, .init(codingPath: c.codingPath, debugDescription: "missing name"))
}

/// The `info` object shared by `get_vod_info` and `get_series_info`.
struct InfoFields: Decodable {
    var plot: String?
    var year: Int?
    var duration: TimeInterval?
    var genre: String?
    var ageRating: String?
    var backdropURLs: [URL] = []

    enum CodingKeys: String, CodingKey {
        case plot, releasedate, releaseDateSnake = "release_date", releaseDate, duration
        case durationSecs = "duration_secs", genre, age, backdropPath = "backdrop_path"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plot = c.looseString(.plot)
        let date = [CodingKeys.releasedate, .releaseDateSnake, .releaseDate].lazy.compactMap { c.nonEmptyString($0) }.first
        year = Loose.year(date)
        duration = Loose.duration(seconds: c.looseDouble(.durationSecs), clock: c.nonEmptyString(.duration))
        genre = c.looseString(.genre)
        ageRating = c.looseString(.age)
        if let list = try? c.decodeIfPresent([Lossy<String>].self, forKey: .backdropPath) {
            backdropURLs = list.compactMap { Loose.webURL($0.value) }
        } else if let single = Loose.webURL(c.nonEmptyString(.backdropPath)) {
            backdropURLs = [single]
        }
    }
}

struct VODInfoWire: Decodable {
    var info: InfoFields?
    var containerExtension: String?

    enum CodingKeys: String, CodingKey { case info, movieData = "movie_data" }
    enum MovieDataKeys: String, CodingKey { case containerExtension = "container_extension" }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        info = try? c.decodeIfPresent(InfoFields.self, forKey: .info)
        let movieData = try? c.nestedContainer(keyedBy: MovieDataKeys.self, forKey: .movieData)
        containerExtension = movieData?.looseString(.containerExtension)
    }
}

struct SeriesInfoWire: Decodable {
    /// Episodes as the server grouped them: one group per season key, or one keyless group for an array.
    struct Group {
        var seasonKey: Int?
        var rows: [Lossy<EpisodeRow>]
    }

    var info: InfoFields?
    var episodes: [Group] = []

    enum CodingKeys: String, CodingKey { case info, episodes }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        info = try? c.decodeIfPresent(InfoFields.self, forKey: .info)
        if let rows = try? c.decodeIfPresent([Lossy<EpisodeRow>].self, forKey: .episodes) {
            episodes = [Group(seasonKey: nil, rows: rows)]
        } else if let seasons = try? c.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .episodes) {
            // JSON object key order is not preserved by the decoder, so seasons are visited by number,
            // then non-numeric keys by name. That order decides ties and which duplicate wins.
            let keys = seasons.allKeys.sorted { lhs, rhs in
                switch (Int(lhs.stringValue), Int(rhs.stringValue)) {
                case (let left?, let right?): left < right
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): lhs.stringValue < rhs.stringValue
                }
            }
            episodes = keys.map { key in
                Group(seasonKey: Int(key.stringValue), rows: (try? seasons.decode([Lossy<EpisodeRow>].self, forKey: key)) ?? [])
            }
        }
    }
}

struct EpisodeRow: Decodable {
    var episodeID: Int
    var season: Int?
    var number: Int?
    var title: String?
    var containerExtension: String?
    var duration: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id, season, number = "episode_num", title, containerExtension = "container_extension", info
    }
    enum InfoKeys: String, CodingKey { case durationSecs = "duration_secs", duration }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodeID = try requiredID(c, .id)
        season = c.looseInt(.season)
        number = c.looseInt(.number)
        title = c.looseString(.title)
        containerExtension = c.looseString(.containerExtension)
        if let info = try? c.nestedContainer(keyedBy: InfoKeys.self, forKey: .info) {
            duration = Loose.duration(seconds: info.looseDouble(.durationSecs), clock: info.nonEmptyString(.duration))
        }
    }
}

extension XtreamClient {
    /// Flattens grouped episodes, drops broken and repeated ids (first wins), resolves season and title,
    /// and sorts stably by season then number with nil first.
    static func flatten(_ groups: [SeriesInfoWire.Group], host: String) -> (episodes: [Episode], skipped: Int) {
        var seen = Set<Int>()
        var skipped = 0
        var episodes: [Episode] = []
        for group in groups {
            for lossy in group.rows {
                guard let row = lossy.value, seen.insert(row.episodeID).inserted else {
                    skipped += 1
                    continue
                }
                let title = row.title ?? row.number.map { "Episode \($0)" } ?? "Episode"
                episodes.append(
                    Episode(
                        id: XtreamTitleID(host: host, kind: .episode, rawID: row.episodeID).description, episodeID: row.episodeID,
                        season: row.season ?? group.seasonKey, number: row.number, title: title,
                        containerExtension: row.containerExtension, duration: row.duration))
            }
        }
        let sorted = episodes.enumerated().sorted { lhs, rhs in
            if lhs.element.season != rhs.element.season { return precedes(lhs.element.season, rhs.element.season) }
            if lhs.element.number != rhs.element.number { return precedes(lhs.element.number, rhs.element.number) }
            return lhs.offset < rhs.offset
        }
        return (sorted.map(\.element), skipped)
    }

    /// Nil sorts before any value.
    private static func precedes(_ lhs: Int?, _ rhs: Int?) -> Bool {
        switch (lhs, rhs) {
        case (nil, .some): true
        case (let left?, let right?): left < right
        default: false
        }
    }
}
