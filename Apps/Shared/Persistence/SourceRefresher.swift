import AntennaCore
import Foundation
import Observation
import SwiftData
import SwiftUI

/// Loads sources for the screen that lists channels, one at a time in the
/// order asked, and keeps each source's status for Sources and Settings
/// (sources-and-settings capability). Live on iPhone, iPad and Mac and the
/// Apple TV shell load through it; Settings asks it to refresh.
@MainActor @Observable
final class SourceRefresher {
    struct Dependencies {
        var load: @Sendable (SourceDescriptor) async throws -> Playlist
        var hasLogin: @Sendable (SourceDescriptor) -> Bool
        /// True for a file source whose text has not synced yet.
        var waitsForICloud: @Sendable (SourceDescriptor) -> Bool = { _ in false }
        var lastLoads: LastLoadStore = LastLoadStore()
        var guide: AppGuideStore?
        /// How long one source may take before it counts as unreachable.
        var timeout = Duration.seconds(30)
        var now: @MainActor () -> Date = { .now }
        /// Moves saved references from a loaded source's earlier channel ids
        /// to its ids now (favorites/favorites-saved-before-the-id-change-carry-over).
        var migrateIDs: @MainActor (UUID, [String: String]) -> Void = { _, _ in }

        /// Loads through `loader`, the network and the Keychain, and rewrites
        /// earlier channel ids in `container`.
        static func app(loader: SourceLoader, guide: AppGuideStore?, container: ModelContainer? = nil) -> Self {
            var dependencies = Self(
                load: { try await loader.load($0) }, hasLogin: { loader.hasLogin($0) }, waitsForICloud: { loader.waitsForICloud($0) },
                guide: guide)
            if let container {
                dependencies.migrateIDs = { ChannelIDMigration.apply($1, source: $0, in: container.mainContext) }
            }
            return dependencies
        }
    }

    /// Every 12 hours, the refresh preference's default.
    static let defaultInterval = Duration.seconds(12 * 3600)

    /// Each source's status, by id. A source not asked to load has none.
    private(set) var statuses: [UUID: SourceStatus] = [:]

    @ObservationIgnored let dependencies: Dependencies
    /// The screen that owns the channels, told which sources to load again.
    @ObservationIgnored private var reloader: (([UUID]) -> Void)?
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var guideWatch: Task<Void, Never>?
    /// Imported file sources, which change only when re-imported and so
    /// never refresh (local-m3u-file-import/import-and-watch).
    @ObservationIgnored private var fileSources: Set<UUID> = []

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// The status of `id`, with the last load time kept on this device.
    func status(of id: UUID) -> SourceStatus {
        statuses[id] ?? SourceStatus(lastSuccess: dependencies.lastLoads.read(id))
    }

    // MARK: Loading

    /// The screen that holds the channels registers how to load sources again.
    func attach(reload: @escaping ([UUID]) -> Void) {
        reloader = reload
        watchGuide()
    }

    /// False when an Xtream source's login is not on this device; its status says it waits.
    func hasLogin(_ source: SourceDescriptor) -> Bool {
        let has = dependencies.hasLogin(source)
        if !has { update(source.id) { $0.load = dependencies.waitsForICloud(source) ? .waitingForICloud : .waitingForLogin } }
        return has
    }

    /// Loads `source` after every load asked for before it, gives up after
    /// the timeout, and records the outcome. A failure keeps the counts of
    /// the last load that worked (sources-and-settings/a-failed-refresh-keeps-your-channels).
    func load(_ source: SourceDescriptor) async throws -> Playlist {
        let previous = queue
        let id = source.id
        if source.kind == .m3uFile { fileSources.insert(id) }
        update(id) { $0.load = .loading }
        let work = Task<Result<Playlist, any Error>, Never> { [dependencies] in
            await previous?.value
            do {
                try Task.checkCancellation()
                return .success(try await Self.withTimeout(dependencies.timeout) { try await dependencies.load(source) })
            } catch {
                return .failure(error)
            }
        }
        queue = Task { _ = await work.value }
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        switch result {
        case .success(let playlist):
            let now = dependencies.now()
            dependencies.lastLoads.write(now, for: id)
            update(id) {
                $0.load = .loaded
                $0.channels = playlist.channels.count
                $0.groups = Set(playlist.channels.map { $0.group ?? "" }).count
                $0.lastSuccess = now
                if $0.guide == .notStarted, Self.hasGuide(source, playlist) == false { $0.guide = .none }
            }
            if !playlist.formerIDs.isEmpty { dependencies.migrateIDs(id, playlist.formerIDs) }
            return playlist
        case .failure(let error):
            if error is CancellationError || Task.isCancelled {
                update(id) { $0.load = $0.channels == nil ? .idle : .loaded }
            } else if case SourceLoader.LoadError.waitingForICloud? = error as? SourceLoader.LoadError {
                update(id) { $0.load = .waitingForICloud }
            } else if case SourceLoader.LoadError.loginUnreadable? = error as? SourceLoader.LoadError {
                update(id) { $0.load = .failed(SourceLoader.LoadError.loginUnreadable.localizedDescription) }
            } else {
                update(id) { $0.load = .failed(ConnectFailure(Self.mapped(error), host: source.url.host() ?? "the server").message) }
            }
            throw error
        }
    }

