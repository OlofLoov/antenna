import Foundation
import SwiftData
import AntennaCore

// CloudKit-synced SwiftData models. Rules that CloudKit imposes:
// every property optional or defaulted, no @Attribute(.unique), relationships optional.
// Credentials are NOT stored here; they go in the Keychain (iCloud Keychain syncs them).

/// Every model the app stores. Every container uses this list, so a screen
/// that queries one model never meets a container without it.
enum AntennaSchema {
    static let models: [any PersistentModel.Type] = [
        SourceRecord.self, FavoriteRecord.self, ProfileRecord.self, ProgressRecord.self, ListEntryRecord.self, RecentSearchRecord.self,
    ]
}

@Model
final class SourceRecord {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = SourceKind.m3u.rawValue
    var url: URL?
    var epgURL: URL?
    var credentialKey: String?
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var lastRefreshedAt: Date?

    init(descriptor: SourceDescriptor, sortOrder: Int = 0) {
        self.id = descriptor.id
        self.name = descriptor.name
        self.kindRaw = descriptor.kind.rawValue
        self.url = descriptor.url
        self.epgURL = descriptor.epgURL
        self.credentialKey = descriptor.credentialKey
        self.sortOrder = sortOrder
    }

    var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .m3u }

    /// The order Settings lists sources in and Channels loads them in.
    static var displayOrder: [SortDescriptor<SourceRecord>] { [SortDescriptor(\.sortOrder)] }

    var descriptor: SourceDescriptor? {
        guard let url else { return nil }
        return SourceDescriptor(id: id, name: name, kind: kind, url: url, epgURL: epgURL, credentialKey: credentialKey)
    }
}

@Model
final class FavoriteRecord {
    var channelID: String = ""
    var sourceID: UUID?
    var addedAt: Date = Date.now
    var sortOrder: Int = 0
    /// The profile the favorite belongs to; nil is the first profile, Main (profiles capability).
    var profileID: UUID?

    init(channelID: String, sourceID: UUID?, sortOrder: Int = 0, profileID: UUID? = nil) {
        self.channelID = channelID
        self.sourceID = sourceID
        self.sortOrder = sortOrder
        self.profileID = profileID
    }
}

/// One person's profile (profiles capability). Main has no record until a second
/// profile is added. Duplicates by `id` keep the earliest `createdAt`.
@Model
final class ProfileRecord {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    init(_ profile: Profile) {
        id = profile.id
        name = profile.name
        colorIndex = profile.colorIndex
        sortOrder = profile.sortOrder
        createdAt = profile.createdAt
    }

    var profile: Profile {
        Profile(id: id, name: name, colorIndex: colorIndex, sortOrder: sortOrder, createdAt: createdAt)
    }
}
