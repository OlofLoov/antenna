import Foundation

/// Channels, programmes and titles folded once, so each keystroke only
/// compares text (search capability). Build it from whatever has loaded and
/// build it again when a source, its guide or its titles change; a query
/// never waits for a load.
///
/// Programmes are kept by their distinct title and episode title, so a
/// title repeated through the week is folded and compared once, and in
/// result order, so a query sorts nothing.
public struct SearchIndex: Sendable {
    /// How far ahead In the guide looks (search/seven-days-of-guide).
    public static let horizon: TimeInterval = 7 * 24 * 3600
    /// How far past `horizon` the index reads, so a query a while after the
    /// build still sees seven days. Build again within this long.
    public static let slack: TimeInterval = 24 * 3600

    private struct ChannelEntry: Sendable {
        let channel: SearchChannel
        let name: String
        let group: String
        let number: String
    }

    private struct TitleEntry: Sendable {
        let title: ShelfTitle
        let name: String
        let order: Int
    }

    private let channelEntries: [ChannelEntry]
    private let titleEntries: [TitleEntry]
    private let programmes: ProgrammeStore

    /// An index with nothing in it.
    public init() {
        self.init(channels: [], guide: GuideIndex(), titles: [], now: .distantPast)
    }

    /// - Parameters:
    ///   - channels: every loaded channel. Channels with a blank name are
    ///     left out.
    ///   - guide: the guide. Programmes no channel uses are left out, and so
    ///     are those that end by `now` or start after seven days and `slack`.
    ///   - titles: every loaded movie and series, in source order. Titles
    ///     with a blank name are left out.
    ///   - now: the time of the build.
    public init(channels: [SearchChannel], guide: GuideIndex, titles: [ShelfTitle], now: Date) {
        channelEntries = channels.compactMap { channel in
            let name = SearchQuery.fold(channel.name)
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ChannelEntry(
                channel: channel, name: name, group: channel.group.map(SearchQuery.fold) ?? "",
                number: channel.number.map(String.init) ?? "")
        }
        titleEntries = zip(titles.indices, titles).compactMap { order, title in
            let name = SearchQuery.fold(title.name)
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return TitleEntry(title: title, name: name, order: order)
        }
        programmes = ProgrammeStore(channels: channels, guide: guide, window: DateInterval(start: now, duration: Self.horizon + Self.slack))
    }

    /// Everything `query` finds at `now`; nothing for a query shorter than
    /// two characters.
    ///
    /// Channels rank by whether the name starts with the whole query, then
    /// whether a word of it starts with the first word, then any other name
    /// match, then a number that starts with the typed digits, then a group
    /// match; within a rank by name, number and source, and number matches
    /// by number. Programmes are those on at `now` or starting within seven
    /// days, by start then channel number. Titles rank as channel names do,
    /// then by name and source order.
    public func results(for query: SearchQuery, now: Date) -> SearchResults {
        guard query.isSearchable else { return .none(query) }
        return SearchResults(
            query: query, channels: channels(matching: query), programmes: programmes.hits(matching: query, now: now),
            titles: titles(matching: query))
    }

    // MARK: Channels

    private func channels(matching query: SearchQuery) -> [SearchResults.ChannelHit] {
        var ranked: [(band: Int, entry: ChannelEntry)] = []
        for entry in channelEntries {
            if query.matches(folded: entry.name) {
                ranked.append((Self.nameBand(entry.name, query), entry))
            } else if let digits = query.digits, entry.number.hasPrefix(digits) {
                ranked.append((3, entry))
            } else if query.matches(folded: entry.group) {
                ranked.append((4, entry))
            }
        }
        ranked.sort { lhs, rhs in
            if lhs.band != rhs.band { return lhs.band < rhs.band }
            let left = lhs.entry
            let right = rhs.entry
            // Number matches read as a list of numbers.
            if lhs.band == 3, left.channel.number != right.channel.number {
                return (left.channel.number ?? .max) < (right.channel.number ?? .max)
            }
            if left.name != right.name { return left.name < right.name }
            if left.channel.number != right.channel.number { return (left.channel.number ?? .max) < (right.channel.number ?? .max) }
            if left.channel.sourceOrder != right.channel.sourceOrder { return left.channel.sourceOrder < right.channel.sourceOrder }
            return left.channel.key.position < right.channel.key.position
        }
        return ranked.map { band, entry in
            let match: SearchResults.ChannelHit.Match =
                switch band {
                case 3: .number
                case 4: .group
                default: .name
                }
            return SearchResults.ChannelHit(channel: entry.channel, match: match)
        }
    }

