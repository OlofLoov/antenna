import AntennaCore
import Foundation

/// Reads an Xtream source's movies and series, and a playlist's movies,
/// for the Movies and Series sections (movies-and-series-browsing). Lives in the app layer because it
/// needs the Keychain; the client and decoders are in AntennaCore. Playable
/// addresses are built on demand from the credential and never stored or logged.
struct ShelfLoader: Sendable {
    var session: URLSession = .shared
    var credentials: any CredentialStoring = CredentialStore()
    /// Loads a playlist whose movies are not in memory yet. Nil leaves playlists without movies.
    var playlists: SourceLoader?

    /// Thrown for a source whose login is not on this device.
    enum LoadError: Error, Equatable {
        case noLogin
        /// The title id is not an Xtream id this loader can ask about.
        case unknownTitle
    }

    func hasLogin(_ source: SourceDescriptor) -> Bool {
        SourceLoader(session: session, credentials: credentials).hasLogin(source)
    }

    /// The source's movies or series with its categories. A playlist's
    /// come from its last load or a new one
    /// (m3u-playlists/playlist-movies-show-in-movies, m3u-playlists/playlist-series-show-in-series).
    func load(_ source: SourceDescriptor, kind: ShelfTitle.Kind) async throws -> ShelfCatalogue {
        if source.isPlaylist {
            switch kind {
            case .movie: return ShelfCatalogue(playlistMovies: try await playlistMovies(source), sourceID: source.id)
            case .series: return try await playlistSeries(source).catalogue
            }
        }
        let client = try client(for: source)
        switch kind {
        case .movie:
            async let categories = client.vodCategories()
            async let movies = client.vodStreams()
            return ShelfCatalogue(movies: try await movies.items, categories: try await categories, sourceID: source.id)
        case .series:
            async let categories = client.seriesCategories()
            async let series = client.series()
            return ShelfCatalogue(series: try await series.items, categories: try await categories, sourceID: source.id)
        }
    }

    /// The year, length or seasons, description and rating the banner shows.
    func details(_ source: SourceDescriptor, title: ShelfTitle) async throws -> ShelfDetails {
        if source.isPlaylist {
            switch title.kind {
            case .movie: return ShelfDetails(movie: VODInfo(containerExtension: title.containerExtension))
            case .series: return ShelfDetails(series: try await playlistSeriesInfo(source, series: title))
            }
        }
        let client = try client(for: source)
        let rawID = try rawID(title.id)
        switch title.kind {
        case .movie: return ShelfDetails(movie: try await client.vodInfo(streamID: rawID))
        case .series: return ShelfDetails(series: try await client.seriesInfo(seriesID: rawID))
        }
    }

    /// Everything the title page shows: the movie's or series' info call,
    /// asked once per call (title-detail-and-episode-picker/open-a-movie-s-page).
    func info(_ source: SourceDescriptor, title: ShelfTitle) async throws -> TitleInfo {
        if source.isPlaylist {
            switch title.kind {
            case .movie: return .movie(VODInfo(containerExtension: title.containerExtension))
            case .series: return .series(try await playlistSeriesInfo(source, series: title))
            }
        }
        let client = try client(for: source)
        let rawID = try rawID(title.id)
        switch title.kind {
        case .movie: return .movie(try await client.vodInfo(streamID: rawID))
        case .series: return .series(try await client.seriesInfo(seriesID: rawID))
        }
    }

    /// A series' episodes in the client's order.
    func episodes(_ source: SourceDescriptor, series: ShelfTitle) async throws -> [Episode] {
        if source.isPlaylist { return try await playlistSeriesInfo(source, series: series).episodes }
        return try await client(for: source).seriesInfo(seriesID: try rawID(series.id)).episodes
    }

    /// Where a movie plays from.
    func movieURL(_ source: SourceDescriptor, movie: ShelfTitle) throws -> URL {
        if source.isPlaylist { return try playlistLink(movie.id, in: source) }
        return try client(for: source).movieURL(streamID: try rawID(movie.id), extension: movie.containerExtension)
    }

    /// Where an episode plays from.
    func episodeURL(_ source: SourceDescriptor, episode: Episode) throws -> URL {
        if source.isPlaylist { return try playlistLink(episode.id, in: source) }
        return try client(for: source).episodeURL(episodeID: episode.episodeID, extension: episode.containerExtension)
    }

    private func playlistLink(_ id: String, in source: SourceDescriptor) throws -> URL {
        guard let link = (playlists?.playlistMovies ?? .shared).link(of: id, in: source.id) else { throw LoadError.unknownTitle }
        return link
    }

    private func playlistSeries(_ source: SourceDescriptor) async throws -> PlaylistSeries {
        let store = playlists?.playlistMovies ?? .shared
        if let known = store.series(in: source.id) { return known }
        guard let playlists else { return PlaylistSeries(episodes: [], sourceID: source.id) }
        _ = try await playlists.load(source)
        return store.series(in: source.id) ?? PlaylistSeries(episodes: [], sourceID: source.id)
    }

    /// A series the kept load does not have, such as one shown from an
    /// earlier load, asks the playlist once more before it fails.
    private func playlistSeriesInfo(_ source: SourceDescriptor, series: ShelfTitle) async throws -> SeriesInfo {
        if let info = try await playlistSeries(source).info(for: series.id) { return info }
        guard let playlists else { throw LoadError.unknownTitle }
        _ = try await playlists.load(source)
        let store = playlists.playlistMovies
        guard let info = store.series(in: source.id)?.info(for: series.id) else { throw LoadError.unknownTitle }
        return info
    }

    private func playlistMovies(_ source: SourceDescriptor) async throws -> [Channel] {
        let store = playlists?.playlistMovies ?? .shared
        if let known = store.movies(in: source.id) { return known }
        guard let playlists else { return [] }
        return try await playlists.load(source).movies
    }

    private func client(for source: SourceDescriptor) throws -> XtreamClient {
        guard let key = source.credentialKey, let login = try credentials.load(for: key) else { throw LoadError.noLogin }
        return XtreamClient(
            credentials: .init(server: source.url, username: login.username, password: login.password), session: session)
    }

    private func rawID(_ titleID: String) throws -> Int {
        guard let id = XtreamTitleID(parsing: titleID) else { throw LoadError.unknownTitle }
        return id.rawID
    }
}

/// What the info call answered for a title page.
enum TitleInfo: Sendable, Equatable {
    case movie(VODInfo)
    case series(SeriesInfo)
}
