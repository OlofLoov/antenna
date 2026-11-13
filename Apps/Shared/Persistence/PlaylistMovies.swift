import AntennaCore
import Foundation

/// Each playlist's movie entries from its last load in this run, for the
/// Movies section and playback (m3u-playlists/playlist-movies-show-in-movies).
/// Kept in memory only: the links can hold the provider's login, so they are
/// never stored or logged.
final class PlaylistMovies: @unchecked Sendable {
    static let shared = PlaylistMovies()

    private let lock = NSLock()
    private var bySource: [UUID: [Channel]] = [:]

    /// Replaces the source's movies with the ones its last load found.
    func loaded(_ sourceID: UUID, movies: [Channel]) {
        lock.withLock { bySource[sourceID] = movies }
    }

    /// The source's movies, nil before its first load in this run.
    func movies(in sourceID: UUID) -> [Channel]? {
        lock.withLock { bySource[sourceID] }
    }

    /// Where the movie with this id plays from, nil when the source's last load did not have it.
    func link(of movieID: String, in sourceID: UUID) -> URL? {
        lock.withLock { bySource[sourceID]?.first { $0.id == movieID }?.streamURL }
    }
}

extension SourceDescriptor {
    /// An M3U link or an imported file.
    var isPlaylist: Bool { kind == .m3u || kind == .m3uFile }
}
