import AntennaCore
import Foundation
import SwiftData

/// One profile's watch progress, My list and recent searches
/// (watch-progress-sync), shared by the movies, series and search screens.
///
/// Reads resolve copies from several devices and never write. Writes resolve
/// first and delete the losing copies in the same save. A failed save is
/// rolled back and the call returns normally. Nothing here logs.
@MainActor
struct ActivityStore {
    let context: ModelContext
    let profile: UUID
    /// Saves the context; tests swap in one that fails.
    var save: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    init(context: ModelContext, profile: UUID = Profile.mainID) {
        self.context = context
        self.profile = profile
    }

    // MARK: Progress

    /// The saved progress of one title, or nil.
    func progress(of titleID: String, source: UUID) -> WatchProgress? {
        let resolved = WatchProgress.resolve(progressRecords(titleID: titleID).map(\.value))
        return resolved.winners.first { $0.sourceID == source }
    }

    /// Every title with progress, most recently saved first.
    func allProgress() -> [WatchProgress] {
        WatchProgress.resolve(progressRecords().map(\.value)).winners.sorted(by: WatchProgress.newestFirst)
    }

    /// The episodes of `seriesID` with progress, most recently saved first.
    func episodes(of seriesID: String) -> [WatchProgress] {
        let records = fetch(FetchDescriptor<ProgressRecord>(predicate: #Predicate { $0.seriesID == seriesID }))
        return WatchProgress.episodes(of: seriesID, in: WatchProgress.resolve(owned(records).map(\.value)).winners)
    }

    /// Saves where the user is in a title. A title id that could carry a link
    /// or login is refused.
    func saveProgress(titleID: String, seriesID: String? = nil, source: UUID, position: Double, duration: Double?, now: Date = .now) {
        guard WatchProgress.isStorable(titleID: titleID), position.isFinite, position >= 0 else { return }
        let records = progressRecords(titleID: titleID).filter { $0.sourceID == source }
        let survivor = WatchProgress.resolve(records.map(\.value)).winners.first
        let value = WatchProgress(
            id: "", titleID: titleID, seriesID: seriesID, sourceID: source, position: position, duration: duration,
            updatedAt: WatchProgress.stamp(now: now, replacing: survivor?.updatedAt))
        let saved = ProgressRecord(value, profileID: storedProfile)
        context.insert(saved)
        let all = records + [saved]
        WatchProgress.resolve(all.map(\.value)).losers.forEach { context.delete(all[$0]) }
        commit()
    }

    // MARK: My list

    /// The movies or the series on My list, most recently added first.
    func myList(_ kind: ListEntry.Kind) -> [ListEntry] {
        ListEntry.list(kind, in: ListEntry.resolve(owned(fetch(FetchDescriptor<ListEntryRecord>())).map(\.value)).winners)
    }

    func isOnMyList(_ titleID: String, source: UUID) -> Bool {
        listRecords(titleID: titleID).contains { $0.sourceID == source && $0.value.isUsable }
    }

    /// Adds a title to My list; a title already there keeps its place.
    func addToMyList(_ titleID: String, source: UUID, now: Date = .now) {
        guard WatchProgress.isStorable(titleID: titleID) else { return }
        let records = listRecords(titleID: titleID).filter { $0.sourceID == source }
        if records.isEmpty {
            context.insert(ListEntryRecord(titleID: titleID, sourceID: source, addedAt: now, profileID: storedProfile))
        }
        ListEntry.resolve(records.map(\.value)).losers.forEach { context.delete(records[$0]) }
        commit()
    }

    /// Removes a title from My list, with every copy another device made.
    func removeFromMyList(_ titleID: String, source: UUID) {
        listRecords(titleID: titleID).filter { $0.sourceID == source }.forEach(context.delete)
        commit()
    }

    // MARK: Recent searches

    /// The ten newest searches, newest first.
    func recentSearches() -> [RecentSearch] {
        RecentSearch.resolve(searchRecords().map(\.value)).winners
    }

    /// Records a search. A blank search is ignored; one that differs from an
    /// earlier search only in case or accents replaces it.
    func recordSearch(_ query: String, now: Date = .now) {
        guard let tidy = RecentSearch.tidy(query) else { return }
        var records = searchRecords()
        let fold = RecentSearch.fold(tidy)
        let same = records.filter { RecentSearch.fold($0.query) == fold }.map(\.updatedAt).max()
        let record = RecentSearchRecord(query: tidy, updatedAt: WatchProgress.stamp(now: now, replacing: same), profileID: storedProfile)
        context.insert(record)
        records.append(record)
        RecentSearch.resolve(records.map(\.value)).losers.forEach { context.delete(records[$0]) }
        commit()
    }

    // MARK: Records

    private var storedProfile: UUID? { ProfileList.storedID(for: profile) }

    private func owned<Record: ProfileOwned>(_ records: [Record]) -> [Record] {
        records.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }
    }

    private func progressRecords(titleID: String? = nil) -> [ProgressRecord] {
        guard let titleID else { return owned(fetch(FetchDescriptor<ProgressRecord>())) }
        return owned(fetch(FetchDescriptor<ProgressRecord>(predicate: #Predicate { $0.titleID == titleID })))
    }

    private func listRecords(titleID: String) -> [ListEntryRecord] {
        owned(fetch(FetchDescriptor<ListEntryRecord>(predicate: #Predicate { $0.titleID == titleID })))
    }

    private func searchRecords() -> [RecentSearchRecord] {
        owned(fetch(FetchDescriptor<RecentSearchRecord>()))
    }

    private func fetch<Record: PersistentModel>(_ descriptor: FetchDescriptor<Record>) -> [Record] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func commit() {
        do {
            try save(context)
        } catch {
            context.rollback()
        }
    }
}

extension ActivityStore {
    /// Removes a deleted source's progress and My list entries for every
    /// profile, keeping recent searches
    /// (watch-progress-sync/deleting-a-source-removes-its-progress-and-list-entries).
    /// The caller saves.
    static func removeSource(_ source: UUID, in context: ModelContext) {
        let progress = (try? context.fetch(FetchDescriptor<ProgressRecord>(predicate: #Predicate { $0.sourceID == source }))) ?? []
        let entries = (try? context.fetch(FetchDescriptor<ListEntryRecord>(predicate: #Predicate { $0.sourceID == source }))) ?? []
        progress.forEach(context.delete)
        entries.forEach(context.delete)
    }

    /// Removes a deleted profile's progress, My list and recent searches. The caller saves.
    static func removeProfile(_ profile: UUID, in context: ModelContext) {
        func remove<Record: ProfileOwned>(_ type: Record.Type) {
            let records = (try? context.fetch(FetchDescriptor<Record>())) ?? []
            records.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }.forEach(context.delete)
        }
        remove(ProgressRecord.self)
        remove(ListEntryRecord.self)
        remove(RecentSearchRecord.self)
    }
}
