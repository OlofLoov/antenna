import Foundation

/// One source's programmes, keyed by trimmed XMLTV channel id, cleaned so
/// that each key's list is sorted by start and has no overlaps. Every
/// programme is kept whether or not a channel uses its id, so a new channel
/// list needs no re-parse.
struct SourceGuide: Sendable {
    let programmes: [String: [Programme]]
    /// Earliest start to latest stop over every programme; nil when there are none.
    let span: DateInterval?
    let count: Int

    /// Drops programmes whose stop is not after their start. Per id, sorts by
    /// start; of equal starts keeps the last in input order; then cuts each
    /// programme's stop to the next one's start, so the later start wins and
    /// nothing is split.
    init(_ input: [Programme]) {
        var grouped: [String: [(offset: Int, programme: Programme)]] = [:]
        for (offset, programme) in input.enumerated() where programme.start < programme.stop {
            let id = programme.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
            grouped[id, default: []].append((offset, programme))
        }
        var programmes: [String: [Programme]] = [:]
        programmes.reserveCapacity(grouped.count)
        var count = 0
        var earliest: Date?
        var latest: Date?
        for (id, entries) in grouped {
            let sorted = entries.sorted { ($0.programme.start, $0.offset) < ($1.programme.start, $1.offset) }
            var cleaned: [Programme] = []
            cleaned.reserveCapacity(sorted.count)
            for entry in sorted {
                if let last = cleaned.last, last.start == entry.programme.start {
                    cleaned[cleaned.count - 1] = entry.programme
                    continue
                }
                if let last = cleaned.last, last.stop > entry.programme.start {
                    cleaned[cleaned.count - 1].stop = entry.programme.start
                }
                cleaned.append(entry.programme)
            }
            count += cleaned.count
            if let first = cleaned.first { earliest = min(earliest ?? first.start, first.start) }
            if let stop = cleaned.map(\.stop).max() { latest = max(latest ?? stop, stop) }
            programmes[id] = cleaned
        }
        self.programmes = programmes
        self.count = count
        if let earliest, let latest { span = DateInterval(start: earliest, end: latest) } else { span = nil }
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
            if programmes[key.epgID]?.isEmpty == false { withGuide += 1 }
        }
        let matched = used.reduce(0) { $0 + (programmes[$1]?.count ?? 0) }
        return Summary(channelsWithGuide: withGuide, channelsTotal: channels.count, days: days(from: now), unmatched: count - matched)
    }

    /// UTC calendar days from the one holding `now` through the one holding the
    /// latest stop, on which a programme starts or is airing at 00:00 UTC.
    func days(from now: Date) -> Int {
        let secondsPerDay = 86_400.0
        func day(_ date: Date) -> Int { Int((date.timeIntervalSince1970 / secondsPerDay).rounded(.down)) }
        let today = day(now)
        var covered = Set<Int>()
        for list in programmes.values {
            for programme in list {
                var current = day(programme.start)
                while Double(current) * secondsPerDay < programme.stop.timeIntervalSince1970 {
                    if current >= today { covered.insert(current) }
                    current += 1
                }
            }
        }
        return covered.count
    }
}
