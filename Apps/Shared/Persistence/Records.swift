import Foundation
import SwiftData
import AntennaCore

// CloudKit-synced SwiftData models. Rules that CloudKit imposes:
// every property optional or defaulted, no @Attribute(.unique), relationships optional.
// Every stored property is marked .allowsCloudEncryption, so CloudKit keeps it in an
// encrypted field (source-management/the-synced-library-is-in-encrypted-fields).
// Credentials are NOT stored here; they go in the Keychain (iCloud Keychain syncs them).

/// Every model the app stores. Every container uses this list, so a screen
/// that queries one model never meets a container without it.
enum AntennaSchema {
    static let models: [any PersistentModel.Type] = [
        SourceRecord.self, FavoriteRecord.self, ProfileRecord.self, ProgressRecord.self, ListEntryRecord.self, RecentSearchRecord.self,
        PreferencesRecord.self, GroupRecord.self, GroupMemberRecord.self, HiddenGroupRecord.self, PasscodeRecord.self, ReminderRecord.self,
        GuideSettingsRecord.self,
    ]
}

@Model
final class SourceRecord {
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var name: String = ""
    @Attribute(.allowsCloudEncryption) var kindRaw: String = SourceKind.m3u.rawValue
    @Attribute(.allowsCloudEncryption) var url: URL?
    @Attribute(.allowsCloudEncryption) var epgURL: URL?
    @Attribute(.allowsCloudEncryption) var credentialKey: String?
    @Attribute(.allowsCloudEncryption) var sortOrder: Int = 0
    @Attribute(.allowsCloudEncryption) var createdAt: Date = Date.now
    @Attribute(.allowsCloudEncryption) var lastRefreshedAt: Date?
    /// An imported file's text as UTF-8, with the logins in its links
    /// replaced by placeholders. Synced as a CloudKit asset; nil on another
    /// device until it arrives (local-m3u-file-import capability).
    @Attribute(.externalStorage, .allowsCloudEncryption) var playlistData: Data?
    /// The imported file's name, such as "home-playlist.m3u".
    @Attribute(.allowsCloudEncryption) var fileName: String?
    @Attribute(.allowsCloudEncryption) var importedAt: Date?
    /// The value inside this list's login placeholders, kept across re-imports.
    @Attribute(.allowsCloudEncryption) var playlistToken: String?
    /// The User-Agent the source's requests carry; nil for the default
    /// (sources-and-settings/a-user-agent-per-source).
    @Attribute(.allowsCloudEncryption) var userAgent: String?

    init(descriptor: SourceDescriptor, sortOrder: Int = 0) {
        self.id = descriptor.id
        self.name = descriptor.name
        self.kindRaw = descriptor.kind.rawValue
        self.url = descriptor.url
        self.epgURL = descriptor.epgURL
        self.credentialKey = descriptor.credentialKey
        self.userAgent = descriptor.userAgent
        self.sortOrder = sortOrder
    }

    var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .m3u }

    /// The order Settings lists sources in and Channels loads them in.
    static var displayOrder: [SortDescriptor<SourceRecord>] { [SortDescriptor(\.sortOrder)] }

    /// Nil for a link source whose link has not synced. A file source has
    /// no link and gets a stand-in that changes with each import.
    var descriptor: SourceDescriptor? {
        guard let url = url ?? (kind == .m3uFile ? PlaylistFileStore.standIn(id: id, importedAt: importedAt) : nil) else { return nil }
        return SourceDescriptor(
            id: id, name: name, kind: kind, url: url, epgURL: epgURL, credentialKey: credentialKey, userAgent: userAgent)
    }
}

@Model
final class FavoriteRecord {
    @Attribute(.allowsCloudEncryption) var channelID: String = ""
    @Attribute(.allowsCloudEncryption) var sourceID: UUID?
    @Attribute(.allowsCloudEncryption) var addedAt: Date = Date.now
    @Attribute(.allowsCloudEncryption) var sortOrder: Int = 0
    /// The profile the favorite belongs to; nil is the first profile, Main (profiles capability).
    @Attribute(.allowsCloudEncryption) var profileID: UUID?

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
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var name: String = ""
    @Attribute(.allowsCloudEncryption) var colorIndex: Int = 0
    @Attribute(.allowsCloudEncryption) var sortOrder: Int = 0
    @Attribute(.allowsCloudEncryption) var createdAt: Date = Date.now
    /// adult-content/show-adult-content-with-the-passcode
    @Attribute(.allowsCloudEncryption) var showsAdult: Bool = false
    /// `ProfileAccent.rawValue`; nil and unknown values read as Blue.
    @Attribute(.allowsCloudEncryption) var accent: String?

    init(_ profile: Profile) {
        showsAdult = profile.showsAdult
        id = profile.id
        name = profile.name
        colorIndex = profile.colorIndex
        sortOrder = profile.sortOrder
        createdAt = profile.createdAt
        accent = profile.accent == .blue ? nil : profile.accent.rawValue
    }

    var profile: Profile {
        Profile(
            id: id, name: name, colorIndex: colorIndex, sortOrder: sortOrder, createdAt: createdAt,
            showsAdult: showsAdult, accent: ProfileAccent(stored: accent))
    }
}