    /// Refresh now on one source, or Refresh all with every id in order
    /// (sources-and-settings/refresh-by-hand). Channels stay while they load.
    /// A file source is left out: it changes only when re-imported.
    func refresh(_ ids: [UUID]) {
        let ids = ids.filter { !fileSources.contains($0) }
        if !ids.isEmpty { reloader?(ids) }
    }

    /// The sources loaded in this run whose last load is older than
    /// `interval`; nil interval means manual refresh only
    /// (sources-and-settings/sources-refresh-on-a-schedule).
    func due(interval: Duration?) -> [UUID] {
        guard let interval else { return [] }
        let now = dependencies.now()
        let seconds = TimeInterval(interval.components.seconds)
        return statuses.compactMap { id, status in
            guard !fileSources.contains(id), status.load == .loaded || status.channels != nil, status.load != .loading,
                let last = status.lastSuccess, now.timeIntervalSince(last) >= seconds
            else { return nil }
            return id
        }
    }

    /// Reloads what `due(interval:)` names. Call when the app comes back to the front.
    func refreshDue(interval: Duration?) {
        let ids = due(interval: interval)
        if !ids.isEmpty { refresh(ids) }
    }

    /// Forgets a deleted source's status and its last load time on this device.
    func forget(_ id: UUID) {
        statuses[id] = nil
        dependencies.lastLoads.remove(id)
    }

    // MARK: Guide

    private func watchGuide() {
        guard guideWatch == nil, let guide = dependencies.guide else { return }
        let stream = guide.progressStream()
        guideWatch = Task { [weak self] in
            for await event in stream {
                self?.guideChanged(event)
            }
        }
    }

    private func guideChanged(_ event: GuideProgress) {
        update(event.sourceID) { status in
            switch event {
            case .downloading, .fetching:
                status.guide = .downloading
            case .loaded(_, let matched, let total, let days, _):
                status.guide = .loaded(days: days, matched: matched, total: total)
                status.lastGuideDays = days
            case .failed:
                status.guide = .failed
            }
        }
    }

    // MARK: Helpers

    private func update(_ id: UUID, _ change: (inout SourceStatus) -> Void) {
        var status = status(of: id)
        change(&status)
        statuses[id] = status
    }

    private static func hasGuide(_ source: SourceDescriptor, _ playlist: Playlist) -> Bool {
        source.kind != .m3u || source.epgURL != nil || !playlist.epgURLs.isEmpty
    }

    /// A playlist's bad status as the server error the copy names.
    private static func mapped(_ error: any Error) -> any Error {
        if case SourceLoader.LoadError.badStatus(let status)? = error as? SourceLoader.LoadError {
            return ConnectFailure.serverError(status: status)
        }
        return error
    }

    private static func withTimeout<T: Sendable>(_ limit: Duration, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw URLError(.timedOut) }
            return first
        }
    }
}

/// When each source last loaded on this device, in `UserDefaults` under
/// `settings.lastLoad.<sourceId>`. Never synced; holds a date only.
struct LastLoadStore: @unchecked Sendable {
    static let prefix = "settings.lastLoad."
    var defaults: UserDefaults = .standard

    func read(_ id: UUID) -> Date? {
        guard let data = defaults.data(forKey: Self.prefix + id.uuidString) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: data)
    }

    func write(_ date: Date, for id: UUID) {
        guard let data = try? JSONEncoder().encode(date) else { return }
        defaults.set(data, forKey: Self.prefix + id.uuidString)
    }

    func remove(_ id: UUID) {
        defaults.removeObject(forKey: Self.prefix + id.uuidString)
    }
}

extension EnvironmentValues {
    /// The app's refresher. Nil in previews and screens that run without one.
    @Entry var sourceRefresher: SourceRefresher? = .none
}

extension SourceDescriptor {
    /// True when loading `other` gives the same channels: everything but
    /// the name matches.
    func loadsLike(_ other: SourceDescriptor) -> Bool {
        kind == other.kind && url == other.url && epgURL == other.epgURL && credentialKey == other.credentialKey
    }
}
