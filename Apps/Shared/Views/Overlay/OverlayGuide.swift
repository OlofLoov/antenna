import AntennaCore
import Foundation

/// The guide the channel overlay, info bar and guide grid read: each
/// channel's loading state, the programme on at a time and the programmes
/// in a stretch of time. The app reads `AppGuideStore`; the shell's UI
/// tests pass a scripted one.
struct OverlayGuide {
    let state: @MainActor (Channel) -> GuideLoadingState
    let current: @MainActor (Channel, Date) -> Programme?
    /// Up to the given count of programmes starting at or after the date.
    let next: @MainActor (Channel, Date, Int) -> [Programme]
    /// The programmes that overlap the interval, in start order.
    var programmes: @MainActor (Channel, DateInterval) -> [Programme] = { _, _ in [] }
    /// From the earliest start to the latest stop the guide holds, nil with no guide.
    var horizon: @MainActor () -> DateInterval? = { nil }
    /// Loads a source's guide again, as the guide's Retry asks.
    var refresh: @MainActor (UUID) -> Void = { _ in }

    /// What `channel`'s row says at `date`.
    @MainActor func line(for channel: Channel, at date: Date) -> GuideLine {
        GuideLine(state: state(channel), current: current(channel, date), now: date)
    }

    /// What the panel shows for one channel.
    struct Panel {
        /// The programme on now, if any.
        let now: Programme?
        let line: GuideLine
        /// Up to three that follow it, or follow now.
        let next: [Programme]
    }

    /// The panel's guide for `channel` at `date`.
    @MainActor func panel(for channel: Channel, at date: Date) -> Panel {
        let now = current(channel, date)
        let line = GuideLine(state: state(channel), current: now, now: date)
        return Panel(now: now, line: line, next: next(channel, now?.stop ?? date, 3))
    }

    /// The app's guide store; with none, every channel has no guide.
    static func store(_ store: AppGuideStore?) -> OverlayGuide {
        OverlayGuide(
            state: { store?.loadingState(for: $0) ?? .unavailable },
            current: { channel, date in GuideKey(channel: channel).flatMap { store?.current(for: $0, at: date) } },
            next: { channel, date, count in
                GuideKey(channel: channel).map { store?.next(for: $0, after: date, count: count) ?? [] } ?? []
            },
            programmes: { channel, interval in
                guard let key = GuideKey(channel: channel) else { return [] }
                return store?.programmes(for: [key], in: interval)[key] ?? []
            },
            horizon: { store?.horizon },
            refresh: { id in Task { await store?.refresh(sourceID: id) } })
    }
}
