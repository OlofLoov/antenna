import AntennaCore
import Foundation

/// Reads an Xtream source's movies and series for the Movies and Series
/// sections (movies-and-series-browsing). Lives in the app layer because it
/// needs the Keychain; the client and decoders are in AntennaCore. Playable
/// addresses are built on demand from the credential and never stored or logged.
struct ShelfLoader: Sendable {
    var session: URLSession = .shared
    var credentials: any CredentialStoring = CredentialStore()

    /// Thrown for a source whose login is not on this device.
    enum LoadError: Error, Equatable {
        case noLogin
        /// The title id is not an Xtream id this loader can ask about.
        case unknownTitle
    }

    func hasLogin(_ source: SourceDescriptor) -> Bool {
        SourceLoader(session: session, credentials: credentials).hasLogin(source)
    }

    /// The source's movies or series with its categories.
    func load(_ source: SourceDescriptor, kind: ShelfTitle.Kind) async throws -> ShelfCatalogue {
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
        let client = try client(for: source)
        let rawID = try rawID(title.id)
        switch title.kind {
        case .movie: return ShelfDetails(movie: try await client.vodInfo(streamID: rawID))
        case .series: return ShelfDetails(series: try await client.seriesInfo(seriesID: rawID))
        }
    }

    /// A series' episodes in the client's order.
    func episodes(_ source: SourceDescriptor, series: ShelfTitle) async throws -> [Episode] {
        try await client(for: source).seriesInfo(seriesID: try rawID(series.id)).episodes
    }

    /// Where a movie plays from.
    func movieURL(_ source: SourceDescriptor, movie: ShelfTitle) throws -> URL {
        try client(for: source).movieURL(streamID: try rawID(movie.id), extension: movie.containerExtension)
    }

    /// Where an episode plays from.
    func episodeURL(_ source: SourceDescriptor, episode: Episode) throws -> URL {
        try client(for: source).episodeURL(episodeID: episode.episodeID, extension: episode.containerExtension)
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
