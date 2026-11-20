import AntennaCore
import Foundation
import Observation

/// Movies and Series side by side, so switching sections reloads nothing.
/// Also holds the open title and person pages and the names behind the
/// people index.
@MainActor @Observable
final class ShelfLibrary {
    let movies: ShelfModel
    let series: ShelfModel
    /// The open pages, last on top, over the section or Search the first
    /// one opened in (title-detail-and-episode-picker, browse-by-person).
    private(set) var stack: [LibraryPage] = []
    /// The page closed last, until the poster or button that opened it
    /// takes focus back (title-detail-and-episode-picker/back-to-where-you-were).
    private(set) var returning: TitleRoute?
    /// The page just closed over another page, until the chip or poster
    /// on the page below takes focus back (browse-by-person/a-person-s-page).
    private(set) var popped: LibraryPage?
    /// Which sections the sources offer, set by `ShelfSync`
    /// (m3u-playlists/playlist-titles-show-on-every-platform).
    var offer = TitleOffer.none
    /// The current profile's adult content switch, set by `ShelfSync` and
    /// passed to both sections (adult-content/hidden-everywhere-by-default).
    var showsAdult = false {
        didSet {
            movies.showsAdult = showsAdult
            series.showsAdult = showsAdult
        }
    }
    /// Names from every info answer, kept on the device
    /// (browse-by-person/names-the-provider-sent-are-kept).
    private(set) var learned = LearnedCredits()
    /// Bumped each time `learned` changes.
    private(set) var learnedRevision = 0

    @ObservationIgnored private let peopleStore: PeopleStore?
    @ObservationIgnored private var peopleBuilt: (key: [Int], index: PeopleIndex)?
    @ObservationIgnored private var saving: Task<Void, Never>?
    @ObservationIgnored private var loadingPeople: Task<Void, Never>?

    init(movies: ShelfModel, series: ShelfModel, people: PeopleStore? = nil) {
        self.movies = movies
        self.series = series
        peopleStore = people
        movies.heard = { [weak self] in self?.heard($0, $1) }
        series.heard = { [weak self] in self?.heard($0, $1) }
        if let people {
            loadingPeople = Task { [weak self] in
                let kept = await people.load()
                self?.merge(kept)
            }
        }
    }

    /// The page on top, nil when the section or Search shows.
    var top: LibraryPage? { stack.last }

    /// The title page on top, nil when none or a person page is.
    var page: TitleRoute? {
        if case .title(let route)? = stack.last { return route }
        return nil
    }

    /// The person page on top, nil when none or a title page is.
    var person: PersonRoute? {
        if case .person(let route)? = stack.last { return route }
        return nil
    }

    func model(_ kind: ShelfTitle.Kind) -> ShelfModel {
        kind == .movie ? movies : series
    }

    func sourcesChanged(_ all: [SourceDescriptor]) {
        movies.sourcesChanged(all)
        series.sourcesChanged(all)
        // An empty list is the store before it loads; nothing is dropped then.
        if !all.isEmpty, learned.keep(sources: Set(all.map(\.id))) { learnedChanged() }
    }

    /// One section opened. Both load, because Continue watching shows
    /// movies and series together
    /// (movies-and-series-browsing/continue-watching).
    func open() {
        movies.open()
        series.open()
    }

    /// Opens a title's page over the section it was picked in, in place of
    /// any open pages.
    func openPage(_ title: ShelfTitle, from origin: TitleRoute.Origin, in section: ShelfTitle.Kind) {
        stack = [.title(route(title, section: section, origin: origin))]
        popped = nil
    }

    /// Opens a title's page over the page on top, from a person's page.
    func push(_ title: ShelfTitle) {
        guard let below = top else { return }
        stack.append(.title(route(title, section: below.section, origin: below.origin)))
        popped = nil
    }

    /// Opens a person's page over the page on top, from a chip on a title
    /// page. `chip` is the chip's id, focused again on the way back.
    func openPerson(_ name: PersonName, chip: String) {
        guard let below = top else { return }
        stack.append(.person(PersonRoute(name: name, section: below.section, origin: below.origin, chip: chip)))
        popped = nil
    }

