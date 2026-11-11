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

    /// Yields after every save to `container`, from this device or arriving
    /// from iCloud, so a screen reads again
    /// (watch-progress-sync/changes-from-another-device-show-up-without-reopening-the-screen).
    /// Each call makes its own stream, and nothing is yielded on creation.
    static func changes(in container: ModelContainer) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let center = NotificationCenter.default
            let mine = ObjectIdentifier(container)
            let saved = center.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { note in
                guard let context = note.object as? ModelContext, ObjectIdentifier(context.container) == mine else { return }
                continuation.yield()
            }
            let imported = center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
                continuation.yield()
            }
            let observers = Observers(tokens: [saved, imported])
            continuation.onTermination = { _ in observers.tokens.forEach(center.removeObserver) }
        }
    }
}

/// Notification tokens a stream removes when it ends. NotificationCenter
/// tokens are safe to remove from any thread.
private struct Observers: @unchecked Sendable {
    let tokens: [any NSObjectProtocol]
}
