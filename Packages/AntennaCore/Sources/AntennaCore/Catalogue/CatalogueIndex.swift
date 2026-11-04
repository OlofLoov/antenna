import Foundation

/// Everything in a catalogue that does not depend on favorites, so
/// `Catalogue.replacingFavorites(_:)` can keep it as is.
///
/// Entries are the kept channels in source order, then position. The build
/// keeps closures and dictionary lookups per entry to a minimum because
/// AC-14 times it in a debug build.
struct CatalogueIndex: Sendable {
    /// Provider numbers outside this range count as missing.
    static let providerNumbers = 1...99_999

    let channels: [Channel]
    let keys: [RowKey]
    /// Assigned number per entry, the provider's or the fallback.
    let numbers: [Int]
    /// Named and ungrouped groups in display order, without `.favorites` and `.all`.
    let groups: [CatalogueGroup]
    /// Rows of each named or ungrouped group, sorted.
    let rowsByGroup: [CatalogueGroup: [RowKey]]
    /// The All channels order as keys, and its numbers for the digit search.
    let allRows: [RowKey]
    let sortedNumbers: [Int]
    /// Per entry: index in `allRows`, index in its group's rows, and its group.
    let allRank: [Int]
    let groupRank: [Int]
    let entryGroup: [CatalogueGroup]
    /// Entries per channel id, in entry order.
    let indicesByID: [String: [Int]]

    private struct Entries {
        var channels: [Channel] = []
        var keys: [RowKey] = []
        var ranks: [Int] = []
        var indicesByID: [String: [Int]] = [:]
    }

    private struct RawGroup: Hashable {
        let sourceRank: Int
        let name: String?
    }

    init(channels input: [Channel], groupOrder: [UUID: [String]]) {
        let entries = Self.entries(of: input)
        let channels = entries.channels
        let keys = entries.keys
        let sourceRanks = entries.ranks
        let indicesByID = entries.indicesByID

        var groupSlots: [CatalogueGroup] = []
        var slotByRaw: [RawGroup: Int] = [:]
        var slotByGroup: [CatalogueGroup: Int] = [:]
        var entrySlot: [Int] = []
        entrySlot.reserveCapacity(channels.count)
        for entry in channels.indices {
            let raw = RawGroup(sourceRank: sourceRanks[entry], name: channels[entry].group)
            if let slot = slotByRaw[raw] {
                entrySlot.append(slot)
                continue
            }
            let group = Self.group(sourceID: keys[entry].sourceID, name: raw.name)
            let slot = slotByGroup[group] ?? groupSlots.count
            if slot == groupSlots.count {
                groupSlots.append(group)
                slotByGroup[group] = slot
            }
            slotByRaw[raw] = slot
            entrySlot.append(slot)
        }

        let numbers = Self.assignNumbers(channels)
        let allOrder = Self.sortByNumber(numbers)

        var allRank = [Int](repeating: 0, count: channels.count)
        var groupRank = [Int](repeating: 0, count: channels.count)
        var slotRows = [[RowKey]](repeating: [], count: groupSlots.count)
        var allRows: [RowKey] = []
        allRows.reserveCapacity(channels.count)
        for (rank, entry) in zip(allOrder.indices, allOrder) {
            let slot = entrySlot[entry]
            allRank[entry] = rank
            groupRank[entry] = slotRows[slot].count
            slotRows[slot].append(keys[entry])
            allRows.append(keys[entry])
        }

        self.channels = channels
        self.keys = keys
        self.numbers = numbers
        self.groups = Self.orderGroups(groupSlots, groupOrder: groupOrder)
        self.rowsByGroup = Dictionary(uniqueKeysWithValues: zip(groupSlots, slotRows))
        self.allRows = allRows
        self.sortedNumbers = allOrder.map { numbers[$0] }
        self.allRank = allRank
        self.groupRank = groupRank
        self.entryGroup = entrySlot.map { groupSlots[$0] }
        self.indicesByID = indicesByID
    }

    static func group(sourceID: UUID, name: String?) -> CatalogueGroup {
        guard let name, !name.allSatisfy(\.isWhitespace) else { return .ungrouped(sourceID) }
        return .named(sourceID, name)
    }

    /// The entry with exactly `key`.
    func entry(for key: RowKey) -> Int? {
        indicesByID[key.id]?.first { keys[$0] == key }
    }

