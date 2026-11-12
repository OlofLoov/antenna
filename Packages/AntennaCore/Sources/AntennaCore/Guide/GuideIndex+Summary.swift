import Foundation

extension GuideIndex {
    /// Counts for `GuideProgress.loaded` over every turned-on guide of the
    /// source, given its channels. A channel has a guide when its key from
    /// `key(for:)` has any programme, past ones included, the rule
    /// `loadingState(for:)` uses for `.loaded`. `days` is the most any one
    /// guide covers.
    func summary(sourceID: UUID, channels: [Channel], now: Date) -> SourceGuide.Summary {
        guard let entry = sources[sourceID] else {
            return SourceGuide.Summary(channelsWithGuide: 0, channelsTotal: channels.count, days: 0, unmatched: 0)
        }
        var used = Set<String>()
        var withGuide = 0
        for channel in channels {
            guard let key = key(for: channel) else { continue }
            used.insert(key.epgID)
            if schedule(for: key) != nil { withGuide += 1 }
        }
        var total = 0
        var matched = 0
        var days = 0
        for layer in entry.layers {
            total += layer.guide.count
            matched += used.reduce(0) { $0 + (layer.guide.schedules[$1]?.count ?? 0) }
            days = max(days, layer.guide.days(from: now))
        }
        return SourceGuide.Summary(channelsWithGuide: withGuide, channelsTotal: channels.count, days: days, unmatched: total - matched)
    }
}
