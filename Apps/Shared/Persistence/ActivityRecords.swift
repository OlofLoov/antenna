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
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var titleID: String = ""
    @Attribute(.allowsCloudEncryption) var seriesID: String?
    @Attribute(.allowsCloudEncryption) var sourceID: UUID?
    /// Seconds from the start.
    @Attribute(.allowsCloudEncryption) var position: Double = 0
    /// Seconds; nil when the player did not know.
    @Attribute(.allowsCloudEncryption) var duration: Double?
    @Attribute(.allowsCloudEncryption) var updatedAt: Date = Date.now
    @Attribute(.allowsCloudEncryption) var profileID: UUID?

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
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var titleID: String = ""
    @Attribute(.allowsCloudEncryption) var sourceID: UUID?
    @Attribute(.allowsCloudEncryption) var addedAt: Date = Date.now
    @Attribute(.allowsCloudEncryption) var profileID: UUID?

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
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var query: String = ""
    @Attribute(.allowsCloudEncryption) var updatedAt: Date = Date.now
    @Attribute(.allowsCloudEncryption) var profileID: UUID?

    init(query: String, updatedAt: Date, profileID: UUID?) {
        self.query = query
        self.updatedAt = updatedAt
        self.profileID = profileID
    }

    var value: RecentSearch {
        RecentSearch(id: id.uuidString, query: query, updatedAt: updatedAt)
    }
}