    /// Tagged channels without a duplicate key, sorted by source order then
    /// position, with each entry's source rank and the entries per id.
    private static func entries(of input: [Channel]) -> Entries {
        var rankBySource: [UUID: Int] = [:]
        var lastSource: UUID?
        var rank = 0
        var inputIndex: [Int] = []
        var tagged: [RowKey] = []
        var taggedRanks: [Int] = []
        var inOrder = true
        for index in input.indices {
            guard let key = RowKey(input[index]) else { continue }
            if key.sourceID != lastSource {
                rank = rankBySource[key.sourceID] ?? rankBySource.count
                rankBySource[key.sourceID] = rank
                lastSource = key.sourceID
            }
            if let previous = tagged.last, (taggedRanks[taggedRanks.count - 1], previous.position) > (rank, key.position) {
                inOrder = false
            }
            inputIndex.append(index)
            tagged.append(key)
            taggedRanks.append(rank)
        }
        var order = Array(tagged.indices)
        if !inOrder {
            order.sort { (taggedRanks[$0], tagged[$0].position, $0) < (taggedRanks[$1], tagged[$1].position, $1) }
        }

        var channels: [Channel] = []
        var keys: [RowKey] = []
        var ranks: [Int] = []
        var indicesByID: [String: [Int]] = [:]
        channels.reserveCapacity(order.count)
        keys.reserveCapacity(order.count)
        ranks.reserveCapacity(order.count)
        indicesByID.reserveCapacity(order.count)
        for item in order {
            let key = tagged[item]
            if let sameID = indicesByID[key.id] {
                guard !sameID.contains(where: { keys[$0] == key }) else { continue }
                indicesByID[key.id, default: []].append(keys.count)
            } else {
                indicesByID[key.id] = [keys.count]
            }
            channels.append(input[inputIndex[item]])
            keys.append(key)
            ranks.append(taggedRanks[item])
        }
        return Entries(channels: channels, keys: keys, ranks: ranks, indicesByID: indicesByID)
    }

    /// Provider numbers in range pass through. The rest get the highest of
    /// them plus 1, 2, ... in entry order.
    private static func assignNumbers(_ channels: [Channel]) -> [Int] {
        var numbers = [Int](repeating: 0, count: channels.count)
        var highest = 0
        for entry in channels.indices {
            if let number = channels[entry].number, providerNumbers.contains(number) {
                numbers[entry] = number
                highest = max(highest, number)
            }
        }
        var next = highest + 1
        for entry in numbers.indices where numbers[entry] == 0 {
            numbers[entry] = next
            next += 1
        }
        return numbers
    }

    /// Entry indices by number, ties in entry order, which is source order
    /// then position. A counting sort: numbers are positive and at most
    /// 99 999 plus the entry count.
    private static func sortByNumber(_ numbers: [Int]) -> [Int] {
        var highest = 0
        for number in numbers where number > highest { highest = number }
        var next = [Int](repeating: 0, count: highest + 2)
        for number in numbers { next[number + 1] += 1 }
        for slot in next.indices.dropFirst() { next[slot] += next[slot - 1] }
        var order = [Int](repeating: 0, count: numbers.count)
        for entry in numbers.indices {
            order[next[numbers[entry]]] = entry
            next[numbers[entry]] += 1
        }
        return order
    }

    /// Per source in source order: the `groupOrder` names that have channels,
    /// then the other names in first-appearance order, then Ungrouped.
    /// `slots` is in first-appearance order with each source's groups together.
    private static func orderGroups(_ slots: [CatalogueGroup], groupOrder: [UUID: [String]]) -> [CatalogueGroup] {
        var sources: [UUID] = []
        var seenSources: Set<UUID> = []
        var namesBySource: [UUID: [String]] = [:]
        var ungrouped: Set<UUID> = []
        for group in slots {
            let source: UUID
            switch group {
            case let .named(id, name):
                source = id
                namesBySource[id, default: []].append(name)
            case let .ungrouped(id):
                source = id
                ungrouped.insert(id)
            case .favorites, .all:
                continue
            }
            if seenSources.insert(source).inserted { sources.append(source) }
        }
        var result: [CatalogueGroup] = []
        for source in sources {
            let present = namesBySource[source] ?? []
            let presentSet = Set(present)
            var used: Set<String> = []
            var ordered: [String] = []
            for name in groupOrder[source] ?? [] where presentSet.contains(name) && used.insert(name).inserted {
                ordered.append(name)
            }
            ordered += present.filter { !used.contains($0) }
            result += ordered.map { .named(source, $0) }
            if ungrouped.contains(source) { result.append(.ungrouped(source)) }
        }
        return result
    }

    /// The lowest assigned number whose decimal form starts with `digits`
    /// after leading zeros are stripped.
    func match(digits: String) -> RowKey? {
        guard !digits.isEmpty, digits.unicodeScalars.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        let stripped = digits.drop { $0 == "0" }
        guard let highest = sortedNumbers.last, !stripped.isEmpty,
            stripped.count <= String(highest).count, var low = Int(stripped)
        else { return nil }
        var span = 1
        while low <= highest {
            let first = firstIndex(atLeast: low)
            if first < sortedNumbers.count, sortedNumbers[first] < low + span {
                return allRows[first]
            }
            low *= 10
            span *= 10
        }
        return nil
    }

    private func firstIndex(atLeast value: Int) -> Int {
        var low = 0
        var high = sortedNumbers.count
        while low < high {
            let mid = (low + high) / 2
            if sortedNumbers[mid] < value { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
