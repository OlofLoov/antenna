import AntennaCore
import Foundation
import Observation

/// The titles of one section, Movies or Series, from every Xtream source
/// (movies-and-series-browsing capability): each source as it loads, the
/// banner, the rows and the banner's details. Loading starts the first time
/// the section opens and the titles stay while the app runs.
@MainActor @Observable
final class ShelfModel {
    struct Dependencies {
        var load: @MainActor (SourceDescriptor, ShelfTitle.Kind) async throws -> ShelfCatalogue
        var hasLogin: @MainActor (SourceDescriptor) -> Bool
        var details: @MainActor (SourceDescriptor, ShelfTitle) async throws -> ShelfDetails
        /// A series' episodes in the client's order.
        var episodes: @MainActor (SourceDescriptor, ShelfTitle) async throws -> [Episode]
        /// A title page's info call.
        var info: @MainActor (SourceDescriptor, ShelfTitle) async throws -> TitleInfo = { _, _ in
            throw ShelfLoader.LoadError.unknownTitle
        }
        /// How often to look for a login that has not arrived yet.
        var loginCheck = Duration.seconds(5)
    }

    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    let kind: ShelfTitle.Kind
    private(set) var sources: [ShelfSource] = []
    /// Every source's titles, in source order and each source's order.
    private(set) var titles: [ShelfTitle] = []
    private(set) var rows: [ShelfRow] = []
    private(set) var banner: [ShelfTitle] = []
    /// The banner's details by title id, once loaded.
    private(set) var details: [String: ShelfDetails] = [:]
    /// False until the section first opens; nothing loads before.
    private(set) var opened = false
    /// Failed sources whose banner the user dismissed.
    private(set) var dismissed: Set<UUID> = []
    /// Series' episode lists by series id, once loaded.
    private(set) var episodes: [String: [Episode]] = [:]

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var catalogues: [UUID: ShelfCatalogue] = [:]
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var loginWatch: Task<Void, Never>?
    @ObservationIgnored private var byKey: [ActivityKey: ShelfTitle] = [:]

    init(kind: ShelfTitle.Kind, _ dependencies: Dependencies) {
        self.kind = kind
        self.dependencies = dependencies
    }

    /// What the section shows for the sources as they stand.
    var status: ShelfStatus {
        ShelfStatus(sources: sources, kind: kind, dismissed: dismissed)
    }

    /// The loaded title with this key, or nil.
    func title(_ key: ActivityKey) -> ShelfTitle? {
        byKey[key]
    }

    /// The source a title came from, or nil once it is gone.
    func source(of title: ShelfTitle) -> SourceDescriptor? {
        descriptors[title.sourceID]
    }

    // MARK: Sources

    /// Call on appearance and whenever the stored sources change. Only
    /// Xtream sources count. Before the section opens this only records
    /// them; afterwards new and edited sources load and removed ones drop out.
    func sourcesChanged(_ all: [SourceDescriptor]) {
        var seen: Set<UUID> = []
        let list = all.filter { $0.kind == .xtream && seen.insert($0.id).inserted }
        let ids = Set(list.map(\.id))
        for id in descriptors.keys where !ids.contains(id) {
            loads[id]?.cancel()
            loads[id] = nil
            descriptors[id] = nil
            catalogues[id] = nil
        }
        var changed: [SourceDescriptor] = []
        for source in list where descriptors[source.id] != source {
            descriptors[source.id] = source
            changed.append(source)
        }
        let previous = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        sources = list.map { source in
            var row = previous[source.id] ?? ShelfSource(id: source.id, name: source.name, state: .loading)
            row.name = source.name
            return row
        }
        rebuild()
        if opened { changed.forEach(startLoad) }
    }

    /// The section opened: the first time every source loads; afterwards a
    /// source waiting for its login is tried again
    /// (movies-and-series-browsing/when-sources-fail).
    func open() {
        guard opened else {
            opened = true
            descriptors.values.forEach(startLoad)
            return
        }
        checkLogins()
    }

    /// Asks the failed sources again. Sources with titles keep them.
    func retry() {
        for row in sources where row.state.isFailure {
            if let source = descriptors[row.id] { startLoad(source) }
        }
    }

