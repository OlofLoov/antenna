import AntennaCore
import Foundation

/// Each playlist's movies and episodes from its last load in this run, for
/// the Movies and Series sections and playback
/// (m3u-playlists/playlist-movies-show-in-movies,
/// m3u-playlists/playlist-series-show-in-series). Kept in memory only: the
/// links can hold the provider's login, so they are never stored or logged.
final class PlaylistMovies: @unchecked Sendable {
    static let shared = PlaylistMovies()

    private struct Loaded {
        var movies: [Channel]
        var episodes: [Channel]
        var series: PlaylistSeries
    }

    private let lock = NSLock()
    private var bySource: [UUID: Loaded] = [:]

    /// Replaces the source's movies and episodes with the ones its last load
    /// found, and groups the episodes into series.
    func loaded(_ sourceID: UUID, movies: [Channel], episodes: [Channel] = []) {
        let series = PlaylistSeries(episodes: episodes, sourceID: sourceID)
        lock.withLock { bySource[sourceID] = Loaded(movies: movies, episodes: episodes, series: series) }
    }

    /// The source's movies, nil before its first load in this run.
    func movies(in sourceID: UUID) -> [Channel]? {
        lock.withLock { bySource[sourceID]?.movies }
    }

    /// The source's episodes grouped into series, nil before its first load in this run.
    func series(in sourceID: UUID) -> PlaylistSeries? {
        lock.withLock { bySource[sourceID]?.series }
    }

    /// Where the movie or episode with this id plays from, nil when the
    /// source's last load did not have it.
    func link(of id: String, in sourceID: UUID) -> URL? {
        lock.withLock {
            guard let loaded = bySource[sourceID] else { return nil }
            return (loaded.movies.first { $0.id == id } ?? loaded.episodes.first { $0.id == id })?.streamURL
        }
    }
}

extension SourceDescriptor {
    /// An M3U link or an imported file.
    var isPlaylist: Bool { kind == .m3u || kind == .m3uFile }
}
