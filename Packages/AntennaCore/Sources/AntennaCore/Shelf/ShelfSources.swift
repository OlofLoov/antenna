import Foundation

/// One source's movies or series with its category names in the
/// provider's order.
public struct ShelfCatalogue: Sendable, Hashable {
    public var titles: [ShelfTitle]
    public var categories: [String]

    public init(titles: [ShelfTitle], categories: [String]) {
        self.titles = titles
        self.categories = categories
    }

    /// A source's movies. A category id the provider repeats keeps its first name.
    public init(movies: [VODItem], categories: [XtreamCategory], sourceID: UUID) {
        let names = Self.names(categories)
        self.init(titles: movies.map { ShelfTitle(movie: $0, sourceID: sourceID, categories: names) }, categories: Self.order(categories))
    }

    /// A source's series, with the category rule of `init(movies:categories:sourceID:)`.
    public init(series: [Series], categories: [XtreamCategory], sourceID: UUID) {
        let names = Self.names(categories)
        self.init(titles: series.map { ShelfTitle(series: $0, sourceID: sourceID, categories: names) }, categories: Self.order(categories))
    }

    private static func names(_ categories: [XtreamCategory]) -> [String: String] {
        Dictionary(categories.map { ($0.categoryID, $0.categoryName) }, uniquingKeysWith: { first, _ in first })
    }

    private static func order(_ categories: [XtreamCategory]) -> [String] {
        Shelf.categoryOrder([categories.map(\.categoryName)])
    }
}

/// How far one Xtream source got with its movies or series.
public enum ShelfSourceState: Sendable, Hashable {
    case loading
    case loaded(titles: Int)
    case offline
    case failed
    case waitingForLogin

    /// Offline or failed: Retry asks it again.
    public var isFailure: Bool { self == .offline || self == .failed }

    public var hasTitles: Bool {
        if case .loaded(let count) = self { return count > 0 }
        return false
    }
}

/// One source as the section lists it while titles load or fail.
public struct ShelfSource: Identifiable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var state: ShelfSourceState

    public init(id: UUID, name: String, state: ShelfSourceState) {
        self.id = id
        self.name = name
        self.state = state
    }
}

/// What the section shows for its sources as they stand
/// (movies-and-series-browsing/when-sources-fail). A source's own error
/// text is never part of it.
public enum ShelfStatus: Sendable, Hashable {
    /// No source has titles yet and at least one is still loading.
    case loading([ShelfSource])
    /// No source has titles, every failure was the connection.
    case offline(waiting: [String])
    /// No source has titles and at least one failed.
    case failed(waiting: [String])
    /// Every source answered with nothing or waits for its login: a line per source.
    case empty(lines: [String])
    /// Titles show, under a banner naming the sources that failed unless
    /// dismissed, with a note per source waiting for its login.
    case titles(banner: String?, waiting: [ShelfSource])

    /// `dismissed` holds the failed sources whose banner the user closed.
    public init(sources: [ShelfSource], kind: ShelfTitle.Kind, dismissed: Set<UUID> = []) {
        let waiting = sources.filter { $0.state == .waitingForLogin }
        guard sources.contains(where: \.state.hasTitles) else {
            if sources.contains(where: { $0.state == .loading }) || sources.isEmpty {
                self = .loading(sources)
                return
            }
            let lines = waiting.map { "\($0.name): waiting for its login to sync from iCloud" }
            let failures = sources.filter(\.state.isFailure)
            if !failures.isEmpty, failures.allSatisfy({ $0.state == .offline }) {
                self = .offline(waiting: lines)
            } else if !failures.isEmpty {
                self = .failed(waiting: lines)
            } else {
                self = .empty(lines: sources.map { Self.emptyLine($0, kind: kind) })
            }
            return
        }
        let failed = sources.filter { $0.state.isFailure && !dismissed.contains($0.id) }
        self = .titles(banner: failed.isEmpty ? nil : "Could not load " + Self.list(failed.map(\.name)), waiting: waiting)
    }

    public static let offlineTitle = "You're offline."
    public static let offlineLine = "Connect to the internet and try again."
    public static let emptyTitle = "Nothing here yet"

    /// "Could not load movies" or "Could not load series".
    public static func failedTitle(_ kind: ShelfTitle.Kind) -> String {
        "Could not load " + noun(kind)
    }

    private static func noun(_ kind: ShelfTitle.Kind) -> String {
        kind == .movie ? "movies" : "series"
    }

    private static func emptyLine(_ source: ShelfSource, kind: ShelfTitle.Kind) -> String {
        source.state == .waitingForLogin
            ? "\(source.name): waiting for its login to sync from iCloud" : "\(source.name): no \(noun(kind))"
    }

    private static func list(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
