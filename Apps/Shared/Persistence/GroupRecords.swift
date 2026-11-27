import AntennaCore
import Foundation
import SwiftData

/// The user's settings for one group, shared by every profile
/// (group-management capability): a provider group's custom name, lock and
/// place, or one of the user's own groups. Every field is defaulted and
/// nothing is unique; duplicates by group keep the earliest `createdAt`.
@Model
final class GroupRecord {
    /// For an own group, the group's id; otherwise a fresh id per record.
    @Attribute(.allowsCloudEncryption) var id: UUID = UUID()
    /// `LiveSession.Group.Kind` raw value: all, named, ungrouped or own.
    @Attribute(.allowsCloudEncryption) var kindRaw: String = ""
    @Attribute(.allowsCloudEncryption) var sourceID: UUID?
    /// The provider's category name for a named group.
    @Attribute(.allowsCloudEncryption) var providerName: String?
    /// The user's name; required for an own group, optional otherwise.
    @Attribute(.allowsCloudEncryption) var customName: String?
    @Attribute(.allowsCloudEncryption) var locked: Bool = false
    /// The user's mark: true for adult, false for not adult, nil to follow
    /// the name rules and the provider's flag (adult-content/correct-a-group).
    @Attribute(.allowsCloudEncryption) var adult: Bool?
    /// The group's place in the user's order; nil keeps the usual place.
    @Attribute(.allowsCloudEncryption) var sortOrder: Int?
    @Attribute(.allowsCloudEncryption) var createdAt: Date = Date.now

    init(group: CatalogueGroup, now: Date = .now) {
        let stored = LiveSession.Group(group)
        if case .own(let id) = group { self.id = id }
        kindRaw = stored.kind.rawValue
        sourceID = group == .all ? nil : stored.sourceID
        providerName = stored.name
        createdAt = now
    }

    /// The group this record is about; nil for a malformed record.
    var group: CatalogueGroup? {
        guard let kind = LiveSession.Group.Kind(rawValue: kindRaw) else { return nil }
        var stored = LiveSession.Group(.all)
        stored.kind = kind
        stored.sourceID = kind == .own ? id : sourceID
        stored.name = providerName
        switch kind {
        case .favorites, .recents, .new: return nil
        case .all, .named, .ungrouped, .own: return stored.group
        }
    }
}

/// A channel in one of the user's own groups, shaped like `FavoriteRecord`.
@Model
final class GroupMemberRecord {
    @Attribute(.allowsCloudEncryption) var groupID: UUID?
    @Attribute(.allowsCloudEncryption) var channelID: String = ""
    @Attribute(.allowsCloudEncryption) var sourceID: UUID?
    @Attribute(.allowsCloudEncryption) var sortOrder: Int = 0
    @Attribute(.allowsCloudEncryption) var addedAt: Date = Date.now

    init(groupID: UUID, channelID: String, sourceID: UUID, sortOrder: Int) {
        self.groupID = groupID
        self.channelID = channelID
        self.sourceID = sourceID
        self.sortOrder = sortOrder
    }
}

/// A group one profile hid (profiles/what-each-profile-keeps). A nil
/// `profileID` is the first profile, Main.
@Model
final class HiddenGroupRecord {
    @Attribute(.allowsCloudEncryption) var profileID: UUID?
    /// `CatalogueGroup.storageKey` of the hidden group.
    @Attribute(.allowsCloudEncryption) var groupKey: String = ""
    @Attribute(.allowsCloudEncryption) var hidden: Bool = true
    @Attribute(.allowsCloudEncryption) var createdAt: Date = Date.now

    init(profileID: UUID?, group: CatalogueGroup) {
        self.profileID = profileID
        self.groupKey = group.storageKey
    }
}
