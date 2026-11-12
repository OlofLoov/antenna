import AntennaCore
import Foundation
import Observation

/// One connected source as the loading checklist follows it
/// (first-run-onboarding/the-checklist-shows-real-progress): its channels,
/// its movies and series, and its guide, each running, done or failed.
@MainActor @Observable
final class SourceSetup {
    /// A checklist line that ends done with a value, or failed.
    enum Line<Value: Equatable>: Equatable {
        case running
        case done(Value)
        case failed

        var isFinished: Bool { self != .running }

        var value: Value? {
            if case .done(let value) = self { return value }
            return nil
        }
    }

    /// Movies and series counts; nil after the cutoff, when the line reads
    /// "Movies and series available".
    struct Library: Equatable {
        var movies: Int
        var series: Int
        var total: Int { movies + series }
    }

    enum Guide: Equatable {
        /// The source names no guide; there is no guide line.
        case none
        case waiting
        case downloading(bytes: Int64)
        /// The last byte arrived and the guide is being read.
        case reading
        case loaded(days: Int, matched: Int, total: Int)
        case failed

        var isFinished: Bool {
            switch self {
            case .none, .loaded, .failed: true
            case .waiting, .downloading, .reading: false
            }
        }
    }

    /// What loading needs from outside, so tests can stub it.
    struct Dependencies {
        /// The live channels: the playlist Connect downloaded, or the Xtream categories and streams.
        var channels: @MainActor (SourceConnector.Connection) async throws -> Playlist
        /// The Xtream movie and series counts.
        var library: @MainActor (SourceConnector.Connection) async throws -> Library
        var guide: (any SetupGuide)?
        /// How long the movies line waits for counts.
        var libraryCutoff = Duration.seconds(20)
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    let connection: SourceSetup.Connection
    /// The source's id.
    var id: UUID { connection.descriptor.id }
    var name: String { connection.descriptor.name }
    private(set) var channels: Line<ChannelTally> = .running
    /// Nil for a playlist, which has no movies line.
    private(set) var library: Line<Library?>?
    private(set) var guide: Guide = .waiting
    /// The tagged channels, once loaded.
    private(set) var loaded: [Channel] = []

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var work: [Task<Void, Never>] = []

    typealias Connection = SourceConnector.Connection

    init(_ connection: Connection, dependencies: Dependencies) {
        self.connection = connection
        self.dependencies = dependencies
        if case .account = connection.reply { library = .running }
    }

    /// Every line is done or failed.
    var isFinished: Bool {
        channels.isFinished && (library?.isFinished ?? true) && guide.isFinished
    }

    /// Live channels loaded.
    var hasLive: Bool { (channels.value?.channels ?? 0) > 0 }

    /// Movies or series loaded, or available once the movies line stopped waiting.
    var hasLibrary: Bool {
        guard case .done(let library)? = library else { return false }
        return library.map { $0.total > 0 } ?? true
    }

    /// The source connected but has nothing to watch: no channels, movies or series.
    var isEmpty: Bool {
        channels.isFinished && (library?.isFinished ?? true) && !hasLive && !hasLibrary
    }

    /// Starts every line. Returns at once.
    func start() {
        guard work.isEmpty else { return }
        work.append(Task { await loadChannels() })
        if library != nil { work.append(Task { await loadLibrary() }) }
    }

    /// Stops what is still running; the guide store keeps its own download.
    func stop() {
        work.forEach { $0.cancel() }
    }

    /// Waits for every line. For tests.
    func finished() async {
        for task in work { await task.value }
    }

    private func loadChannels() async {
        let playlist: Playlist
        do {
            playlist = try await dependencies.channels(connection)
        } catch {
            guard !Task.isCancelled else { return }
            channels = .failed
            guide = .none
            return
        }
        guard !Task.isCancelled else { return }
        loaded = Channel.tagged(playlist.channels, sourceID: id)
        channels = .done(ChannelTally(tagged: loaded))
        await followGuide(playlist)
    }

    private func loadLibrary() async {
        let counts = Task { [dependencies, connection] in try await dependencies.library(connection) }
        let cutoff = Task { [dependencies] in try? await dependencies.sleep(dependencies.libraryCutoff) }
        let winner = Task {
            await cutoff.value
            counts.cancel()
        }
        defer { winner.cancel() }
        do {
            let result = try await counts.value
            cutoff.cancel()
            library = .done(result)
        } catch {
            guard !Task.isCancelled else { return }
            // The cutoff cancelled the request, or it failed: either way the
            // line reads that movies and series are available.
            library = .done(nil)
        }
    }

    private func followGuide(_ playlist: Playlist) async {
        let descriptor = connection.descriptor
        let login = connection.login.map { (username: $0.username, password: $0.password) }
        let link = GuideURLResolver.resolve(
            kind: descriptor.kind, url: descriptor.url, epgURL: descriptor.epgURL, playlistEPGURLs: playlist.epgURLs, credential: login)
        guard let guideStore = dependencies.guide, link != nil else {
            guide = .none
            return
        }
        let progress = guideStore.progressStream()
        await guideStore.register(epgURLs: playlist.epgURLs, for: id)
        await guideStore.update(channels: loaded)
        await guideStore.refreshIfStale(now: .now)
        for await event in progress where event.sourceID == id {
            guard !Task.isCancelled else { return }
            switch event {
            case .downloading(_, let received, let expected):
                guide = expected.map { received >= $0 && $0 > 0 } == true ? .reading : .downloading(bytes: received)
            case .loaded(_, let matched, let total, let days, _):
                guide = .loaded(days: days, matched: matched, total: total)
                return
            case .failed:
                guide = .failed
                return
            }
        }
    }
}

/// The part of the guide store the checklist uses.
@MainActor
protocol SetupGuide {
    func progressStream() -> AsyncStream<GuideProgress>
    func register(epgURLs: [URL], for sourceID: UUID) async
    func update(channels: [Channel]) async
    func refreshIfStale(now: Date) async
}

extension AppGuideStore: SetupGuide {}

extension SourceSetup.Dependencies {
    /// The app's: Xtream through `XtreamClient` on `session`, the guide
    /// through the app's store.
    static func live(session: URLSession = .shared, guide: AppGuideStore?) -> Self {
        .init(
            channels: { connection in
                switch connection.reply {
                case .playlist(let playlist):
                    return playlist
                case .account:
                    let client = try Self.client(for: connection, session: session)
                    async let categories = client.liveCategories()
                    async let streams = client.liveStreams()
                    let names = Dictionary(
                        try await categories.map { ($0.categoryID, $0.categoryName) }, uniquingKeysWith: { first, _ in first })
                    return Playlist(
                        channels: try await streams.map { client.channel(from: $0, categoryName: $0.categoryID.flatMap { names[$0] }) })
                }
            },
            library: { connection in
                let client = try Self.client(for: connection, session: session)
                async let movies = client.vodStreams()
                async let series = client.series()
                return SourceSetup.Library(movies: try await movies.items.count, series: try await series.items.count)
            },
            guide: guide)
    }

    private static func client(for connection: SourceConnector.Connection, session: URLSession) throws -> XtreamClient {
        guard let login = connection.login else { throw ConnectFailure.rejected }
        return XtreamClient(
            credentials: .init(server: connection.descriptor.url, username: login.username, password: login.password), session: session)
    }
}
