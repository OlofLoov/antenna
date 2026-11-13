import Foundation

/// What the Groups screen and the channel lists ask about group rules.
extension Catalogue {
    /// The rules this catalogue applies; empty rules when it has none.
    public var rules: GroupRules { policy?.rules ?? GroupRules() }

    /// The name the user gave `group`: the custom name of a provider group,
    /// or an own group's name. Nil when the group keeps the name the app or
    /// the provider gives it.
    public func customName(of group: CatalogueGroup) -> String? {
        guard let policy else { return nil }
        if case .own(let id) = group { return policy.ownNames[id] }
        guard let name = policy.rules.names[group], !name.allSatisfy(\.isWhitespace) else { return nil }
        return name
    }

    /// True when `group` is locked and the locks are closed on this device.
    public func isLocked(_ group: CatalogueGroup) -> Bool {
        policy?.isLocked(group) ?? false
    }

    /// True when the user hid `group`. Favorites and Recents are never hidden.
    public func isHidden(_ group: CatalogueGroup) -> Bool {
        policy?.isHidden(group) ?? false
    }

    /// True when `key`'s channel is locked and the locks are closed, so it
    /// may not be shown or played (group-management/locked-channels-stay-out-of-reach).
    public func isLocked(_ key: RowKey) -> Bool {
        guard let policy, let entry = index.entry(for: key) else { return false }
        return policy.blocked[entry]
    }

    /// Locked groups the channel lists show with a lock while the locks
    /// are closed, in the user's order. Hidden groups are not among them.
    public var lockedGroups: [CatalogueGroup] {
        guard let policy else { return [] }
        return policy.ordered.filter { policy.isLocked($0) && !policy.isHidden($0) }
    }

    /// Every group the Groups screen lists: `.all`, then the source groups
    /// and own groups in the user's order, hidden and locked ones included.
    public var managedGroups: [CatalogueGroup] {
        [.all] + (policy?.ordered ?? index.groups)
    }

    /// How many channels `group` holds with no rule applied: the loaded
    /// members of an own group, every channel for `.all`.
    public func memberCount(of group: CatalogueGroup) -> Int {
        switch group {
        case .all: index.allRows.count
        case .named, .ungrouped: index.rowsByGroup[group]?.count ?? 0
        case .own(let id): policy?.ownRows[id]?.count ?? 0
        case .favorites, .recents, .new: rows(in: group).count
        }
    }

    /// The members of own group `id` that are loaded, in the user's order,
    /// whether or not they are locked.
    public func members(of id: UUID) -> [RowKey] {
        (policy?.ownRows[id] ?? []).map { index.keys[$0] }
    }

    /// Provider groups the rules name that no loaded source lists any more
    /// (group-management/settings-for-groups-that-are-gone). A rule for a
    /// source with no loaded channels, still loading, failed or waiting for
    /// its login, is not among them. Sorted by source order, then name.
    public var orphanedGroups: [CatalogueGroup] {
        guard let policy else { return [] }
        let rules = policy.rules
        let present = Set(index.groups)
        var sourceRank: [UUID: Int] = [:]
        for key in index.keys where sourceRank[key.sourceID] == nil { sourceRank[key.sourceID] = sourceRank.count }
        let named = rules.hidden.union(rules.locked).union(rules.names.keys).union(rules.order.keys)
        let orphans = named.filter { group in
            switch group {
            case .named(let source, _), .ungrouped(let source):
                sourceRank[source] != nil && !present.contains(group)
            case .favorites, .recents, .new, .all, .own: false
            }
        }
        return orphans.sorted { lhs, rhs in
            let left = (sourceRank[lhs.source ?? UUID()] ?? 0, lhs.providerName ?? "")
            let right = (sourceRank[rhs.source ?? UUID()] ?? 0, rhs.providerName ?? "")
            return left < right
        }
    }

    /// The group to show when the one being watched is hidden, locked or
    /// deleted: the first group listed after Favorites, Recents and New,
    /// else Favorites. Never a group that needs the passcode.
    public var fallbackGroup: CatalogueGroup {
        groups.first { $0 != .favorites && $0 != .recents && $0 != .new } ?? .favorites
    }

    /// The rows search looks through: All channels, plus the channels of
    /// hidden groups when `includingHidden` is set. Locked channels are
    /// left out while the locks are closed.
    public func searchRows(includingHidden: Bool) -> [RowKey] {
        guard includingHidden, let policy, !policy.rules.hidden.isEmpty else { return rows(in: .all) }
        var rows: [RowKey] = []
        rows.reserveCapacity(index.allRows.count)
        for key in index.allRows {
            guard let entry = index.entry(for: key), !policy.blocked[entry] else { continue }
            rows.append(key)
        }
        return rows
    }
}

extension CatalogueGroup {
    /// The source a provider group belongs to.
    var source: UUID? {
        switch self {
        case .named(let source, _), .ungrouped(let source): source
        case .favorites, .recents, .new, .all, .own: nil
        }
    }

    /// The provider's name for a named group.
    var providerName: String? {
        if case .named(_, let name) = self { return name }
        return nil
    }

    /// A string that names the group in stored records and accessibility
    /// identifiers: `all`, `new`, `named.<source>.<name>`, `ungrouped.<source>`,
    /// `own.<id>`. It never holds a channel id, so never a stream link.
    public var storageKey: String {
        switch self {
        case .favorites: "favorites"
        case .recents: "recents"
        case .new: "new"
        case .all: "all"
        case .named(let source, let name): "named.\(source.uuidString).\(name)"
        case .ungrouped(let source): "ungrouped.\(source.uuidString)"
        case .own(let id): "own.\(id.uuidString)"
        }
    }

    /// The group `storageKey` names; nil for a key it cannot read.
    public init?(storageKey: String) {
        let parts = storageKey.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        let id = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        switch (parts[0], parts.count, id) {
        case ("favorites", 1, _): self = .favorites
        case ("recents", 1, _): self = .recents
        case ("new", 1, _): self = .new
        case ("all", 1, _): self = .all
        case ("named", 3, .some(let id)): self = .named(id, parts[2])
        case ("ungrouped", 2, .some(let id)): self = .ungrouped(id)
        case ("own", 2, .some(let id)): self = .own(id)
        default: return nil
        }
    }
}