    /// Hides the failure banner until another source fails.
    func dismissBanner() {
        dismissed.formUnion(sources.filter(\.state.isFailure).map(\.id))
    }

    /// Loads each source still waiting for its login whose login has arrived.
    func checkLogins() {
        guard opened else { return }
        for row in sources where row.state == .waitingForLogin {
            if let source = descriptors[row.id], dependencies.hasLogin(source) { startLoad(source) }
        }
    }

    /// Waits until no source is loading. For tests.
    func settled() async {
        while let next = loads.values.first {
            await next.value
        }
    }

    private func startLoad(_ source: SourceDescriptor) {
        loads[source.id]?.cancel()
        catalogues[source.id] = nil
        dismissed.remove(source.id)
        setState(.loading, for: source.id)
        rebuild()
        let kind = kind
        loads[source.id] = Task { [weak self] in
            guard let self else { return }
            let result: Result<ShelfCatalogue, any Error>
            if !dependencies.hasLogin(source) {
                result = .failure(LoadFailure.waitingForLogin)
            } else {
                do {
                    result = .success(try await dependencies.load(source, kind))
                } catch {
                    result = .failure(error)
                }
            }
            guard !Task.isCancelled else { return }
            loads[source.id] = nil
            finish(source, with: result)
        }
    }

    private func finish(_ source: SourceDescriptor, with result: Result<ShelfCatalogue, any Error>) {
        switch result {
        case .success(let catalogue):
            catalogues[source.id] = catalogue
            setState(.loaded(titles: catalogue.titles.count), for: source.id)
        case .failure(let failure):
            let state = Self.state(for: failure)
            setState(state, for: source.id)
            if state == .waitingForLogin { watchLogins() }
        }
        rebuild()
    }

    private func watchLogins() {
        guard loginWatch == nil else { return }
        loginWatch = Task { [weak self] in
            while let self, sources.contains(where: { $0.state == .waitingForLogin }) {
                try? await Task.sleep(for: dependencies.loginCheck)
                guard !Task.isCancelled else { break }
                checkLogins()
            }
            self?.loginWatch = nil
        }
    }

    private static func state(for error: any Error) -> ShelfSourceState {
        if case LoadFailure.waitingForLogin? = error as? LoadFailure { return .waitingForLogin }
        if case ShelfLoader.LoadError.noLogin? = error as? ShelfLoader.LoadError { return .waitingForLogin }
        let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
        if let urlError = error as? URLError, offline.contains(urlError.code) { return .offline }
        return .failed
    }

    private func setState(_ state: ShelfSourceState, for id: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].state = state
    }

    private func rebuild() {
        let loaded = sources.compactMap { catalogues[$0.id] }
        let all = loaded.flatMap(\.titles)
        guard all != titles else { return }
        titles = all
        byKey = Dictionary(all.map { ($0.activityKey, $0) }, uniquingKeysWith: { first, _ in first })
        rows = Shelf.rows(all, categoryOrder: Shelf.categoryOrder(loaded.map(\.categories)), now: .now)
        banner = Shelf.banner(all)
    }

    // MARK: Banner details

    /// Loads the year, length and description of a banner title once. A
    /// failure leaves the banner with the name and category.
    func loadDetails(_ title: ShelfTitle) async {
        guard !asked.contains(title.id), let source = descriptors[title.sourceID] else { return }
        asked.insert(title.id)
        guard let found = try? await dependencies.details(source, title) else { return }
        details[title.id] = found
    }

    // MARK: Episodes

    /// A series' episodes, from memory once loaded. Throws when the list
    /// fails to load, so the caller can offer Retry.
    func loadEpisodes(_ series: ShelfTitle) async throws -> [Episode] {
        if let known = episodes[series.id] { return known }
        guard let source = descriptors[series.sourceID] else { throw ShelfLoader.LoadError.unknownTitle }
        let list = try await dependencies.episodes(source, series)
        episodes[series.id] = list
        return list
    }

    /// The info call for a title page, asked every time. A series' episodes
    /// are kept for Continue watching. Throws `LoadFailure.waitingForLogin`
    /// when the source's login is not on this device.
    func info(_ title: ShelfTitle) async throws -> TitleInfo {
        guard let source = descriptors[title.sourceID] else { throw ShelfLoader.LoadError.unknownTitle }
        guard dependencies.hasLogin(source) else { throw LoadFailure.waitingForLogin }
        let info = try await dependencies.info(source, title)
        if case .series(let series) = info { episodes[title.id] = series.episodes }
        return info
    }

    /// True when the title's source has its login on this device.
    func hasLogin(_ title: ShelfTitle) -> Bool {
        descriptors[title.sourceID].map(dependencies.hasLogin) ?? false
    }

    /// True while the title's source is still in the library.
    func hasSource(_ title: ShelfTitle) -> Bool {
        sources.contains { $0.id == title.sourceID }
    }

    /// Loads a series' episodes for its Continue watching caption, ignoring failures.
    func prefetchEpisodes(_ series: ShelfTitle) async {
        _ = try? await loadEpisodes(series)
    }
}

