import Foundation

/// An immutable snapshot of every source's guide. Queries read it without
/// locking; the guide engine builds a new one and publishes it whole.
///
/// A programme is on from its start until just before its stop. Each key's
/// programmes are sorted by start and never overlap: where two overlapped,
/// the later start won and the earlier one ends where it begins.
public struct GuideIndex: Sendable {
    struct SourceEntry: Sendable {
        /// Set once a load has completed.
        var guide: SourceGuide?
        /// The answer for every channel of the source while `guide` is nil.
        var state: GuideLoadingState
    }

    var sources: [UUID: SourceEntry]

    /// An index with no sources and no reach.
    public init() {
        sources = [:]
    }

    /// An index in which every listed source has completed with these
    /// programmes. Tests, previews and UI test scripts use it; the app gets
    /// its index from the guide engine.
    public init(programmes: [UUID: [Programme]]) {
        sources = programmes.mapValues { SourceEntry(guide: SourceGuide($0), state: .loading) }
    }

    init(sources: [UUID: SourceEntry]) {
        self.sources = sources
    }

    /// From the earliest start to the latest stop over every completed
    /// source, including programmes no channel uses. Nil when no source holds
    /// a programme.
    public var horizon: DateInterval? {
        let spans = sources.values.compactMap { $0.guide?.span }
        guard let start = spans.map(\.start).min(), let end = spans.map(\.end).max() else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// How many programmes the completed sources hold, used ones or not.
    /// Changes when a source's guide loads, refreshes or goes.
    public var programmeCount: Int {
        sources.values.reduce(0) { $0 + ($1.guide?.count ?? 0) }
    }

    /// How many sources are past loading: completed, failed or without a guide.
    public var settledSourceCount: Int {
        sources.values.count { $0.guide != nil || $0.state != .loading }
    }

    /// The programme on at `date`, or nil when nothing is.
    public func current(for key: GuideKey, at date: Date) -> Programme? {
        guard let (guide, list) = schedule(for: key) else { return nil }
        let index = firstIndex(in: list) { $0.start > date } - 1
        guard index >= 0, date < list[index].stop else { return nil }
        return guide.programme(list[index], id: key.epgID)
    }

    /// Up to `count` programmes starting at or after `date`, in start order.
    /// Callers pass the current programme's stop, or now when nothing is on.
    public func next(for key: GuideKey, after date: Date, count: Int) -> [Programme] {
        guard count > 0, let (guide, list) = schedule(for: key) else { return [] }
        let first = firstIndex(in: list) { $0.start >= date }
        return list[first..<min(list.count, first + count)].map { guide.programme($0, id: key.epgID) }
    }

    /// Per key, every programme that overlaps `interval` (start before its end,
    /// stop after its start), in start order. Gaps stay empty. Keys with
    /// nothing in the window are left out.
    public func programmes(for keys: [GuideKey], in interval: DateInterval) -> [GuideKey: [Programme]] {
        var result: [GuideKey: [Programme]] = [:]
        for key in keys {
            guard let (guide, list) = schedule(for: key) else { continue }
            let first = firstIndex(in: list) { $0.stop > interval.start }
            let end = firstIndex(in: list) { $0.start >= interval.end }
            if first < end { result[key] = list[first..<end].map { guide.programme($0, id: key.epgID) } }
        }
        return result
    }

    /// `.loaded` or `.noData` once the key's source has completed a load;
    /// before that the source's state. A source the index has not heard of
    /// is `.loading`.
    public func loadingState(for key: GuideKey) -> GuideLoadingState {
        guard let entry = sources[key.sourceID] else { return .loading }
        guard let guide = entry.guide else { return entry.state }
        return guide.schedules[key.epgID]?.isEmpty == false ? .loaded : .noData
    }

    /// As `loadingState(for:)` with the channel's key. A channel without a
    /// guide id reports its source's state, then `.noData` once the source has
    /// completed. A channel without `sourceID` is `.unavailable`.
    public func loadingState(for channel: Channel) -> GuideLoadingState {
        if let key = GuideKey(channel: channel) { return loadingState(for: key) }
        guard let sourceID = channel.sourceID else { return .unavailable }
        guard let entry = sources[sourceID] else { return .loading }
        return entry.guide == nil ? entry.state : .noData
    }

    private func schedule(for key: GuideKey) -> (SourceGuide, [SourceGuide.Slot])? {
        guard let guide = sources[key.sourceID]?.guide, let slots = guide.schedules[key.epgID] else { return nil }
        return (guide, slots)
    }

    /// The first index whose element satisfies `predicate`, which must be
    /// false then true along the list; `list.count` when none does.
    private func firstIndex(in list: [SourceGuide.Slot], where predicate: (SourceGuide.Slot) -> Bool) -> Int {
        var low = 0
        var high = list.count
        while low < high {
            let mid = (low + high) / 2
            if predicate(list[mid]) { high = mid } else { low = mid + 1 }
        }
        return low
    }
}
