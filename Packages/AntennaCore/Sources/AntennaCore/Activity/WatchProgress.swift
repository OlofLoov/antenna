import Foundation

/// How far into a movie or episode the user got (watch-progress-sync). One
/// value per stored record; `resolve` settles copies from several devices.
public struct WatchProgress: Sendable, Hashable {
    /// The record's own id, the last tie-break between copies.
    public var id: String
    /// The movie or episode, `xtream#<host>#vod#<id>` or `xtream#<host>#episode#<id>`.
    public var titleID: String
    /// The series an episode belongs to; nil for a movie.
    public var seriesID: String?
    public var sourceID: UUID?
    /// Seconds from the start.
    public var position: Double
    /// Seconds; nil, zero, negative or not finite reads as unknown.
    public var duration: Double?
    public var updatedAt: Date

    public init(
        id: String, titleID: String, seriesID: String? = nil, sourceID: UUID?, position: Double, duration: Double?,
        updatedAt: Date
    ) {
        self.id = id
        self.titleID = titleID
        self.seriesID = seriesID
        self.sourceID = sourceID
        self.position = position
        self.duration = duration
        self.updatedAt = updatedAt
    }

    /// False for a damaged record: no title, no source, or a position that is
    /// negative or not finite. Reads skip it and writes never delete it
    /// (watch-progress-sync/devices-that-disagree-settle-on-the-same-answer).
    public var isUsable: Bool {
        !titleID.isEmpty && sourceID != nil && position.isFinite && position >= 0
    }

    /// The length when it is a usable number of seconds.
    public var knownDuration: Double? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    /// Not started, in progress or watched, from the share of the length
    /// watched (watch-progress-sync/in-progress-and-watched-mean-the-same-everywhere).
    public var state: WatchState {
        guard let length = knownDuration else { return .notStarted }
        let share = position / length
        if share < WatchState.inProgressFrom { return .notStarted }
        return share < WatchState.watchedFrom ? .inProgress : .watched
    }

    /// Where playback resumes: the saved position while in progress, else the start.
    public var resumePosition: Double {
        state == .inProgress ? position : 0
    }

    /// Which copies of a title the screens see: per title and source, the
    /// latest `updatedAt`, then the higher position, then the lower id.
    public static func resolve(_ copies: [WatchProgress]) -> Resolution<WatchProgress> {
        Resolution(copies, usable: \.isUsable, key: { ActivityKey(titleID: $0.titleID, sourceID: $0.sourceID) }) { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.position != rhs.position { return lhs.position > rhs.position }
            return lhs.id < rhs.id
        }
    }

    /// The episodes of `seriesID` among `progress`, most recently saved first
    /// (watch-progress-sync/a-series-shows-progress-for-each-of-its-episodes).
    public static func episodes(of seriesID: String, in progress: [WatchProgress]) -> [WatchProgress] {
        progress.filter { $0.seriesID == seriesID }.sorted(by: newestFirst)
    }

    /// Most recently saved first, then by id so the order never wavers.
    public static func newestFirst(_ lhs: WatchProgress, _ rhs: WatchProgress) -> Bool {
        lhs.updatedAt != rhs.updatedAt ? lhs.updatedAt > rhs.updatedAt : lhs.id < rhs.id
    }

    /// The time a save on this device stamps: now, or just after the copy it
    /// replaces when another device's clock put that copy later, so the new
    /// save wins (watch-progress-sync/devices-that-disagree-settle-on-the-same-answer).
    public static func stamp(now: Date, replacing survivor: Date?) -> Date {
        guard let survivor else { return now }
        return max(now, survivor.addingTimeInterval(0.001))
    }

    /// False for a title id that could carry a link or a login: empty, or
    /// holding `://` or `@` (watch-progress-sync/progress-is-saved-and-read-back).
    public static func isStorable(titleID: String) -> Bool {
        !titleID.isEmpty && !titleID.contains("://") && !titleID.contains("@")
    }
}

/// Where a title stands for Continue watching and resume.
public enum WatchState: Sendable, Hashable {
    /// Under 2% watched, or no known length.
    case notStarted
    /// From 2% up to 95% watched.
    case inProgress
    /// 95% or more watched.
    case watched

    static let inProgressFrom = 0.02
    static let watchedFrom = 0.95
}

/// The identity that progress and My list entries share: a title from one source.
public struct ActivityKey: Sendable, Hashable {
    public var titleID: String
    public var sourceID: UUID?

    public init(titleID: String, sourceID: UUID?) {
        self.titleID = titleID
        self.sourceID = sourceID
    }
}

/// Copies settled into one per key. `winners` are what the screens see,
/// `losers` the indices into the input a write deletes. Damaged copies are in
/// neither, so nothing deletes them.
public struct Resolution<Value: Sendable>: Sendable {
    /// One per key, in the order their keys first appear.
    public let winners: [Value]
    /// Indices into the copies passed in, matching `winners`.
    public let winnerIndices: [Int]
    /// Indices into the copies passed in, ascending.
    public let losers: [Int]

    init<Key: Hashable>(
        _ copies: [Value], usable: (Value) -> Bool, key: (Value) -> Key, wins: (Value, Value) -> Bool
    ) {
        var best: [Key: Int] = [:]
        var order: [Key] = []
        var lost: [Int] = []
        for (index, copy) in copies.enumerated() where usable(copy) {
            let key = key(copy)
            guard let current = best[key] else {
                best[key] = index
                order.append(key)
                continue
            }
            if wins(copy, copies[current]) {
                lost.append(current)
                best[key] = index
            } else {
                lost.append(index)
            }
        }
        winnerIndices = order.compactMap { best[$0] }
        winners = winnerIndices.map { copies[$0] }
        losers = lost.sorted()
    }

    init(_ copies: [Value], winnerIndices: [Int], losers: [Int]) {
        self.winnerIndices = winnerIndices
        winners = winnerIndices.map { copies[$0] }
        self.losers = losers.sorted()
    }
}