/// Movies and Series side by side, so switching sections reloads nothing.
@MainActor @Observable
final class ShelfLibrary {
    let movies: ShelfModel
    let series: ShelfModel
    /// The title page open over a section, nil when none is
    /// (title-detail-and-episode-picker).
    private(set) var page: TitleRoute?
    /// The page just closed, until the poster or button that opened it
    /// takes focus back (title-detail-and-episode-picker/back-to-where-you-were).
    private(set) var returning: TitleRoute?
    /// True with at least one Xtream source, whether or not it has answered
    /// (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
    private(set) var hasXtream = false

    init(movies: ShelfModel, series: ShelfModel) {
        self.movies = movies
        self.series = series
    }

    func model(_ kind: ShelfTitle.Kind) -> ShelfModel {
        kind == .movie ? movies : series
    }

    func sourcesChanged(_ all: [SourceDescriptor]) {
        hasXtream = all.contains { $0.kind == .xtream }
        movies.sourcesChanged(all)
        series.sourcesChanged(all)
    }

    /// One section opened. Both load, because Continue watching shows
    /// movies and series together
    /// (movies-and-series-browsing/continue-watching).
    func open() {
        movies.open()
        series.open()
    }

    /// Opens a title's page over the section it was picked in.
    func openPage(_ title: ShelfTitle, from origin: TitleRoute.Origin, in section: ShelfTitle.Kind) {
        page = TitleRoute(title: title, section: section, origin: origin, model: TitleModel(title: title, shelf: model(title.kind)))
    }

    /// Closes the page; the section shows as it was.
    func closePage() {
        returning = page
        page = nil
    }

    /// The starting poster or button has focus again.
    func returned() {
        returning = nil
    }

    /// The app came back to the foreground: sources waiting for a login try again.
    func becameActive() {
        movies.checkLogins()
        series.checkLogins()
    }
}

extension ShelfLibrary {
    /// The library the app runs on, reading through `loader`.
    static func live(_ loader: ShelfLoader) -> ShelfLibrary {
        let dependencies = ShelfModel.Dependencies(
            load: { try await loader.load($0, kind: $1) },
            hasLogin: { loader.hasLogin($0) },
            details: { try await loader.details($0, title: $1) },
            episodes: { try await loader.episodes($0, series: $1) })
        return ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
    }
}

/// An open title page and where it was opened from, so going back can put
/// focus or the scroll position on the starting point
/// (title-detail-and-episode-picker/back-to-where-you-were).
struct TitleRoute: Equatable {
    enum Origin: Equatable {
        /// The banner's More info button.
        case banner
        /// A poster, or the More info item in its menu, in the row or grid
        /// named by its identifier part.
        case poster(row: String)
    }

    var title: ShelfTitle
    /// The section the page shows over.
    var section: ShelfTitle.Kind
    var origin: Origin
    /// The page's details and episodes, new each time a page opens.
    let model: TitleModel

    static func == (lhs: TitleRoute, rhs: TitleRoute) -> Bool {
        lhs.title == rhs.title && lhs.section == rhs.section && lhs.origin == rhs.origin && lhs.model === rhs.model
    }
}
