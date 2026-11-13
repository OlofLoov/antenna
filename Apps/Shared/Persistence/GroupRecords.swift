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
    var id: UUID = UUID()
    /// `LiveSession.Group.Kind` raw value: all, named, ungrouped or own.
    var kindRaw: String = ""
    var sourceID: UUID?
    /// The provider's category name for a named group.
    var providerName: String?
    /// The user's name; required for an own group, optional otherwise.
    var customName: String?
    var locked: Bool = false
    /// The group's place in the user's order; nil keeps the usual place.
    var sortOrder: Int?
    var createdAt: Date = Date.now

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
    var groupID: UUID?
    var channelID: String = ""
    var sourceID: UUID?
    var sortOrder: Int = 0
    var addedAt: Date = Date.now

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
    var profileID: UUID?
    /// `CatalogueGroup.storageKey` of the hidden group.
    var groupKey: String = ""
    var hidden: Bool = true
    var createdAt: Date = Date.now

    init(profileID: UUID?, group: CatalogueGroup) {
        self.profileID = profileID
        self.groupKey = group.storageKey
    }
}
