import Foundation

/// One source's programmes, keyed by trimmed XMLTV channel id, cleaned so
/// that each key's list is sorted by start and has no overlaps. Every
/// programme is kept whether or not a channel uses its id, so a new channel
/// list needs no re-parse.
///
/// Programmes are stored compactly: each is a fixed-size `Slot` of times and
/// references into one UTF-8 text buffer per source, where a repeated title
/// or description is kept once. Queries build `Programme` values on demand.
struct SourceGuide: Sendable {
    /// A run of bytes in `text`; `length == .max` means no value.
    struct TextRef: Sendable, Equatable {
        var offset: UInt32
        var length: UInt32

        static let none = TextRef(offset: 0, length: .max)
    }

    /// One programme without its channel id, which is the key it is stored under.
    struct Slot: Sendable {
        var start: Date
        var stop: Date
        var title: TextRef
        var subtitle: TextRef
        var summary: TextRef
        var category: TextRef
        var icon: TextRef
    }

    let schedules: [String: [Slot]]
    private let text: [UInt8]
    /// Earliest start to latest stop over every programme; nil when there are none.
    let span: DateInterval?
    let count: Int

    /// Drops programmes whose stop is not after their start. Per id, sorts by
    /// start; of equal starts keeps the last in input order; then cuts each
    /// programme's stop to the next one's start, so the later start wins and
    /// nothing is split.
    init(_ input: [Programme]) {
        var builder = Builder()
        for programme in input { builder.add(programme) }
        self = builder.build()
    }

    fileprivate init(schedules: [String: [Slot]], text: [UInt8]) {
        var count = 0
        var earliest: Date?
        var latest: Date?
        for slots in schedules.values {
            count += slots.count
            if let first = slots.first { earliest = min(earliest ?? first.start, first.start) }
            if let stop = slots.last?.stop { latest = max(latest ?? stop, stop) }
        }
        self.schedules = schedules
        self.text = text
        self.count = count
        if let earliest, let latest { span = DateInterval(start: earliest, end: latest) } else { span = nil }
    }

    /// The programme in `slot`, stored under channel id `id`.
    func programme(_ slot: Slot, id: String) -> Programme {
        Programme(
            channelID: id, start: slot.start, stop: slot.stop, title: string(slot.title) ?? "",
            subtitle: string(slot.subtitle), summary: string(slot.summary), category: string(slot.category),
            iconURL: string(slot.icon).flatMap(URL.init(string:)))
    }

    /// Every programme, per id. Builds them all, so only tests use it.
    var programmes: [String: [Programme]] {
        Dictionary(uniqueKeysWithValues: schedules.map { id, slots in (id, slots.map { programme($0, id: id) }) })
    }

    func string(_ ref: TextRef) -> String? {
        guard ref.length != TextRef.none.length else { return nil }
        guard ref.length > 0 else { return "" }
        let start = Int(ref.offset)
        return text.withUnsafeBufferPointer { buffer in
            String(decoding: UnsafeBufferPointer(rebasing: buffer[start..<start + Int(ref.length)]), as: UTF8.self)
        }
    }

    /// Collects programmes one at a time, as the parser hands them over, so
    /// no array of `Programme` is ever held.
    struct Builder {
        /// Repeated text is looked up here. It stops growing past this many
        /// entries, so the table stays small for guides with little repetition.
        private static let internLimit = 65_536

        private var grouped: [String: [Slot]] = [:]
        private var text: [UInt8] = []
        private var interned: [Int: TextRef] = [:]

        mutating func add(_ programme: Programme) {
            guard programme.start < programme.stop else { return }
            let slot = Slot(
                start: programme.start, stop: programme.stop, title: store(programme.title),
                subtitle: store(programme.subtitle), summary: store(programme.summary), category: store(programme.category),
                icon: store(programme.iconURL?.absoluteString))
            grouped[programme.channelID.trimmingCharacters(in: .whitespacesAndNewlines), default: []].append(slot)
        }

        private mutating func store(_ value: String?) -> TextRef {
            guard let value else { return .none }
            var hasher = Hasher()
            hasher.combine(value)
            let hash = hasher.finalize()
            if let ref = interned[hash], text[Int(ref.offset)..<Int(ref.offset) + Int(ref.length)].elementsEqual(value.utf8) {
                return ref
            }
            let ref = TextRef(offset: UInt32(text.count), length: UInt32(value.utf8.count))
            text.append(contentsOf: value.utf8)
            if interned.count < Self.internLimit, interned[hash] == nil { interned[hash] = ref }
            return ref
        }

        consuming func build() -> SourceGuide {
            interned = [:]
            for id in Array(grouped.keys) {
                guard var slots = grouped.removeValue(forKey: id) else { continue }
                SourceGuide.clean(&slots)
                grouped[id] = slots
            }
            // An array grows by doubling; copy the text once so the guide
            // keeps no unused capacity.
            let packed = Array(text)
            text = []
            return SourceGuide(schedules: grouped, text: packed)
        }
    }

    /// Sorts by start, keeps the last of equal starts in input order, and cuts
    /// each stop to the next start.
    fileprivate static func clean(_ slots: inout [Slot]) {
        let order = slots.indices.sorted { (slots[$0].start, $0) < (slots[$1].start, $1) }
        var cleaned: [Slot] = []
        cleaned.reserveCapacity(slots.count)
        for index in order {
            let slot = slots[index]
            if let last = cleaned.last, last.start == slot.start {
                cleaned[cleaned.count - 1] = slot
                continue
            }
            if let last = cleaned.last, last.stop > slot.start {
                cleaned[cleaned.count - 1].stop = slot.start
            }
            cleaned.append(slot)
        }
        slots = cleaned
    }

    struct Summary: Sendable, Equatable {
        var channelsWithGuide: Int
        var channelsTotal: Int
        var days: Int
        var unmatched: Int
    }

    /// Counts for `GuideProgress.loaded`, given every channel of this source.
    /// A channel has a guide when its key has any programme, past ones
    /// included, the same rule `GuideIndex.loadingState` uses for `.loaded`.
    func summary(channels: [Channel], now: Date) -> Summary {
        var used = Set<String>()
        var withGuide = 0
        for channel in channels {
            guard let key = GuideKey(channel: channel) else { continue }
            used.insert(key.epgID)
            if schedules[key.epgID]?.isEmpty == false { withGuide += 1 }
        }
        let matched = used.reduce(0) { $0 + (schedules[$1]?.count ?? 0) }
        return Summary(channelsWithGuide: withGuide, channelsTotal: channels.count, days: days(from: now), unmatched: count - matched)
    }

    /// UTC calendar days from the one holding `now` through the one holding the
    /// latest stop, on which a programme starts or is airing at 00:00 UTC.
    func days(from now: Date) -> Int {
        let secondsPerDay = 86_400.0
        func day(_ date: Date) -> Int { Int((date.timeIntervalSince1970 / secondsPerDay).rounded(.down)) }
        let today = day(now)
        var covered = Set<Int>()
        for slots in schedules.values {
            for slot in slots {
                var current = day(slot.start)
                while Double(current) * secondsPerDay < slot.stop.timeIntervalSince1970 {
                    if current >= today { covered.insert(current) }
                    current += 1
                }
            }
        }
        return covered.count
    }
}