    /// 0 when `name` starts with the whole query, 1 when one of its words
    /// starts with the first word, 2 otherwise.
    private static func nameBand(_ name: String, _ query: SearchQuery) -> Int {
        if name.hasPrefix(query.folded) { return 0 }
        guard let first = query.tokens.first else { return 2 }
        var searchStart = name.startIndex
        while let found = name.range(of: first, range: searchStart..<name.endIndex) {
            if found.lowerBound == name.startIndex { return 1 }
            let before = name[name.index(before: found.lowerBound)]
            if !(before.isLetter || before.isNumber) { return 1 }
            searchStart = name.index(after: found.lowerBound)
        }
        return 2
    }

    // MARK: Titles

    private func titles(matching query: SearchQuery) -> [SearchResults.TitleHit] {
        titleEntries
            .filter { query.matches(folded: $0.name) }
            .map { (band: Self.nameBand($0.name, query), entry: $0) }
            .sorted { lhs, rhs in
                if lhs.band != rhs.band { return lhs.band < rhs.band }
                if lhs.entry.name != rhs.entry.name { return lhs.entry.name < rhs.entry.name }
                return lhs.entry.order < rhs.entry.order
            }
            .map { SearchResults.TitleHit(title: $0.entry.title) }
    }
}

/// The programmes of a search index, in result order: by start, then by
/// the rank of the channel they show under.
final class ProgrammeStore: Sendable {
    struct Entry: Sendable {
        let start: Date
        let stop: Date
        /// Indices into `texts`; -1 for none.
        let title: Int32
        let subtitle: Int32
        /// Index into `keys` and `owners`.
        let key: Int32
    }

    let entries: [Entry]
    let texts: [String]
    private let foldedTexts: [String]
    /// Per text, the entries whose title or episode title it is.
    private let entriesByText: [[Int32]]
    let keys: [GuideKey]
    /// Per key, the channel its programmes show under: of the channels
    /// sharing it, the lowest number, then the earlier source and row.
    let owners: [SearchChannel]
    /// The longest programme, so a query knows how far back to look for one on now.
    private let longest: TimeInterval

    init(channels: [SearchChannel], guide: GuideIndex, window: DateInterval) {
        var owner: [GuideKey: SearchChannel] = [:]
        for channel in channels {
            guard let key = channel.guideKey else { continue }
            if let current = owner[key], !Self.ranks(channel, before: current) { continue }
            owner[key] = channel
        }
        let ranked = owner.sorted { Self.ranks($0.value, before: $1.value) }

        var keys: [GuideKey] = []
        var owners: [SearchChannel] = []
        var texts: [String] = []
        var textIDs: [UInt64: Int32] = [:]
        var sourceNumbers: [UUID: UInt64] = [:]
        var unsorted: [Entry] = []
        var longest: TimeInterval = 0
        for (key, channel) in ranked {
            guard let guide = guide.sources[key.sourceID]?.guide, let slots = guide.schedules[key.epgID] else { continue }
            let sourceNumber = sourceNumbers[key.sourceID] ?? UInt64(sourceNumbers.count)
            sourceNumbers[key.sourceID] = sourceNumber
            // A repeated text is stored once per source, so its offset names it.
            func textID(_ ref: SourceGuide.TextRef) -> Int32 {
                guard ref.length != SourceGuide.TextRef.none.length, ref.length > 0 else { return -1 }
                let name = sourceNumber << 32 | UInt64(ref.offset)
                if let id = textIDs[name] { return id }
                let id = Int32(texts.count)
                texts.append(guide.string(ref) ?? "")
                textIDs[name] = id
                return id
            }
            let keyID = Int32(keys.count)
            var added = false
            for slot in slots where slot.stop > window.start && slot.start < window.end {
                unsorted.append(
                    Entry(start: slot.start, stop: slot.stop, title: textID(slot.title), subtitle: textID(slot.subtitle), key: keyID))
                longest = max(longest, slot.stop.timeIntervalSince(slot.start))
                added = true
            }
            if added {
                keys.append(key)
                owners.append(channel)
            }
        }
        entries = Self.byStart(unsorted)
        var byText = [[Int32]](repeating: [], count: texts.count)
        for (offset, entry) in entries.enumerated() {
            if entry.title >= 0 { byText[Int(entry.title)].append(Int32(offset)) }
            if entry.subtitle >= 0, entry.subtitle != entry.title { byText[Int(entry.subtitle)].append(Int32(offset)) }
        }
        self.texts = texts
        foldedTexts = texts.map(SearchQuery.fold)
        entriesByText = byText
        self.keys = keys
        self.owners = owners
        self.longest = longest
    }