    /// Opens a person's page over Search, in place of any open pages.
    func openPerson(_ name: PersonName, fromSearchIn section: ShelfTitle.Kind) {
        stack = [.person(PersonRoute(name: name, section: section, origin: .search, chip: nil))]
        popped = nil
    }

    /// Goes back one page. Closing the last one shows the section as it was.
    func closePage() {
        guard let closed = stack.popLast() else { return }
        popped = stack.isEmpty ? nil : closed
        if stack.isEmpty, case .title(let route) = closed { returning = route }
    }

    /// Closes every open page.
    func closeAll() {
        if case .title(let route)? = stack.first { returning = route }
        stack = []
        popped = nil
    }

    /// The starting poster or button has focus again.
    func returned() {
        returning = nil
    }

    /// The page below has put focus back on the chip or poster.
    func restored() {
        popped = nil
    }

    /// The app came back to the foreground: sources waiting for a login try again.
    func becameActive() {
        movies.checkLogins()
        series.checkLogins()
    }

    private func route(_ title: ShelfTitle, section: ShelfTitle.Kind, origin: TitleRoute.Origin) -> TitleRoute {
        let model = TitleModel(title: title, shelf: model(title.kind), lookup: TitleLookups.app)
        return TitleRoute(title: title, section: section, origin: origin, model: model)
    }

    // MARK: People

    /// Changes whenever the people index would change.
    var peopleRevision: [Int] {
        [movies.indexRevision, series.indexRevision, learnedRevision]
    }

    /// Everyone the loaded titles name, built off the main actor when the
    /// titles or the learned names changed since the last build.
    func people() async -> PeopleIndex {
        let key = peopleRevision
        if let built = peopleBuilt, built.key == key { return built.index }
        let index = await PeopleIndex.build(titles: movies.titles + series.titles, learned: learned)
        if key == peopleRevision { peopleBuilt = (key, index) }
        return index
    }

    /// Waits for the names kept on the device to load. For tests.
    func peopleLoaded() async {
        await loadingPeople?.value
    }

    private func heard(_ title: ShelfTitle, _ info: TitleInfo) {
        let credits: TitleCredits
        let year: Int?
        switch info {
        case .movie(let movie):
            credits = TitleCredits(cast: movie.cast, director: movie.director)
            year = movie.year
        case .series(let series):
            credits = TitleCredits(cast: series.cast, director: series.director)
            year = series.year
        }
        if learned.record(title, credits: credits, year: year, now: .now) { learnedChanged() }
    }

    /// Adds what the device kept under the names heard since launch, which win.
    private func merge(_ kept: LearnedCredits) {
        guard !kept.isEmpty else { return }
        var merged = kept
        merged.merge(learned)
        learned = merged
        learnedRevision += 1
    }

    /// Saves at most every five seconds while names arrive.
    private func learnedChanged() {
        learnedRevision += 1
        guard let peopleStore, saving == nil else { return }
        saving = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self else { return }
            saving = nil
            await peopleStore.save(learned.encoded(now: .now))
        }
    }
}

/// One open page: a title's or a person's.
enum LibraryPage: Equatable {
    case title(TitleRoute)
    case person(PersonRoute)

    /// The section the page shows over, the first page's.
    var section: ShelfTitle.Kind {
        switch self {
        case .title(let route): route.section
        case .person(let route): route.section
        }
    }

    /// Where the first page was opened from.
    var origin: TitleRoute.Origin {
        switch self {
        case .title(let route): route.origin
        case .person(let route): route.origin
        }
    }
}

/// An open person's page (browse-by-person/a-person-s-page).
struct PersonRoute: Equatable {
    var name: PersonName
    var section: ShelfTitle.Kind
    var origin: TitleRoute.Origin
    /// The chip that opened it, nil from Search.
    var chip: String?
    /// New each time a page opens, so two pages of one person are two pages.
    var id = UUID()
}

extension ShelfLibrary {
    /// The library the app runs on, reading through `loader`.
    static func live(_ loader: ShelfLoader) -> ShelfLibrary {
        let dependencies = ShelfModel.Dependencies(
            load: { try await loader.load($0, kind: $1) },
            hasLogin: { loader.hasLogin($0) },
            episodes: { try await loader.episodes($0, series: $1) },
            info: { try await loader.info($0, title: $1) })
        return ShelfLibrary(
            movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies), people: .live)
    }
}
