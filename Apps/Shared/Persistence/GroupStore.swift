import AntennaCore
import Foundation
import SwiftData

/// Reads and writes the group records (group-management capability).
/// Duplicates by group keep the earliest `createdAt`; the rest are left
/// for the Groups screen to list with Remove. Malformed records are ignored.
@MainActor
enum GroupStore {
    /// The rules the catalogue applies for `profile`, from every record.
    static func rules(
        groups: [GroupRecord], members: [GroupMemberRecord], hidden: [HiddenGroupRecord], profile: UUID, locksOpen: Bool
    ) -> GroupRules {
        var rules = GroupRules(locksOpen: locksOpen)
        let winners = winners(groups)
        let membersByGroup = Dictionary(grouping: members.filter { $0.groupID != nil }, by: \.groupID)
        for record in winners {
            guard let group = record.group else { continue }
            if record.locked { rules.locked.insert(group) }
            if let order = record.sortOrder { rules.order[group] = order }
            if case .own(let id) = group {
                let stored = (membersByGroup[id] ?? []).sorted { ($0.sortOrder, $0.addedAt) < ($1.sortOrder, $1.addedAt) }
                let refs = stored.compactMap { member in
                    member.sourceID.map { GroupRules.Member(channelID: member.channelID, sourceID: $0) }
                }
                rules.ownGroups.append(GroupRules.OwnGroup(id: id, name: record.customName ?? "", members: refs))
            } else if let name = record.customName, !name.allSatisfy(\.isWhitespace) {
                rules.names[group] = name
            }
        }
        for record in hidden where record.hidden && ProfileList.owns(profile, recordProfile: record.profileID) {
            if let group = CatalogueGroup(storageKey: record.groupKey) { rules.hidden.insert(group) }
        }
        return rules
    }

