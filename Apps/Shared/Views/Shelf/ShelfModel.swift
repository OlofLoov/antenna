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
        /// A series' episodes in the client's order.
        var episodes: @MainActor (SourceDescriptor, ShelfTitle) async throws -> [Episode]
        /// A title's info call, for the banner, the Apple TV preview and the
        /// title page.
        var info: @MainActor (SourceDescriptor, ShelfTitle) async throws -> TitleInfo
        /// How often to look for a login that has not arrived yet.
        var loginCheck = Duration.seconds(5)
    }

    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    let kind: ShelfTitle.Kind
    private(set) var sources: [ShelfSource] = []
    /// The rows, the banner and the lookups, built off the main actor each
    /// time a source's titles change
    /// (movies-and-series-browsing/browsing-stays-responsive).
    private(set) var index = ShelfIndex.empty
    /// Bumped each time `index` changes, so the people index knows to rebuild.
    private(set) var indexRevision = 0
    /// Details by title id, once the banner, the preview or a page has asked.
    private(set) var details: [String: ShelfDetails] = [:]
    /// Titles whose info call has answered or failed.
    private(set) var answered: Set<String> = []
    /// True when the current profile shows adult content. Unless it is set
    /// the index leaves adult titles out; a change builds it again
    /// (adult-content/hidden-everywhere-by-default).
    var showsAdult = false {
        didSet { if showsAdult != oldValue { rebuild() } }
    }
    /// False until the section first opens; nothing loads before.
    private(set) var opened = false
    /// Failed sources whose banner the user dismissed.
    private(set) var dismissed: Set<UUID> = []
    /// Series' episode lists by series id, once loaded.
    private(set) var episodes: [String: [Episode]] = [:]

    @ObservationIgnored private let dependencies: Dependencies
    /// Hears every info answer, whichever screen asked, so the names in it
    /// reach the people index (browse-by-person/a-person-s-page-never-asks-the-provider).
    @ObservationIgnored var heard: (ShelfTitle, TitleInfo) -> Void = { _, _ in }
    @ObservationIgnored private var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var catalogues: [UUID: ShelfCatalogue] = [:]
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var kept: [ActivityKey: TitleInfo] = [:]
    @ObservationIgnored private var keptOrder: [ActivityKey] = []
    @ObservationIgnored private var inFlight: [ActivityKey: Task<TitleInfo, any Error>] = [:]
    @ObservationIgnored private var previewQueue = OneAtATime()
    @ObservationIgnored private var previewTitles: [String: ShelfTitle] = [:]
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var loginWatch: Task<Void, Never>?
    /// Bumped whenever a catalogue arrives or goes.
    @ObservationIgnored private var revision = 0
    /// The sources and revision of the last index asked for.
    @ObservationIgnored private var requested: IndexKey?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var building: Task<Void, Never>?
    /// Loaded states that show with the index holding their titles.
    @ObservationIgnored private var pendingStates: [UUID: ShelfSourceState] = [:]
    /// Grid lists in their order, kept until the index changes.
    @ObservationIgnored private var sortedLists: [SortedList: [ShelfTitle]] = [:]

    private struct IndexKey: Equatable {
        var sources: [UUID]
        var revision: Int
        var showsAdult: Bool
    }

    private struct SortedList: Hashable {
        var genre: String?
        var sort: ShelfSort
    }

    init(kind: ShelfTitle.Kind, _ dependencies: Dependencies) {
        self.kind = kind
        self.dependencies = dependencies
    }

    /// What the section shows for the sources as they stand.
    var status: ShelfStatus {
        ShelfStatus(sources: sources, kind: kind, dismissed: dismissed)
    }

    /// The section's titles, or one genre's, in `sort` order. Sorted once
    /// per index, so a grid's redraws do not sort again
    /// (movies-and-series-browsing/browsing-stays-responsive).
    func titles(in genre: String? = nil, sortedBy sort: ShelfSort) -> [ShelfTitle] {
        let key = SortedList(genre: genre, sort: sort)
        if let kept = sortedLists[key] { return kept }
        let list: [ShelfTitle] =
            switch (genre, sort) {
            case (nil, .recentlyAdded): index.newest
            case (nil, _): Shelf.sorted(index.titles, by: sort)
            case (let genre?, _): Shelf.sorted(Shelf.titles(in: genre, of: index.titles), by: sort)
            }
        sortedLists[key] = list
        return list
    }

    /// The source a title came from, or nil once it is gone.
    func source(of title: ShelfTitle) -> SourceDescriptor? {
        descriptors[title.sourceID]
    }

    // MARK: Sources

    /// Call on appearance and whenever the stored sources change. Only
    /// Xtream sources and playlists count
    /// (m3u-playlists/playlist-movies-show-in-movies, m3u-playlists/playlist-series-show-in-series). Before the section opens this only records
    /// them; afterwards new and edited sources load and removed ones drop out.
    func sourcesChanged(_ all: [SourceDescriptor]) {
        var seen: Set<UUID> = []
        let kinds: Set<SourceKind> = [.xtream, .m3u, .m3uFile]
        let list = all.filter { kinds.contains($0.kind) && seen.insert($0.id).inserted }
        let ids = Set(list.map(\.id))
        for id in descriptors.keys where !ids.contains(id) {
            loads[id]?.cancel()
            loads[id] = nil
            descriptors[id] = nil
            setCatalogue(nil, for: id)
            pendingStates[id] = nil
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

    /// Waits until no source is loading and the index is built. For tests.
    func settled() async {
        while true {
            if let next = loads.values.first {
                await next.value
            } else if let building {
                await building.value
            } else {
                return
            }
        }
    }

    private func startLoad(_ source: SourceDescriptor) {
        loads[source.id]?.cancel()
        setCatalogue(nil, for: source.id)
        pendingStates[source.id] = nil
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
            setCatalogue(catalogue, for: source.id)
            // The state shows with the index holding these titles.
            pendingStates[source.id] = .loaded(titles: catalogue.titles.count)
        case .failure(let failure):
            pendingStates[source.id] = nil
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

    private func setCatalogue(_ catalogue: ShelfCatalogue?, for id: UUID) {
        guard catalogue != nil || catalogues[id] != nil else { return }
        catalogues[id] = catalogue
        revision += 1
    }

    /// Builds the index of the loaded catalogues off the main actor when
    /// they changed, then shows it with the sources' loaded states. Only
    /// the newest build is shown.
    private func rebuild() {
        let key = IndexKey(
            sources: sources.compactMap { catalogues[$0.id] == nil ? nil : $0.id }, revision: revision, showsAdult: showsAdult)
        guard key != requested else {
            if building == nil { showPendingStates() }
            return
        }
        requested = key
        generation += 1
        let current = generation
        let loaded = sources.compactMap { catalogues[$0.id] }
        building = Task { [weak self] in
            let signpost = BrowseSignposts.signposter.beginInterval("shelf index")
            let index = await ShelfIndex.build(loaded, showsAdult: key.showsAdult, now: .now)
            BrowseSignposts.signposter.endInterval("shelf index", signpost)
            guard let self, current == generation else { return }
            self.index = index
            indexRevision += 1
            sortedLists = [:]
            showPendingStates()
            building = nil
        }
    }

    private func showPendingStates() {
        for (id, state) in pendingStates { setState(state, for: id) }
        pendingStates = [:]
    }

    // MARK: Details

    /// How many titles' info answers stay in memory, oldest dropped first.
    static let keptLimit = 100

    /// Loads the year, length and description of a title once per launch,
    /// for the banner or the Apple TV preview. A failure leaves the name and
    /// category; only a page's Retry asks again
    /// (movies-and-series-browsing/title-details-are-asked-once-per-title).
    func loadDetails(_ title: ShelfTitle) async {
        guard !asked.contains(title.id), descriptors[title.sourceID] != nil else { return }
        asked.insert(title.id)
        defer { answered.insert(title.id) }
        _ = try? await fetch(title)
    }

    /// Asks about a title the Apple TV highlight rested on, one request at a
    /// time. A title that rests while a request is out is asked about next,
    /// replacing any title already waiting. Titles asked about before are
    /// skipped.
    func preview(_ title: ShelfTitle) {
        guard !asked.contains(title.id), descriptors[title.sourceID] != nil else { return }
        previewTitles[title.id] = title
        let first = previewQueue.ask(title.id)
        let live = [previewQueue.asking, previewQueue.waiting]
        previewTitles = previewTitles.filter { live.contains($0.key) }
        guard let first else { return }
        previewTask = Task { [weak self] in
            var next: String? = first
            while let id = next, let self {
                if let title = previewTitles[id] { await loadDetails(title) }
                previewTitles[id] = nil
                next = previewQueue.finished()
            }
        }
    }

    /// Waits until no preview request is out. For tests.
    func previewsSettled() async {
        await previewTask?.value
    }

    /// The info answer kept for a title, if any.
    func keptInfo(_ title: ShelfTitle) -> TitleInfo? {
        kept[title.activityKey]
    }

    /// The kept answer, the request already out for the title, or a new
    /// request. Only the caller that started a request keeps its answer.
    private func fetch(_ title: ShelfTitle) async throws -> TitleInfo {
        let key = title.activityKey
        if let known = kept[key] { return known }
        if let running = inFlight[key] { return try await running.value }
        guard let source = descriptors[title.sourceID] else { throw ShelfLoader.LoadError.unknownTitle }
        guard dependencies.hasLogin(source) else { throw LoadFailure.waitingForLogin }
        let info = dependencies.info
        // Not a child task: a page that closes stops waiting, but the
        // request runs to its end and the answer is kept for the next ask.
        let request = Task { try await info(source, title) }
        inFlight[key] = request
        defer { inFlight[key] = nil }
        let answer = try await request.value
        keep(answer, for: title)
        return answer
    }

    private func keep(_ answer: TitleInfo, for title: ShelfTitle) {
        let key = title.activityKey
        if kept.updateValue(answer, forKey: key) != nil { keptOrder.removeAll { $0 == key } }
        keptOrder.append(key)
        while keptOrder.count > Self.keptLimit { kept[keptOrder.removeFirst()] = nil }
        details[title.id] = ShelfDetails(answer)
        heard(title, answer)
        asked.insert(title.id)
        answered.insert(title.id)
        if case .series(let series) = answer { episodes[title.id] = series.episodes }
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

    /// The info call for a title page: the answer kept from the banner, the
    /// preview or an earlier page, else one request. A series' episodes are
    /// kept for Continue watching. Throws `LoadFailure.waitingForLogin` when
    /// the source's login is not on this device.
    func info(_ title: ShelfTitle) async throws -> TitleInfo {
        try await fetch(title)
    }

    /// Asks the provider again, for a page's Retry.
    func refreshInfo(_ title: ShelfTitle) async throws -> TitleInfo {
        let key = title.activityKey
        if kept.removeValue(forKey: key) != nil { keptOrder.removeAll { $0 == key } }
        return try await fetch(title)
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

extension ShelfModel {
    /// Every source's titles, in source order and each source's order.
    var titles: [ShelfTitle] { index.titles }
    var rows: [ShelfRow] { index.rows }
    var banner: [ShelfTitle] { index.banner }

    /// The loaded title with this key, or nil.
    func title(_ key: ActivityKey) -> ShelfTitle? {
        index.title(key)
    }
}
