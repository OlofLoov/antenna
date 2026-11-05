import Foundation

/// What screens use to show guide data. Not actor-isolated; the app conforms
/// on the main actor and forwards commands to a `GuideEngine`.
///
/// Queries answer from the latest published `GuideIndex` without waiting.
/// Commands return once the engine has taken them, never after a download.
/// `update(channels:)` returns before the lists are applied; the counts
/// follow as `.loaded` progress.
/// The channel loader calls `register(epgURLs:for:)`, then
/// `update(channels:)`, then `refreshIfStale(now:)` after each source.
public protocol GuideStore: AnyObject {
    var horizon: DateInterval? { get }
    func programmes(for keys: [GuideKey], in interval: DateInterval) -> [GuideKey: [Programme]]
    func current(for key: GuideKey, at date: Date) -> Programme?
    func next(for key: GuideKey, after date: Date, count: Int) -> [Programme]
    func loadingState(for key: GuideKey) -> GuideLoadingState
    func loadingState(for channel: Channel) -> GuideLoadingState
    func progressStream() -> AsyncStream<GuideProgress>
    func refreshIfStale(now: Date) async
    func refresh(sourceID: UUID) async
    func update(channels: [Channel]) async
    func register(epgURLs: [URL], for sourceID: UUID) async
    func remove(sourceID: UUID) async
}
