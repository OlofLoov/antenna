import Foundation

/// Rows listed in order, with each entry's 0-based place among them.
struct RankedRows: Sendable {
    let rows: [RowKey]
    let rankByEntry: [Int: Int]

    static let empty = RankedRows(rows: [], rankByEntry: [:])
}

/// The group rules applied to one catalogue index: which entries are
/// hidden or out of reach, the group list in the user's order, and the
/// rows of All channels, the provider groups and the user's own groups
/// once rules apply. Built once per index and rules, so favorites and
/// recents can be swapped without building it again.
struct CataloguePolicy: Sendable {
    let rules: GroupRules
    /// Per entry: true when a lock that applies now covers it.
    let blocked: [Bool]
    /// Provider groups and own groups in the user's order, hidden and locked ones included.
    let ordered: [CatalogueGroup]
    let allRows: [RowKey]
    /// Per entry: its index in `allRows`, or -1 when left out.
    let allRank: [Int]
    let sortedNumbers: [Int]
    /// Provider group rows with blocked entries left out; nil when nothing
    /// outside a locked group is blocked, so the index's rows hold.
    let rowsByGroup: [CatalogueGroup: [RowKey]]?
    /// Per entry: its index in its group's rows when `rowsByGroup` is set.
    let groupRank: [Int]
    /// Own groups' resolved rows before locks apply, and their names.
    let ownRows: [UUID: [Int]]
    let ownNames: [UUID: String]

    init(index: CatalogueIndex, rules: GroupRules) {
        self.rules = rules
        let count = index.channels.count
        let locks = rules.effectiveLocks
        let hiddenGroups = rules.hidden

        var ownRows: [UUID: [Int]] = [:]
        var ownNames: [UUID: String] = [:]
        for group in rules.ownGroups where ownRows[group.id] == nil {
            var seen: Set<Int> = []
            var entries: [Int] = []
            for member in group.members {
                let match = (index.indicesByID[member.channelID] ?? [])
                    .filter { index.keys[$0].sourceID == member.sourceID }
                    .min { index.allRank[$0] < index.allRank[$1] }
                if let match, seen.insert(match).inserted { entries.append(match) }
            }
            ownRows[group.id] = entries
            ownNames[group.id] = group.name
        }

        var blocked = [Bool](repeating: false, count: count)
        var hidden = [Bool](repeating: false, count: count)
        if !locks.isEmpty || !hiddenGroups.isEmpty {
            for entry in 0..<count {
                let group = index.entryGroup[entry]
                if locks.contains(group) { blocked[entry] = true }
                if hiddenGroups.contains(group) { hidden[entry] = true }
            }
        }
        var blockedOutsideLockedGroups = false
        for case .own(let id) in locks {
            for entry in ownRows[id] ?? [] where !blocked[entry] {
                blocked[entry] = true
                blockedOutsideLockedGroups = true
            }
        }

        let allOrder = Self.allOrder(index)
        var allRows: [RowKey] = []
        var sortedNumbers: [Int] = []
        var allRank = [Int](repeating: -1, count: count)
        allRows.reserveCapacity(count)
        sortedNumbers.reserveCapacity(count)
        for entry in allOrder where !blocked[entry] && !hidden[entry] {
            allRank[entry] = allRows.count
            allRows.append(index.keys[entry])
            sortedNumbers.append(index.numbers[entry])
        }

        var rowsByGroup: [CatalogueGroup: [RowKey]]?
        var groupRank = [Int](repeating: -1, count: count)
        if blockedOutsideLockedGroups {
            var rows: [CatalogueGroup: [RowKey]] = [:]
            for entry in allOrder where !blocked[entry] {
                let group = index.entryGroup[entry]
                groupRank[entry] = rows[group, default: []].count
                rows[group, default: []].append(index.keys[entry])
            }
            rowsByGroup = rows
        }

        let usual = index.groups + rules.ownGroups.map(\.id).uniqued().map(CatalogueGroup.own)
        let place = Dictionary(uniqueKeysWithValues: zip(usual, usual.indices))
        self.ordered = usual.sorted { lhs, rhs in
            let left = rules.order[lhs]
            let right = rules.order[rhs]
            switch (left, right) {
            case let (.some(left), .some(right)) where left != right: return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            default: return (place[lhs] ?? 0) < (place[rhs] ?? 0)
            }
        }
        self.blocked = blocked
        self.allRows = allRows
        self.allRank = allRank
        self.sortedNumbers = sortedNumbers
        self.rowsByGroup = rowsByGroup
        self.groupRank = groupRank
        self.ownRows = ownRows
        self.ownNames = ownNames
    }

    /// Entries in All channels order.
    private static func allOrder(_ index: CatalogueIndex) -> [Int] {
        var order = [Int](repeating: 0, count: index.channels.count)
        for entry in index.allRank.indices { order[index.allRank[entry]] = entry }
        return order
    }

    func isHidden(_ group: CatalogueGroup) -> Bool {
        rules.hidden.contains(group) && group != .favorites && group != .recents && group != .new
    }

    func isLocked(_ group: CatalogueGroup) -> Bool {
        rules.effectiveLocks.contains(group)
    }

    /// `ranked` with blocked entries left out.
    func filter(_ ranked: RankedRows, index: CatalogueIndex) -> RankedRows {
        let entries = ranked.rankByEntry.sorted { $0.value < $1.value }.map(\.key)
        guard entries.contains(where: { blocked[$0] }) else { return ranked }
        let kept = entries.filter { !blocked[$0] }
        return RankedRows(
            rows: kept.map { index.keys[$0] }, rankByEntry: Dictionary(uniqueKeysWithValues: zip(kept, kept.indices)))
    }

    /// The own group's rows with blocked entries left out.
    func ownRanked(_ id: UUID, index: CatalogueIndex) -> RankedRows {
        let kept = (ownRows[id] ?? []).filter { !blocked[$0] }
        return RankedRows(
            rows: kept.map { index.keys[$0] }, rankByEntry: Dictionary(uniqueKeysWithValues: zip(kept, kept.indices)))
    }
}

extension Array where Element: Hashable {
    /// The elements in order, each kept at its first position.
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