    /// One record per group, the earliest; own groups in creation order.
    static func winners(_ records: [GroupRecord]) -> [GroupRecord] {
        var best: [CatalogueGroup: GroupRecord] = [:]
        var order: [CatalogueGroup] = []
        for record in records.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let group = record.group, best[group] == nil else { continue }
            best[group] = record
            order.append(group)
        }
        return order.compactMap { best[$0] }
    }

    /// Records that lost to an earlier one for the same group.
    static func duplicates(_ records: [GroupRecord]) -> [GroupRecord] {
        let kept = Set(winners(records).map(\.persistentModelID))
        return records.filter { $0.group != nil && !kept.contains($0.persistentModelID) }
    }

    // MARK: Writes

    /// Hides or shows `group` for `profile`.
    static func setHidden(_ group: CatalogueGroup, _ hidden: Bool, profile: UUID, in context: ModelContext) {
        let key = group.storageKey
        let records = fetch(HiddenGroupRecord.self, context).filter {
            $0.groupKey == key && ProfileList.owns(profile, recordProfile: $0.profileID)
        }
        if hidden, records.isEmpty {
            context.insert(HiddenGroupRecord(profileID: profile == Profile.mainID ? nil : profile, group: group))
        } else if !hidden {
            records.forEach(context.delete)
        }
        try? context.save()
    }

    /// Locks or unlocks `group` on every device. All channels, Favorites
    /// and Recents are never locked.
    static func setLocked(_ group: CatalogueGroup, _ locked: Bool, in context: ModelContext) {
        guard group != .all, group != .favorites, group != .recents else { return }
        record(for: group, in: context).locked = locked
        try? context.save()
    }

    /// Gives `group` the user's `name`. An empty name gives a provider
    /// group its provider name back and is refused for an own group
    /// (group-management/give-a-group-your-own-name). Returns false when refused.
    @discardableResult
    static func rename(_ group: CatalogueGroup, to name: String, in context: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .own = group, trimmed.isEmpty { return false }
        guard group != .favorites, group != .recents else { return false }
        record(for: group, in: context).customName = trimmed.isEmpty ? nil : trimmed
        try? context.save()
        return true
    }

    /// Stores `groups` as the user's order, first to last.
    static func reorder(_ groups: [CatalogueGroup], in context: ModelContext) {
        for (place, group) in zip(groups.indices, groups) where group != .all && group != .favorites && group != .recents {
            let record = record(for: group, in: context)
            if record.sortOrder != place { record.sortOrder = place }
        }
        try? context.save()
    }

    /// Makes an own group named `name`, placed after every group, or nil
    /// for an empty name.
    @discardableResult
    static func create(named name: String, after groups: [CatalogueGroup], in context: ModelContext, now: Date = .now) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = UUID()
        let record = GroupRecord(group: .own(id), now: now)
        record.customName = trimmed
        record.sortOrder = groups.count
        context.insert(record)
        try? context.save()
        return id
    }

    /// Deletes own group `id` and its members on every device.
    static func delete(own id: UUID, in context: ModelContext) {
        fetch(GroupRecord.self, context).filter { $0.group == .own(id) }.forEach(context.delete)
        members(of: id, in: context).forEach(context.delete)
        fetch(HiddenGroupRecord.self, context).filter { $0.groupKey == CatalogueGroup.own(id).storageKey }.forEach(context.delete)
        try? context.save()
    }

    /// Stores `channels` as own group `id`'s members in this order. A
    /// channel whose id holds a link is left out (`GroupRules.canSave`).
    static func setMembers(of id: UUID, to channels: [Channel], in context: ModelContext) {
        members(of: id, in: context).forEach(context.delete)
        var order = 0
        for channel in channels {
            guard let source = channel.sourceID, GroupRules.canSave(channelID: channel.id) else { continue }
            context.insert(GroupMemberRecord(groupID: id, channelID: channel.id, sourceID: source, sortOrder: order))
            order += 1
        }
        try? context.save()
    }

    /// Removes every setting stored for `group`: its record, its
    /// duplicates and every profile's hidden flag
    /// (group-management/settings-for-groups-that-are-gone).
    static func remove(_ group: CatalogueGroup, in context: ModelContext) {
        fetch(GroupRecord.self, context).filter { $0.group == group }.forEach(context.delete)
        fetch(HiddenGroupRecord.self, context).filter { $0.groupKey == group.storageKey }.forEach(context.delete)
        if case .own(let id) = group { members(of: id, in: context).forEach(context.delete) }
        try? context.save()
    }

    /// A playlist was deleted: its channels leave the own groups and its
    /// groups' settings go (group-management/build-your-own-group-from-any-playlist).
    /// Saved by the caller.
    static func removeSource(_ id: UUID, in context: ModelContext) {
        fetch(GroupMemberRecord.self, context).filter { $0.sourceID == id }.forEach(context.delete)
        fetch(GroupRecord.self, context).filter { $0.kindRaw != LiveSession.Group.Kind.own.rawValue && $0.sourceID == id }
            .forEach(context.delete)
        let prefixes = ["named.\(id.uuidString).", "ungrouped.\(id.uuidString)"]
        fetch(HiddenGroupRecord.self, context).filter { record in prefixes.contains { record.groupKey.hasPrefix($0) } }
            .forEach(context.delete)
    }

    /// A profile was deleted: its hidden groups go. Saved by the caller.
    static func removeProfile(_ id: UUID, in context: ModelContext) {
        fetch(HiddenGroupRecord.self, context).filter { ProfileList.owns(id, recordProfile: $0.profileID) }.forEach(context.delete)
    }

    // MARK: Helpers

    /// The winning record for `group`, inserted when there is none.
    private static func record(for group: CatalogueGroup, in context: ModelContext) -> GroupRecord {
        if let found = winners(fetch(GroupRecord.self, context)).first(where: { $0.group == group }) { return found }
        let record = GroupRecord(group: group)
        context.insert(record)
        return record
    }

    private static func members(of id: UUID, in context: ModelContext) -> [GroupMemberRecord] {
        fetch(GroupMemberRecord.self, context).filter { $0.groupID == id }
    }

    private static func fetch<Record: PersistentModel>(_ type: Record.Type, _ context: ModelContext) -> [Record] {
        (try? context.fetch(FetchDescriptor<Record>())) ?? []
    }
}
