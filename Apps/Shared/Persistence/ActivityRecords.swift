import AntennaCore
import Foundation
import SwiftData

// Watch history records (watch-progress-sync), synced through CloudKit like
// the others: every property defaulted or optional, no unique attribute, no
// relationship, no URL. Title ids carry the server host only. A nil
// `profileID` belongs to the first profile, Main.

/// A record kept per profile; nil is Main.
protocol ProfileOwned: PersistentModel {
    var profileID: UUID? { get }
}

extension ProgressRecord: ProfileOwned {}
extension ListEntryRecord: ProfileOwned {}
extension RecentSearchRecord: ProfileOwned {}

/// How far into a movie or episode one profile got.
@Model
final class ProgressRecord {
    var id: UUID = UUID()
    var titleID: String = ""
    var seriesID: String?
    var sourceID: UUID?
    /// Seconds from the start.
    var position: Double = 0
    /// Seconds; nil when the player did not know.
    var duration: Double?
    var updatedAt: Date = Date.now
    var profileID: UUID?

    init(_ value: WatchProgress, profileID: UUID?) {
        titleID = value.titleID
        seriesID = value.seriesID
        sourceID = value.sourceID
        position = value.position
        duration = value.duration
        updatedAt = value.updatedAt
        self.profileID = profileID
    }

    var value: WatchProgress {
        WatchProgress(
            id: id.uuidString, titleID: titleID, seriesID: seriesID, sourceID: sourceID, position: position, duration: duration,
            updatedAt: updatedAt)
    }
}

/// A movie or series on one profile's My list.
@Model
final class ListEntryRecord {
    var id: UUID = UUID()
    var titleID: String = ""
    var sourceID: UUID?
    var addedAt: Date = Date.now
    var profileID: UUID?

    init(titleID: String, sourceID: UUID?, addedAt: Date, profileID: UUID?) {
        self.titleID = titleID
        self.sourceID = sourceID
        self.addedAt = addedAt
        self.profileID = profileID
    }

    var value: ListEntry {
        ListEntry(id: id.uuidString, titleID: titleID, sourceID: sourceID, addedAt: addedAt)
    }
}

/// One of a profile's recent searches.
@Model
final class RecentSearchRecord {
    var id: UUID = UUID()
    var query: String = ""
    var updatedAt: Date = Date.now
    var profileID: UUID?

    init(query: String, updatedAt: Date, profileID: UUID?) {
        self.query = query
        self.updatedAt = updatedAt
        self.profileID = profileID
    }

    var value: RecentSearch {
        RecentSearch(id: id.uuidString, query: query, updatedAt: updatedAt)
    }
}