    static let empty = ProgrammeStore(channels: [], guide: GuideIndex(), window: DateInterval())

    /// Lower number, then earlier source, then earlier row.
    static func ranks(_ lhs: SearchChannel, before rhs: SearchChannel) -> Bool {
        (lhs.number ?? .max, lhs.sourceOrder, lhs.key.position) < (rhs.number ?? .max, rhs.sourceOrder, rhs.key.position)
    }

    /// `entries` by start, keeping their order within one start, which is
    /// channel rank. A counting sort over the distinct starts, which are few.
    private static func byStart(_ entries: [Entry]) -> [Entry] {
        var bucketOf: [Date: Int] = [:]
        for entry in entries where bucketOf[entry.start] == nil { bucketOf[entry.start] = 0 }
        for (rank, start) in bucketOf.keys.sorted().enumerated() { bucketOf[start] = rank }
        var counts = [Int](repeating: 0, count: bucketOf.count + 1)
        let buckets = entries.map { bucketOf[$0.start] ?? 0 }
        for bucket in buckets { counts[bucket + 1] += 1 }
        for index in counts.indices.dropFirst() { counts[index] += counts[index - 1] }
        var sorted = entries
        for (entry, bucket) in zip(entries, buckets) {
            sorted[counts[bucket]] = entry
            counts[bucket] += 1
        }
        return sorted
    }

    /// The entries matching `query` that are on at `now` or start within
    /// seven days, in order.
    func hits(matching query: SearchQuery, now: Date) -> SearchResults.Programmes {
        var marked = [Bool](repeating: false, count: entries.count)
        var any = false
        for (textID, folded) in foldedTexts.enumerated() where query.matches(folded: folded) {
            for offset in entriesByText[textID] { marked[Int(offset)] = true }
            any = true
        }
        guard any else { return SearchResults.Programmes(store: self, offsets: [], now: now) }
        let end = now.addingTimeInterval(SearchIndex.horizon)
        var offsets: [Int32] = []
        var index = firstEntry(startingAtOrAfter: now.addingTimeInterval(-longest))
        while index < entries.count, entries[index].start < end {
            if marked[index], entries[index].stop > now { offsets.append(Int32(index)) }
            index += 1
        }
        return SearchResults.Programmes(store: self, offsets: offsets, now: now)
    }

    private func firstEntry(startingAtOrAfter date: Date) -> Int {
        var low = 0
        var high = entries.count
        while low < high {
            let mid = (low + high) / 2
            if entries[mid].start >= date { high = mid } else { low = mid + 1 }
        }
        return low
    }

    func hit(_ offset: Int32, now: Date) -> SearchResults.ProgrammeHit {
        let entry = entries[Int(offset)]
        let key = keys[Int(entry.key)]
        let programme = Programme(
            channelID: key.epgID, start: entry.start, stop: entry.stop, title: entry.title >= 0 ? texts[Int(entry.title)] : "",
            subtitle: entry.subtitle >= 0 ? texts[Int(entry.subtitle)] : nil)
        return SearchResults.ProgrammeHit(
            programme: programme, channel: owners[Int(entry.key)], isOnNow: entry.start <= now && now < entry.stop,
            id: .init(guideKey: key, start: entry.start))
    }
}
