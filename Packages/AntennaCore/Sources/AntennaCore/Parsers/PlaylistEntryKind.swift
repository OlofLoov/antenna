import Foundation

/// What a playlist entry is: a live channel, a movie or a series episode
/// (m3u-playlists/movies-and-episodes-in-a-playlist-are-recognized).
public enum PlaylistEntryKind: Sendable, Hashable {
    case live, movie, episode

    static let movieExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "m4v"]
    static let movieGroupWords = ["vod", "movies", "movie", "films", "film"]
    static let liveGroupWords: Set<String> = ["live", "news", "sport", "sports"]

    /// Sorts one entry by the first rule that applies: a `/series/` path is
    /// an episode, a `/movie/` or `/movies/` path a movie, a name with a
    /// season and episode such as "S01E02" an episode, a group starting with
    /// "VOD", "Movies" or "Films" a movie, an entry with a live sign live, and
    /// a link ending in a video file extension a movie. Anything else is
    /// live. Live signs are catch-up, a guide id, a live group such as
    /// "News" or "24/7", and a duration of -1 or 0.
    public init(_ channel: Channel) {
        let folders = channel.streamURL.pathComponents.dropLast().map { $0.lowercased() }
        if folders.contains("series") {
            self = .episode
        } else if folders.contains("movie") || folders.contains("movies") {
            self = .movie
        } else if Self.namesAnEpisode(channel.name) {
            self = .episode
        } else if let group = channel.group, Self.isMovieGroup(group) {
            self = .movie
        } else if Self.looksLive(channel) {
            self = .live
        } else if Self.movieExtensions.contains(channel.streamURL.pathExtension.lowercased()) {
            self = .movie
        } else {
            self = .live
        }
    }

    /// True for an entry with catch-up, a guide id, a live group or a duration of -1 or 0.
    static func looksLive(_ channel: Channel) -> Bool {
        if channel.hasCatchup || channel.epgID != nil { return true }
        if let duration = channel.duration, duration <= 0, duration >= -1 { return true }
        return channel.group.map(isLiveGroup) ?? false
    }

    /// True for a group with the word Live, News, Sport or Sports, or holding "24/7".
    static func isLiveGroup(_ group: String) -> Bool {
        let lowered = group.lowercased()
        if lowered.contains("24/7") { return true }
        return lowered.split { !$0.isLetter }.contains { liveGroupWords.contains(String($0)) }
    }

    /// True for a name holding a season and episode marker like "S01E02" or "s1 e12".
    static func namesAnEpisode(_ name: String) -> Bool {
        name.range(of: #"(?i)(?<![A-Za-z0-9])S\d{1,2}\s?E\d{1,3}(?![0-9])"#, options: .regularExpression) != nil
    }

    /// True for a group whose first word is VOD, Movie(s) or Film(s), as in "VOD | Action" or "Movies: Comedy".
    static func isMovieGroup(_ group: String) -> Bool {
        let first = group.trimmingCharacters(in: .whitespaces).lowercased().prefix { $0.isLetter }
        return movieGroupWords.contains(String(first))
    }
}

extension Playlist {
    /// The playlist with its movie entries moved from `channels` to
    /// `movies` and its episodes to `episodes`, each list in playlist order
    /// (m3u-playlists/playlist-movies-stay-out-of-live-channels).
    public func separatingOnDemand() -> Playlist {
        var copy = self
        var live: [Channel] = []
        var movies: [Channel] = []
        var episodes: [Channel] = []
        for channel in channels {
            switch PlaylistEntryKind(channel) {
            case .live: live.append(channel)
            case .movie: movies.append(channel)
            case .episode: episodes.append(channel)
            }
        }
        copy.channels = live
        copy.movies = self.movies + movies
        copy.episodes = self.episodes + episodes
        return copy
    }
}

extension ShelfCatalogue {
    /// A playlist's movies for the Movies section: each entry's id, name,
    /// logo as its poster, group as its category and file extension, with the
    /// groups in first-seen order. The ids hold no link
    /// (m3u-playlists/playlist-movies-show-in-movies).
    public init(playlistMovies movies: [Channel], sourceID: UUID) {
        var seen = Set<String>()
        var categories: [String] = []
        let titles = movies.map { movie in
            if let group = movie.group, seen.insert(group).inserted { categories.append(group) }
            let fileExtension = movie.streamURL.pathExtension
            return ShelfTitle(
                id: movie.id, kind: .movie, sourceID: sourceID, name: movie.name, posterURL: movie.logoURL, category: movie.group,
                containerExtension: fileExtension.isEmpty ? nil : fileExtension)
        }
        self.init(titles: titles, categories: categories)
    }
}
