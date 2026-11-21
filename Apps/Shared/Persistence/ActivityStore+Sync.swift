import AntennaCore
import CoreData
import Foundation
import SwiftData

extension ActivityStore {
    /// Where an earlier build kept recent searches on the device, newest first.
    static let carriedOverKey = "search.recents"

    /// Moves the searches an earlier build kept under `carriedOverKey` into
    /// Main's synced searches, in their old order, merged with any from other
    /// devices and capped at ten
    /// (watch-progress-sync/recent-searches-from-an-earlier-build-carry-over).
    /// The key goes only after the save, and a second run finds the same
    /// searches already there, so a kill halfway moves nothing twice.
    static func carryOverSearches(from defaults: UserDefaults, into context: ModelContext, now: Date = .now) {
        guard let old = defaults.stringArray(forKey: carriedOverKey) else { return }
        for (query, updatedAt) in RecentSearch.carriedOver(old, now: now) {
            context.insert(RecentSearchRecord(query: query, updatedAt: updatedAt, profileID: nil))
        }
        let records = ((try? context.fetch(FetchDescriptor<RecentSearchRecord>())) ?? []).filter { $0.profileID == nil }
        RecentSearch.resolve(records.map(\.value)).losers.forEach { context.delete(records[$0]) }
        do {
            try context.save()
            defaults.removeObject(forKey: carriedOverKey)
        } catch {
            context.rollback()
        }
    }

    /// Yields after every save to `container` that touches progress, My list
    /// or recent searches, and after every change to the store's history,
    /// which is how iCloud imports arrive, so a screen reads again
    /// (watch-progress-sync/changes-from-another-device-show-up-without-reopening-the-screen).
    /// Each call makes its own stream, and nothing is yielded on creation.
    /// Only the newest change waits while the reader is busy, so a burst of
    /// saves makes one read.
    static func changes(in container: ModelContainer) -> AsyncStream<ActivityChange> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let center = NotificationCenter.default
            let mine = ObjectIdentifier(container)
            let saved = center.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { note in
                guard let context = note.object as? ModelContext, ObjectIdentifier(context.container) == mine,
                    touchesActivity(note.userInfo)
                else { return }
                continuation.yield(ActivityChange(kind: .saved, at: .now))
            }
            let imported = center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
                continuation.yield(ActivityChange(kind: .history, at: .now))
            }
            let observers = Observers(tokens: [saved, imported])
            continuation.onTermination = { _ in observers.tokens.forEach(center.removeObserver) }
        }
    }

    /// The records `ShelfActivity` reads.
    nonisolated static let activityEntities: Set<String> = [
        String(describing: ProgressRecord.self), String(describing: ListEntryRecord.self),
        String(describing: RecentSearchRecord.self),
    ]

    /// True when a save's notification names a progress, My list or recent
    /// search record, or names nothing it can be told from.
    nonisolated private static func touchesActivity(_ info: [AnyHashable: Any]?) -> Bool {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        let named = keys.compactMap { info?[$0.rawValue] as? [PersistentIdentifier] }
        guard !named.isEmpty else { return true }
        return named.joined().contains { activityEntities.contains($0.entityName) }
    }
}

/// A change `ActivityStore.changes` reports.
struct ActivityChange: Sendable {
    enum Kind: Sendable {
        /// A save on this device that names an activity record.
        case saved
        /// A change to the store's history, from iCloud or from any save,
        /// which names no records; `ActivityStore.activityChanged(after:)`
        /// tells whether it touched activity.
        case history
    }

    let kind: Kind
    /// When it was posted.
    let at: ContinuousClock.Instant
}

extension ActivityStore {
    /// The newest transaction in the store's history, nil when it keeps none.
    func historyMark() -> DefaultHistoryToken? {
        var newest = HistoryDescriptor<DefaultHistoryTransaction>(sortBy: [SortDescriptor(\.transactionIdentifier, order: .reverse)])
        newest.fetchLimit = 1
        return (try? context.fetchHistory(newest))?.first?.token
    }

    /// True when a transaction after `mark` touched a progress, My list or
    /// recent search record, and true when that cannot be told.
    func activityChanged(after mark: DefaultHistoryToken?) -> Bool {
        guard let mark else { return true }
        let later = HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate<DefaultHistoryTransaction> { $0.token > mark })
        guard let transactions = try? context.fetchHistory(later) else { return true }
        return transactions.contains { transaction in
            transaction.changes.contains { Self.activityEntities.contains($0.changedPersistentIdentifier.entityName) }
        }
    }
}

/// Notification tokens a stream removes when it ends. NotificationCenter
/// tokens are safe to remove from any thread.
private struct Observers: @unchecked Sendable {
    let tokens: [any NSObjectProtocol]
}
