import AntennaCore
import Foundation
import SwiftData
import SwiftUI
import os

/// The app's guide store. Holds the latest `GuideIndex` for views to read and
/// forwards commands to a `GuideEngine`, which does the work off the main
/// actor. Maps `SourceRecord`s and Keychain items to the engine's values.
@MainActor @Observable
final class AppGuideStore {
    private(set) var index = GuideIndex()
    @ObservationIgnored private let engine: GuideEngine
    @ObservationIgnored private var knownSources: Set<UUID> = []
    @ObservationIgnored private var listener: Task<Void, Never>?

    /// The listener runs as long as the engine does. The app keeps one store
    /// for its whole life; a test's store and engine end with the process.
    init(engine: GuideEngine) {
        self.engine = engine
        listener = Task { [weak self, engine] in
            for await index in engine.indexes {
                self?.index = index
            }
        }
    }

    /// The store the app runs on. Tests pass a stub session, their own
    /// credential store and a temporary directory.
    static func live(
        container: ModelContainer,
        session: URLSession = URLSession(configuration: .guide),
        credentials: any CredentialStoring = CredentialStore(),
        directory: URL = .cachesDirectory.appending(path: "Guide"),
        stalkerClients: StalkerClients = .shared
    ) -> AppGuideStore {
        let logger = Logger(subsystem: "se.codecrave.antenna", category: "guide")
        let configuration = GuideEngine.Configuration(
            session: session,
            directory: directory,
            sources: { await MainActor.run { AppGuideStore.descriptors(in: container.mainContext, logger: logger) } },
            credential: { key in
                do {
                    guard let found = try credentials.load(for: key) else { return .missing }
                    return .found(username: found.username, password: found.password)
                } catch {
                    return .unreadable
                }
            },
            log: { line in logger.info("\(line, privacy: .public)") },
            stalkerClient: { id in
                if let client = stalkerClients.client(sourceID: id) { return client }
                let source = await MainActor.run { AppGuideStore.source(id, in: container.mainContext) }
                guard let source, let key = source.credentialKey, let credential = try? credentials.load(for: key) else { return nil }
                return stalkerClients.client(for: source, credential: credential)
            }
        )
        return AppGuideStore(engine: GuideEngine(configuration))
    }

    /// Every stored source with a URL, in display order. A failed fetch is
    /// logged and gives no sources.
    static func descriptors(in context: ModelContext, logger: Logger) -> [GuideSourceDescriptor] {
        let records: [SourceRecord]
        do {
            records = try context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder))
        } catch {
            logger.error("guide could not read sources")
            return []
        }
        return records.compactMap { record in
            guard let url = record.url else { return nil }
            return GuideSourceDescriptor(
                sourceID: record.id, kind: record.kind, url: url, epgURL: record.epgURL,
                credentialKey: record.credentialKey, sortOrder: record.sortOrder)
        }
    }

    /// The stored source with `id`, nil when there is none.
    static func source(_ id: UUID, in context: ModelContext) -> SourceDescriptor? {
        let records = (try? context.fetch(FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id }))) ?? []
        return records.first?.descriptor
    }

    /// Removes the guide of every source seen in an earlier call and missing
    /// from `ids`, whether it was deleted here or through iCloud.
    func sourcesChanged(to ids: Set<UUID>) async {
        let gone = knownSources.subtracting(ids)
        knownSources = ids
        for id in gone {
            await engine.remove(sourceID: id)
        }
    }
}

extension AppGuideStore: @MainActor GuideStore {
    var horizon: DateInterval? { index.horizon }

    func programmes(for keys: [GuideKey], in interval: DateInterval) -> [GuideKey: [Programme]] {
        index.programmes(for: keys, in: interval)
    }

    func current(for key: GuideKey, at date: Date) -> Programme? {
        index.current(for: key, at: date)
    }

    func next(for key: GuideKey, after date: Date, count: Int) -> [Programme] {
        index.next(for: key, after: date, count: count)
    }

    func loadingState(for key: GuideKey) -> GuideLoadingState {
        index.loadingState(for: key)
    }

    func loadingState(for channel: Channel) -> GuideLoadingState {
        index.loadingState(for: channel)
    }

    func progressStream() -> AsyncStream<GuideProgress> {
        engine.progressStream()
    }

    func refreshIfStale(now: Date) async {
        await engine.refreshIfStale(now: now)
    }

    func refresh(sourceID: UUID) async {
        await engine.refresh(sourceID: sourceID)
    }

    func update(channels: [Channel]) async {
        engine.update(channels: channels)
    }

    func register(epgURLs: [URL], for sourceID: UUID) async {
        await engine.register(epgURLs: epgURLs, for: sourceID)
    }

    func remove(sourceID: UUID) async {
        await engine.remove(sourceID: sourceID)
    }
}

extension EnvironmentValues {
    /// The guide store screens read. Nil in previews that do not set one.
    @Entry var guideStore: AppGuideStore? = .none
}
