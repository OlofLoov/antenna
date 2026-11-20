import Foundation

/// Rows listed in order, with each entry's 0-based place among them.
struct RankedRows: Sendable {
    let rows: [RowKey]
    let rankByEntry: [Int: Int]

    static let empty = RankedRows(rows: [], rankByEntry: [:])
}

/// The adult groups and entries of one index, before the profile's switch applies.
struct AdultScan {
    let groups: Set<CatalogueGroup>
    /// Per entry, or empty when `any` is false.
    let entries: [Bool]
    /// True when any group or entry is adult.
    let any: Bool
}

/// The group rules applied to one catalogue index: which entries are
/// hidden or out of reach, the group list in the user's order, and the
/// rows of All channels, the provider groups and the user's own groups
/// once rules apply. Built once per index and rules, so favorites and
/// recents can be swapped without building it again.
struct CataloguePolicy: Sendable {
    let rules: GroupRules
    /// Per entry: true when a lock that applies now covers it, or it is
    /// adult content the profile hides.
    let blocked: [Bool]
    /// Per entry: true when it is adult content the profile hides.
    let adultHidden: [Bool]
    /// Provider groups and own groups that hold adult content, by the
    /// provider, the name or the user's mark, whether or not the profile
    /// shows them (adult-content/correct-a-group).
    let adultGroups: Set<CatalogueGroup>
    /// Provider groups and own groups in the user's order, hidden and locked ones included.
    let ordered: [CatalogueGroup]
    let allRows: [RowKey]
    /// Per entry: its index in `allRows`, or -1 when left out.
    let allRank: [Int]
    let sortedNumbers: [Int]
    /// Provider group rows with blocked entries left out; nil when nothing
    /// outside a locked or hidden adult group is blocked, so the index's rows hold.
    let rowsByGroup: [CatalogueGroup: [RowKey]]?
    /// Per entry: its index in its group's rows when `rowsByGroup` is set.
    let groupRank: [Int]
    /// Own groups' resolved rows before locks apply, and their names.
    let ownRows: [UUID: [Int]]
    let ownNames: [UUID: String]
    /// The locks that apply now, read once: every row and count query asks.
    let locks: Set<CatalogueGroup>

    init(index: CatalogueIndex, rules: GroupRules) {
        self.rules = rules
        let count = index.channels.count
        let locks = rules.effectiveLocks
        self.locks = locks
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

        let adult = Self.adult(index: index, rules: rules, ownRows: ownRows)
        let adultGroups = adult.groups
        let hidesAdult = !rules.showsAdult && adult.any
        var blocked = [Bool](repeating: false, count: count)
        var hidden = [Bool](repeating: false, count: count)
        var adultHidden = [Bool](repeating: false, count: count)
        if !locks.isEmpty || !hiddenGroups.isEmpty || hidesAdult {
            for entry in 0..<count {
                let group = index.entryGroup[entry]
                if locks.contains(group) { blocked[entry] = true }
                if hiddenGroups.contains(group) { hidden[entry] = true }
                if hidesAdult && adult.entries[entry] {
                    blocked[entry] = true
                    adultHidden[entry] = true
                }
            }
        }
        for case .own(let id) in locks {
            for entry in ownRows[id] ?? [] { blocked[entry] = true }
        }
        let shutGroups = hidesAdult ? locks.union(adultGroups) : locks
        let blockedOutsideShutGroups = (0..<count).contains { blocked[$0] && !shutGroups.contains(index.entryGroup[$0]) }

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
        if blockedOutsideShutGroups {
            var rows: [CatalogueGroup: [RowKey]] = [:]
            for entry in allOrder where !blocked[entry] {
                let group = index.entryGroup[entry]
                groupRank[entry] = rows[group, default: []].count
                rows[group, default: []].append(index.keys[entry])
            }
            rowsByGroup = rows
        }

        self.ordered = Self.ordered(index: index, rules: rules)
        self.blocked = blocked
        self.adultHidden = adultHidden
        self.adultGroups = adultGroups
        self.allRows = allRows
        self.allRank = allRank
        self.sortedNumbers = sortedNumbers
        self.rowsByGroup = rowsByGroup
        self.groupRank = groupRank
        self.ownRows = ownRows
        self.ownNames = ownNames
    }

    /// Provider groups and own groups in the user's order.
    private static func ordered(index: CatalogueIndex, rules: GroupRules) -> [CatalogueGroup] {
        let usual = index.groups + rules.ownGroups.map(\.id).uniqued().map(CatalogueGroup.own)
        let place = Dictionary(uniqueKeysWithValues: zip(usual, usual.indices))
        return usual.sorted { lhs, rhs in
            let left = rules.order[lhs]
            let right = rules.order[rhs]
            switch (left, right) {
            case let (.some(left), .some(right)) where left != right: return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            default: return (place[lhs] ?? 0) < (place[rhs] ?? 0)
            }
        }
    }

    /// Which groups and entries hold adult content
    /// (adult-content/adult-groups-are-found-by-name, adult-content/correct-a-group).
    ///
    /// A provider group is adult when the user marked it so, or, with no
    /// mark, when its name is adult or the provider flags every one of its
    /// channels. A channel is adult when its group is, when the user marked
    /// an own group holding it adult, or when the provider flags it and the
    /// user did not clear its group. An own group is adult only when marked.
    private static func adult(
        index: CatalogueIndex, rules: GroupRules, ownRows: [UUID: [Int]]
    ) -> AdultScan {
        let marks = rules.adultMarks
        guard index.hasAdult || marks.values.contains(true) else {
            return AdultScan(groups: [], entries: [], any: false)
        }
        let count = index.channels.count
        var entries = [Bool](repeating: false, count: count)
        var groups: Set<CatalogueGroup> = []
        var flaggedOnly: [CatalogueGroup: Bool] = [:]
        for entry in 0..<count {
            let group = index.entryGroup[entry]
            let mark = marks[group]
            let named = index.adultNamed.contains(group)
            let flagged = index.channels[entry].isAdult
            entries[entry] = mark ?? (named || flagged)
            if mark == nil, !named { flaggedOnly[group] = (flaggedOnly[group] ?? true) && flagged }
        }
        for group in index.groups {
            let found = index.adultNamed.contains(group) || flaggedOnly[group] == true
            if marks[group] ?? found { groups.insert(group) }
        }
        for (group, mark) in marks where mark {
            guard case .own(let id) = group, ownRows[id] != nil else { continue }
            groups.insert(group)
            for entry in ownRows[id] ?? [] { entries[entry] = true }
        }
        return AdultScan(groups: groups, entries: entries, any: entries.contains(true) || !groups.isEmpty)
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

    /// True when `group` holds adult content and the profile hides it: the
    /// group is listed nowhere, not even with a lock.
    func isAdultHidden(_ group: CatalogueGroup) -> Bool {
        !rules.showsAdult && adultGroups.contains(group)
    }

    func isLocked(_ group: CatalogueGroup) -> Bool {
        locks.contains(group) && !isAdultHidden(group)
    }

    /// True when `group` lists no rows: hidden, locked or hidden adult.
    func isShut(_ group: CatalogueGroup) -> Bool {
        isLocked(group) || isAdultHidden(group) || (isHidden(group) && group != .all)
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
