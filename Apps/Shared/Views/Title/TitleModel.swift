import AntennaCore
import Foundation
import Observation
import os

/// One open title page (title-detail-and-episode-picker): what is known at
/// once, the info call's answer, and for a series its season groups. A page
/// asks the provider once each time it opens; leaving cancels the request
/// and a late reply changes nothing.
@MainActor @Observable
final class TitleModel {
    /// Where the info call stands.
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(TitleProblem)
    }

    let title: ShelfTitle
    private(set) var metadata: TitleMetadata
    private(set) var phase: Phase = .loading
    /// A series' episodes in season groups, empty until they load.
    private(set) var groups: [SeasonGroup] = []
    /// Episodes the provider listed but the client could not read.
    private(set) var skipped = 0
    /// The picked season's group id; nil follows the play target.
    var pickedSeason: String?
    /// The movie with the info call's file extension once it answers.
    private(set) var playable: ShelfTitle
    /// The episode played last from this page, brought into view on the way back.
    private(set) var lastPlayed: String?

    @ObservationIgnored private let shelf: ShelfModel

    init(title: ShelfTitle, shelf: ShelfModel) {
        self.title = title
        self.shelf = shelf
        metadata = TitleMetadata(title: title)
        playable = title
    }

    /// Every episode in the picker's order.
    var episodes: [Episode] {
        groups.flatMap(\.episodes)
    }

    /// Asks the provider for the details, and a series' episodes. Call from
    /// a task tied to the page, so leaving cancels it.
    func load() async {
        phase = .loading
        do {
            let info = try await shelf.info(title)
            guard !Task.isCancelled else { return }
            apply(info)
            phase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            let kind = title.kind == .movie ? "movie" : "series"
            Self.logger.error("\(kind, privacy: .public) info failed: \(Self.reason(error), privacy: .public)")
            phase = .failed(problem(for: error))
        }
    }

    static let logger = Logger(subsystem: "se.codecrave.antenna", category: "titles")

    /// Why a load failed, with no address, login or body in it, for the log.
    static func reason(_ error: any Error) -> String {
        if let load = error as? ShelfLoader.LoadError { return "\(load)" }
        if let failure = error as? ShelfModel.LoadFailure { return "\(failure)" }
        return LoadFailureReason.text(for: error)
    }

    /// Shows the waiting line when the login is not on this device, so Play
    /// can say why nothing plays. Returns true when the login is here.
    func checkLogin() -> Bool {
        guard shelf.hasLogin(title) else {
            phase = .failed(.waitingForLogin(sourceName))
            return false
        }
        return true
    }

    /// Where `episode` plays from, keeping its season picked and the
    /// episode to bring into view when playback ends
    /// (title-detail-and-episode-picker/play-an-episode-and-come-back).
    func willPlay(_ episode: Episode, progress: [String: WatchProgress]) -> Double {
        pickedSeason = groups.first { $0.episodes.contains(episode) }?.id
        lastPlayed = episode.id
        return progress[episode.id]?.resumePosition ?? 0
    }

    /// True while the title's source is still in the library.
    var sourceExists: Bool {
        shelf.hasSource(title)
    }

    private var sourceName: String {
        shelf.sources.first { $0.id == title.sourceID }?.name ?? "Source"
    }

    private func apply(_ info: TitleInfo) {
        switch info {
        case .movie(let movie):
            metadata = TitleMetadata(movie: title, info: movie)
            if let ext = movie.containerExtension { playable.containerExtension = ext }
        case .series(let series):
            groups = SeasonGroup.group(series.episodes)
            skipped = series.skippedEpisodes
            metadata = TitleMetadata(series: title, info: series, groups: groups)
        }
    }

    private func problem(for error: any Error) -> TitleProblem {
        if case ShelfModel.LoadFailure.waitingForLogin? = error as? ShelfModel.LoadFailure { return .waitingForLogin(sourceName) }
        if case ShelfLoader.LoadError.noLogin? = error as? ShelfLoader.LoadError { return .waitingForLogin(sourceName) }
        if LoadFailureReason.isOffline(error) { return .offline }
        return .failed
    }
}

/// Why the page's details or episodes are missing
/// (title-detail-and-episode-picker/when-details-or-episodes-do-not-load).
enum TitleProblem: Equatable {
    case offline
    case failed
    /// The source's name.
    case waitingForLogin(String)

    /// The line the page shows: "Could not load details" for a movie and
    /// "Could not load episodes" for a series, the offline message, or the
    /// waiting line.
    func message(_ kind: ShelfTitle.Kind) -> String {
        switch self {
        case .offline: "\(ShelfStatus.offlineTitle) \(ShelfStatus.offlineLine)"
        case .failed: kind == .movie ? "Could not load details" : "Could not load episodes"
        case .waitingForLogin(let source): "\(source): waiting for its login to sync from iCloud"
        }
    }
}
