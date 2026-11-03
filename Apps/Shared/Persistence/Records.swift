import Foundation
import SwiftData
import AntennaCore

// CloudKit-synced SwiftData models. Rules that CloudKit imposes:
// every property optional or defaulted, no @Attribute(.unique), relationships optional.
// Credentials are NOT stored here; they go in the Keychain (iCloud Keychain syncs them).

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

    init(channelID: String, sourceID: UUID?, sortOrder: Int = 0) {
        self.channelID = channelID
        self.sourceID = sourceID
        self.sortOrder = sortOrder
    }
}
