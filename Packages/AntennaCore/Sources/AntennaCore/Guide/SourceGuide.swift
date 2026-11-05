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
        // One grouped copy of the programmes; each id's list is cleaned on
        // its own, so the peak stays near two copies of the input.
        var grouped: [String: [Programme]] = [:]
        for programme in input where programme.start < programme.stop {
            grouped[programme.channelID.trimmingCharacters(in: .whitespacesAndNewlines), default: []].append(programme)
        }
        var count = 0
        var earliest: Date?
        var latest: Date?
        for id in Array(grouped.keys) {
            guard var list = grouped.removeValue(forKey: id) else { continue }
            Self.clean(&list)
            count += list.count
            if let first = list.first { earliest = min(earliest ?? first.start, first.start) }
            if let stop = list.last?.stop { latest = max(latest ?? stop, stop) }
            grouped[id] = list
        }
        programmes = grouped
        self.count = count
        if let earliest, let latest { span = DateInterval(start: earliest, end: latest) } else { span = nil }
    }

    /// Sorts by start, keeps the last of equal starts in input order, and cuts
    /// each stop to the next start.
    private static func clean(_ list: inout [Programme]) {
        let order = list.indices.sorted { (list[$0].start, $0) < (list[$1].start, $1) }
        var cleaned: [Programme] = []
        cleaned.reserveCapacity(list.count)
        for index in order {
            let programme = list[index]
            if let last = cleaned.last, last.start == programme.start {
                cleaned[cleaned.count - 1] = programme
                continue
            }
            if let last = cleaned.last, last.stop > programme.start {
                cleaned[cleaned.count - 1].stop = programme.start
            }
            cleaned.append(programme)
        }
        list = cleaned
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
