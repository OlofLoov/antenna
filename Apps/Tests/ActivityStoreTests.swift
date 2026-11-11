import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Watch progress, My list and recent searches against an in-memory store
/// with CloudKit off. Copies another device made are inserted as records,
/// as a sync import would.
@MainActor
@Suite struct ActivityStoreTests {
    let container: ModelContainer
    let source = UUID()
    let movie = "xtream#host.tv#vod#55"
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var context: ModelContext { container.mainContext }
    private var store: ActivityStore { ActivityStore(context: context) }

    private func count<Record: PersistentModel>(_ type: Record.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<Record>())
    }

    private func synced(_ title: String? = nil, source: UUID? = nil, at position: Double, saved offset: TimeInterval) {
        context.insert(
            ProgressRecord(
                WatchProgress(
                    id: "", titleID: title ?? movie, sourceID: source ?? self.source, position: position, duration: 100,
                    updatedAt: start.addingTimeInterval(offset)),
                profileID: nil))
        try? context.save()
    }

    // MARK: Progress

    @Test("watch-progress-sync/progress-is-saved-and-read-back the latest position and length come back, one entry per title")
    func saveAndRead() throws {
        store.saveProgress(titleID: movie, source: source, position: 30, duration: 100, now: start)
        store.saveProgress(titleID: movie, source: source, position: 45, duration: 101, now: start.addingTimeInterval(10))
        let read = try #require(store.progress(of: movie, source: source))
        #expect(read.position == 45)
        #expect(read.duration == 101)
        #expect(try count(ProgressRecord.self) == 1)
        #expect(store.progress(of: movie, source: UUID()) == nil, "another source's copy of the title is its own")
    }

    @Test("watch-progress-sync/progress-is-saved-and-read-back no link, username or password is stored")
    func nothingSecret() throws {
        store.saveProgress(titleID: "http://host.tv/movie/user/pass/55.mkv", source: source, position: 30, duration: 100)
        store.saveProgress(titleID: "xtream#user@host.tv#vod#55", source: source, position: 30, duration: 100)
        #expect(try count(ProgressRecord.self) == 0)
        store.addToMyList("http://host.tv/series/1", source: source)
        #expect(try count(ListEntryRecord.self) == 0)
    }

    @Test("watch-progress-sync/progress-is-saved-and-read-back a failed save does not show and raises nothing")
    func failedSave() throws {
        store.saveProgress(titleID: movie, source: source, position: 30, duration: 100, now: start)
        var failing = store
        failing.save = { _ in throw CocoaError(.fileWriteUnknown) }
        failing.saveProgress(titleID: movie, source: source, position: 80, duration: 100, now: start.addingTimeInterval(10))
        failing.addToMyList(movie, source: source)
        failing.recordSearch("dune")
        #expect(store.progress(of: movie, source: source)?.position == 30)
        #expect(!store.isOnMyList(movie, source: source))
        #expect(store.recentSearches().isEmpty)
    }

    @Test("watch-progress-sync/progress-is-saved-and-read-back years of history are kept")
    func oldHistoryStays() {
        store.saveProgress(titleID: movie, source: source, position: 30, duration: 100, now: start.addingTimeInterval(-5 * 365 * 86400))
        store.saveProgress(titleID: "xtream#host.tv#vod#56", source: source, position: 30, duration: 100, now: start)
        #expect(store.allProgress().count == 2)
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer reads settle without writing, a save removes the loser")
    func twoCopies() throws {
        synced(at: 40, saved: 0)
        synced(at: 70, saved: 5)
        #expect(store.progress(of: movie, source: source)?.position == 70)
        #expect(store.allProgress().count == 1)
        #expect(try count(ProgressRecord.self) == 2, "a read never deletes")
        store.saveProgress(titleID: movie, source: source, position: 75, duration: 100, now: start.addingTimeInterval(6))
        #expect(try count(ProgressRecord.self) == 1)
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer a save replaces a copy from a clock that ran ahead")
    func clockAhead() {
        synced(at: 90, saved: 3600)
        store.saveProgress(titleID: movie, source: source, position: 20, duration: 100, now: start)
        #expect(store.progress(of: movie, source: source)?.position == 20)
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer damaged records are ignored and never deleted")
    func damaged() throws {
        synced("", at: 10, saved: 0)
        synced(at: -5, saved: 0)
        context.insert(ListEntryRecord(titleID: "", sourceID: source, addedAt: start, profileID: nil))
        context.insert(RecentSearchRecord(query: "  ", updatedAt: start, profileID: nil))
        try context.save()
        #expect(store.allProgress().isEmpty)
        #expect(store.myList(.movie).isEmpty)
        #expect(store.recentSearches().isEmpty)
        store.saveProgress(titleID: movie, source: source, position: 20, duration: 100)
        store.recordSearch("dune")
        #expect(try count(ProgressRecord.self) == 3)
        #expect(try count(ListEntryRecord.self) == 1)
        #expect(try count(RecentSearchRecord.self) == 2)
    }

    @Test("watch-progress-sync/a-series-shows-progress-for-each-of-its-episodes a series' episodes, most recent first, without the movie")
    func episodes() {
        let series = "xtream#host.tv#series#7"
        store.saveProgress(titleID: movie, source: source, position: 10, duration: 100, now: start)
        store.saveProgress(titleID: "xtream#host.tv#episode#1", seriesID: series, source: source, position: 10, duration: 100, now: start)
        store.saveProgress(
            titleID: "xtream#host.tv#episode#2", seriesID: series, source: source, position: 10, duration: 100,
            now: start.addingTimeInterval(5))
        #expect(store.episodes(of: series).map(\.titleID) == ["xtream#host.tv#episode#2", "xtream#host.tv#episode#1"])
    }

    // MARK: Sources

    @Test("watch-progress-sync/deleting-a-source-removes-its-progress-and-list-entries one source goes, the other and searches stay")
    func deleteSource() throws {
        let other = UUID()
        let record = SourceRecord(
            descriptor: SourceDescriptor(id: source, name: "A", kind: .xtream, url: try #require(URL(string: "http://host.tv"))))
        context.insert(record)
        store.saveProgress(titleID: movie, source: source, position: 10, duration: 100)
        store.saveProgress(titleID: movie, source: other, position: 10, duration: 100)
        store.addToMyList(movie, source: source)
        store.addToMyList(movie, source: other)
        store.recordSearch("dune")

        SourceRecord.delete(record, from: context, credentials: HeldCredentialStore())
        try context.save()

        #expect(store.allProgress().map(\.sourceID) == [other])
        #expect(store.myList(.movie).map(\.sourceID) == [other])
        #expect(store.recentSearches().map(\.query) == ["dune"])
        #expect(store.progress(of: movie, source: UUID()) == nil, "a source added again has a new id and starts fresh")
    }

    @Test("source-management/deleting-a-source-removes-its-watch-history the credential, record, progress and list go, searches stay")
    func deleteSourceWithHistory() throws {
        let credentials = HeldCredentialStore()
        let form = NewSource(kind: .xtream, url: "http://panel.test", username: "u", password: "p")
        let saved = try form.save(into: context, credentials: credentials)
        let key = try #require(saved.credentialKey)
        store.saveProgress(titleID: movie, source: saved.id, position: 10, duration: 100)
        store.addToMyList(movie, source: saved.id)
        store.recordSearch("dune")

        SourceRecord.delete(saved, from: context, credentials: credentials)
        try context.save()

        #expect(try credentials.load(for: key) == nil)
        #expect(try count(SourceRecord.self) == 0)
        #expect(try count(ProgressRecord.self) == 0)
        #expect(try count(ListEntryRecord.self) == 0)
        #expect(try count(RecentSearchRecord.self) == 1)
    }

    @Test("watch-progress-sync/progress-waits-for-a-source-that-has-not-synced-yet records without their source are read and kept")
    func beforeTheSource() throws {
        let unknown = UUID()
        synced(source: unknown, at: 40, saved: 0)
        context.insert(ListEntryRecord(titleID: movie, sourceID: unknown, addedAt: start, profileID: nil))
        try context.save()
        #expect(store.progress(of: movie, source: unknown)?.position == 40)
        #expect(store.isOnMyList(movie, source: unknown))
        store.saveProgress(titleID: "xtream#host.tv#vod#56", source: source, position: 10, duration: 100)
        #expect(try count(ProgressRecord.self) == 2)
        #expect(try count(ListEntryRecord.self) == 1)
    }

    // MARK: My list

    @Test("watch-progress-sync/add-and-remove-from-my-list adding then removing takes every copy away")
    func addAndRemove() throws {
        store.addToMyList(movie, source: source, now: start)
        store.addToMyList(movie, source: source, now: start.addingTimeInterval(5))
        #expect(store.isOnMyList(movie, source: source))
        #expect(try count(ListEntryRecord.self) == 1, "adding twice keeps one")
        context.insert(ListEntryRecord(titleID: movie, sourceID: source, addedAt: start.addingTimeInterval(9), profileID: nil))
        try context.save()
        #expect(store.myList(.movie).count == 1, "a copy from another device reads as one")
        store.removeFromMyList(movie, source: source)
        #expect(!store.isOnMyList(movie, source: source))
        #expect(try count(ListEntryRecord.self) == 0)
    }

    @Test("watch-progress-sync/my-list-shows-movies-and-series-separately movies and series apart, newest first")
    func listByKind() throws {
        store.addToMyList(movie, source: source, now: start)
        store.addToMyList("xtream#host.tv#series#7", source: source, now: start.addingTimeInterval(1))
        store.addToMyList("xtream#host.tv#vod#56", source: source, now: start.addingTimeInterval(2))
        store.addToMyList("xtream#host.tv#9", source: source, now: start.addingTimeInterval(3))
        #expect(store.myList(.movie).map(\.titleID) == ["xtream#host.tv#vod#56", movie])
        #expect(store.myList(.series).map(\.titleID) == ["xtream#host.tv#series#7"])
        #expect(try count(ListEntryRecord.self) == 4, "the live channel entry is kept")
    }

    // MARK: Searches

    @Test("watch-progress-sync/recent-searches-stay-short-and-tidy newest first, one per spelling, ten at most")
    func searches() throws {
        store.recordSearch("   ", now: start)
        #expect(store.recentSearches().isEmpty)
        for index in 0..<12 { store.recordSearch("query \(index)", now: start.addingTimeInterval(Double(index))) }
        store.recordSearch("QUERY 11", now: start.addingTimeInterval(20))
        store.recordSearch("Amélie  " + String(repeating: "x", count: 200), now: start.addingTimeInterval(30))
        let recent = store.recentSearches()
        #expect(recent.count == 10)
        #expect(recent.first?.query.count == 100)
        #expect(recent.dropFirst().first?.query == "QUERY 11", "the latest spelling")
        #expect(try count(RecentSearchRecord.self) == 10, "older searches are deleted on save")
    }

    @Test("watch-progress-sync/recent-searches-from-an-earlier-build-carry-over old searches join the synced list once")
    func carryOver() throws {
        let defaults = try #require(UserDefaults(suiteName: "activity-\(UUID().uuidString)"))
        defaults.set(["newest", "Older", "oldest"], forKey: ActivityStore.carriedOverKey)
        context.insert(RecentSearchRecord(query: "older", updatedAt: start.addingTimeInterval(-100), profileID: nil))
        context.insert(RecentSearchRecord(query: "from the iPad", updatedAt: start.addingTimeInterval(-50), profileID: nil))
        try context.save()

        ActivityStore.carryOverSearches(from: defaults, into: context, now: start)
        #expect(store.recentSearches().map(\.query) == ["newest", "Older", "oldest", "from the iPad"])
        #expect(defaults.object(forKey: ActivityStore.carriedOverKey) == nil)

        defaults.set(["newest", "Older", "oldest"], forKey: ActivityStore.carriedOverKey)
        ActivityStore.carryOverSearches(from: defaults, into: context, now: start.addingTimeInterval(1))
        #expect(store.recentSearches().count == 4, "a run after a kill before the key went adds nothing twice")
        #expect(try count(RecentSearchRecord.self) == 4)
    }

    // MARK: Changes and profiles

    @Test("watch-progress-sync/changes-from-another-device-show-up-without-reopening-the-screen every watcher hears about a save")
    func changes() async throws {
        let first = ActivityStore.changes(in: container)
        let second = ActivityStore.changes(in: container)
        async let heardFirst: Void? = first.first { _ in true }
        async let heardSecond: Void? = second.first { _ in true }
        try await Task.sleep(for: .milliseconds(50))
        store.saveProgress(titleID: movie, source: source, position: 10, duration: 100)
        #expect(await heardFirst != nil)
        #expect(await heardSecond != nil)
    }

    @Test("watch-progress-sync/progress-follows-the-icloud-account each profile has its own progress, list and searches")
    func perProfile() throws {
        let kids = UUID()
        let kidsStore = ActivityStore(context: context, profile: kids)
        store.saveProgress(titleID: movie, source: source, position: 10, duration: 100)
        kidsStore.saveProgress(titleID: movie, source: source, position: 60, duration: 100)
        kidsStore.addToMyList(movie, source: source)
        kidsStore.recordSearch("cartoons")
        #expect(store.progress(of: movie, source: source)?.position == 10)
        #expect(kidsStore.progress(of: movie, source: source)?.position == 60)
        #expect(!store.isOnMyList(movie, source: source))
        #expect(store.recentSearches().isEmpty)

        ActivityStore.removeProfile(kids, in: context)
        try context.save()
        #expect(kidsStore.allProgress().isEmpty)
        #expect(store.allProgress().count == 1, "Main keeps its own")
        #expect(try count(ListEntryRecord.self) == 0)
        #expect(try count(RecentSearchRecord.self) == 0)
    }
}
