import Foundation

/// What the local buffer holds of the channel playing: from `start` to
/// `end`, the newest moment recorded, with the stretches where no data
/// came in.
public struct TimeshiftWindow: Sendable, Equatable {
    public var start: Date
    public var end: Date
    /// Stretches inside the window with no recording, oldest first.
    public var gaps: [DateInterval]
    /// Bytes on disk.
    public var bytes: Int

    public init(start: Date, end: Date, gaps: [DateInterval] = [], bytes: Int = 0) {
        self.start = start
        self.end = end
        self.gaps = gaps
        self.bytes = bytes
    }

    /// Seconds from `start` to `end`.
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    /// `date` moved inside the window.
    public func clamped(_ date: Date) -> Date {
        min(max(date, start), end)
    }
}

/// Something the buffer tells the player about once.
public enum TimeshiftEvent: Sendable, Equatable {
    /// The hour or the storage cap reached the point being read; playback
    /// goes on from the earliest point kept.
    case reachedReader
    /// Writing failed even after dropping the oldest part; recording stopped.
    /// `storageFull` is true when the device ran out of space.
    case writeFailed(storageFull: Bool)
    /// A recorded part could not be read back; recording stopped.
    case readFailed
}

/// One file of the buffer. Each starts at a point playback can start from.
struct TimeshiftChunk: Sendable, Equatable {
    /// Counts up from 0 within a buffer and names the file.
    let number: Int
    /// When its first byte was written.
    let start: Date
    /// When its last byte was written.
    var end: Date
    var bytes: Int
    /// True when recording stopped and started again just before it.
    let followsGap: Bool

    var fileName: String { "\(number).ts" }
}

/// The chunk list of one buffer and the rules for adding and dropping
/// chunks, kept apart from the files so the rules test on their own.
struct TimeshiftIndex: Sendable {
    let limits: TimeshiftLimits
    /// The most bytes kept: the cap, or less when the device is short.
    let byteCap: Int
    private(set) var chunks: [TimeshiftChunk] = []
    private var nextNumber = 0
    /// A recording stopped; the next chunk follows a gap.
    private var pendingGap = false
    /// Gaps inside one chunk: data stopped and came back on the same connection.
    private var stalls: [DateInterval] = []

    init(limits: TimeshiftLimits, byteCap: Int) {
        self.limits = limits
        self.byteCap = byteCap
    }

    /// Where bytes arriving at `date` go: a new chunk's number, the
    /// current chunk's number, or nil to drop them. Bytes before the first
    /// start point, and after a gap until the next one, are dropped.
    enum Placement: Equatable {
        case newChunk(Int)
        case append(Int)
        case drop
    }

    mutating func place(at date: Date, startPoint: Bool) -> Placement {
        guard let last = chunks.last, !pendingGap else {
            guard startPoint else { return .drop }
            return .newChunk(open(at: date))
        }
        if date.timeIntervalSince(last.end) > limits.gapThreshold { stalls.append(DateInterval(start: last.end, end: date)) }
        if startPoint, date.timeIntervalSince(last.start) >= limits.chunkSpacing {
            return .newChunk(open(at: date))
        }
        return .append(last.number)
    }

    /// Counts `count` bytes written to chunk `number` at `date`.
    mutating func wrote(_ count: Int, to number: Int, at date: Date) {
        guard let index = chunks.lastIndex(where: { $0.number == number }) else { return }
        chunks[index].bytes += count
        chunks[index].end = max(chunks[index].end, date)
    }

    private mutating func open(at date: Date) -> Int {
        let number = nextNumber
        nextNumber += 1
        chunks.append(TimeshiftChunk(number: number, start: date, end: date, bytes: 0, followsGap: pendingGap && !chunks.isEmpty))
        pendingGap = false
        return number
    }

    /// The recording stopped. Whatever comes next starts a new chunk at its first start point.
    mutating func markGap() {
        pendingGap = true
    }

    /// Drops chunks older than the window and, oldest first, chunks past the
    /// byte cap. The chunk being written is never dropped.
    mutating func evict(now: Date) -> [TimeshiftChunk] {
        var dropped: [TimeshiftChunk] = []
        let oldest = now.addingTimeInterval(-limits.window)
        while chunks.count > 1, let first = chunks.first, first.start < oldest || total > byteCap {
            dropped.append(chunks.removeFirst())
        }
        trimStalls()
        return dropped
    }

    /// Drops the oldest `share` of the chunks, at least one, keeping the newest.
    mutating func dropOldest(share: Double) -> [TimeshiftChunk] {
        let count = min(chunks.count - 1, max(1, Int((Double(chunks.count) * share).rounded(.up))))
        guard count > 0 else { return [] }
        let dropped = Array(chunks.prefix(count))
        chunks.removeFirst(count)
        trimStalls()
        return dropped
    }

    private mutating func trimStalls() {
        guard let start = chunks.first?.start else { return stalls.removeAll() }
        stalls.removeAll { $0.end <= start }
    }

    var total: Int { chunks.reduce(0) { $0 + $1.bytes } }

    /// What the buffer holds; nil before the first chunk.
    var window: TimeshiftWindow? {
        guard let first = chunks.first, let last = chunks.last else { return nil }
        var gaps = stalls
        for (previous, chunk) in zip(chunks, chunks.dropFirst()) where chunk.followsGap {
            gaps.append(DateInterval(start: previous.end, end: max(previous.end, chunk.start)))
        }
        return TimeshiftWindow(start: first.start, end: last.end, gaps: gaps.sorted { $0.start < $1.start }, bytes: total)
    }

    /// The chunk to start reading at for `date`: the last one starting at
    /// or before it, or the first one.
    func chunk(at date: Date) -> TimeshiftChunk? {
        chunks.last { $0.start <= date } ?? chunks.first
    }

    /// The newest chunk, where live playback reads.
    var newest: TimeshiftChunk? { chunks.last }

    /// The chunk after `number`, nil when it is the newest or gone.
    func chunk(after number: Int) -> TimeshiftChunk? {
        guard let index = chunks.firstIndex(where: { $0.number == number }), index + 1 < chunks.count else { return nil }
        return chunks[index + 1]
    }

    func chunk(numbered number: Int) -> TimeshiftChunk? {
        chunks.first { $0.number == number }
    }
}
