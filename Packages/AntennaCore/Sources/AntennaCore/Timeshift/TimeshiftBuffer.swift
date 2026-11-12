import Foundation

/// The local recording of the channel playing: chunk files in one session
/// folder, written by the recording thread and read back by the demuxing
/// thread (timeshift-catch-up-and-start-over capability).
///
/// Each chunk starts at a point playback can start from, with the stream's
/// PAT and PMT packets before its first keyframe; bytes before the first
/// such point are not kept. Chunks older than `TimeshiftLimits.window`, and
/// the oldest ones past the byte cap, are deleted as new bytes arrive. When
/// that reaches a chunk a reader is on, `onEvent` gets `.reachedReader`.
///
/// A failed write drops the oldest tenth of the recording and tries once
/// more; when that fails too, recording stops and `onEvent` gets
/// `.writeFailed`. Readers block while they wait for bytes, so read only
/// from a thread of your own, never the main actor. File names count up
/// from 0 and never come from the channel or its address.
public final class TimeshiftBuffer: @unchecked Sendable {
    public let directory: URL
    private let files: any TimeshiftFiles
    private let now: @Sendable () -> Date
    private let condition = NSCondition()
    private var index: TimeshiftIndex
    private var finished = false
    private var failed = false
    private var pins: [UUID: Int] = [:]
    private var handler: (@Sendable (TimeshiftEvent) -> Void)?

    /// `byteCap` is the most bytes kept: `TimeshiftLimits.usableBytes(free:)`
    /// for this device at tune time. `now` stamps each write.
    public init(
        directory: URL, limits: TimeshiftLimits, byteCap: Int, files: any TimeshiftFiles = DiskTimeshiftFiles(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.files = files
        self.now = now
        index = TimeshiftIndex(limits: limits, byteCap: byteCap)
    }

    /// Told once about each event, on the thread that caused it.
    public var onEvent: (@Sendable (TimeshiftEvent) -> Void)? {
        get { condition.withLock { handler } }
        set { condition.withLock { handler = newValue } }
    }

    /// What the buffer holds; nil until the first start point is written.
    public var window: TimeshiftWindow? {
        condition.withLock { index.window }
    }

    /// False once recording stopped for good: after `finish()` or a failed write.
    public var isRecording: Bool {
        condition.withLock { !finished }
    }

    /// True after a write failed for good.
    public var hasFailed: Bool {
        condition.withLock { failed }
    }

    /// Where a reader for `date` starts: the start of the chunk holding it.
    public func startPoint(for date: Date) -> Date? {
        condition.withLock { index.chunk(at: date)?.start }
    }

    // MARK: Writing

    /// Adds the runs of a scanned stream. A run that is a start point can
    /// begin a new chunk, written after `pat` and `pmt`.
    public func record(_ runs: [TSStartPoints.Run], pat: Data?, pmt: Data?) {
        for run in runs {
            guard record(run, pat: pat, pmt: pmt) else { return }
        }
    }

    private func record(_ run: TSStartPoints.Run, pat: Data?, pmt: Data?) -> Bool {
        let date = now()
        var event: TimeshiftEvent?
        defer { if let event { send(event) } }
        condition.lock()
        defer { condition.unlock() }
        guard !finished else { return false }
        let placement = index.place(at: date, startPoint: run.startPoint)
        var bytes = run.bytes
        let number: Int
        switch placement {
        case .drop:
            return true
        case .newChunk(let new):
            number = new
            bytes = (pat ?? Data()) + (pmt ?? Data()) + run.bytes
        case .append(let current):
            number = current
        }
        let url = directory.appending(path: "\(number).ts")
        do {
            try write(bytes, to: url, creating: placement != .append(number))
        } catch {
            for chunk in index.dropOldest(share: index.limits.dropOnWriteFailure) {
                files.remove(directory.appending(path: chunk.fileName))
            }
            do {
                try write(bytes, to: url, creating: placement != .append(number))
            } catch {
                finished = true
                failed = true
                condition.broadcast()
                event = .writeFailed(storageFull: (error as? TimeshiftFileError) == .noSpace)
                return false
            }
        }
        index.wrote(bytes.count, to: number, at: date)
        let dropped = index.evict(now: date)
        for chunk in dropped {
            files.remove(directory.appending(path: chunk.fileName))
        }
        if dropped.contains(where: { chunk in pins.values.contains(chunk.number) }) { event = .reachedReader }
        condition.broadcast()
        return true
    }

    private func write(_ bytes: Data, to url: URL, creating: Bool) throws {
        if creating { try files.create(url) }
        try files.append(bytes, to: url)
    }

    /// The stream stopped and may come back. What comes next starts a new
    /// chunk at its first start point, and the time between shows as a gap.
    public func markGap() {
        condition.withLock { index.markGap() }
    }

    /// No more bytes come. Readers at the end of the recording read 0.
    public func finish() {
        condition.withLock {
            finished = true
            condition.broadcast()
        }
    }

    private func send(_ event: TimeshiftEvent) {
        let handler = condition.withLock { self.handler }
        handler?(event)
    }

    // MARK: Reading

    /// A reader from the chunk holding `date`, or from the newest chunk for
    /// nil. Nil while the buffer holds nothing.
    public func reader(at date: Date?) -> TimeshiftReader? {
        condition.withLock {
            guard let chunk = date.flatMap(index.chunk(at:)) ?? index.newest else { return nil }
            let id = UUID()
            pins[id] = chunk.number
            return TimeshiftReader(buffer: self, id: id, chunk: chunk.number, start: chunk.start)
        }
    }

    /// What one `read` of a reader found.
    enum Step {
        case bytes(Data)
        /// The end of the recording, a gap, or the chunk was dropped.
        case stop(TimeshiftReader.Stop)
        case failed
        case cancelled
    }

    /// Up to `count` bytes for the reader `id` at chunk `number`, `offset`;
    /// waits for bytes at the newest chunk while recording goes on.
    func next(id: UUID, chunk number: inout Int, offset: inout Int, count: Int, cancelled: () -> Bool) -> Step {
        condition.lock()
        while true {
            if cancelled() {
                condition.unlock()
                return .cancelled
            }
            guard let chunk = index.chunk(numbered: number) else {
                condition.unlock()
                return .stop(.dropped)
            }
            if offset < chunk.bytes {
                let take = min(count, chunk.bytes - offset)
                let url = directory.appending(path: chunk.fileName)
                condition.unlock()
                if let data = try? files.read(url, offset: offset, count: take), !data.isEmpty {
                    offset += data.count
                    return .bytes(data)
                }
                // The chunk can go between the check and the read.
                let gone = condition.withLock { index.chunk(numbered: number) == nil }
                if gone { return .stop(.dropped) }
                condition.withLock {
                    finished = true
                    failed = true
                    condition.broadcast()
                }
                send(.readFailed)
                return .failed
            }
            if let following = index.chunk(after: number) {
                if following.followsGap {
                    condition.unlock()
                    return .stop(.gap)
                }
                number = following.number
                offset = 0
                pins[id] = number
                continue
            }
            if finished {
                condition.unlock()
                return .stop(.end)
            }
            condition.wait()
        }
    }

    func unpin(_ id: UUID) {
        condition.withLock {
            pins[id] = nil
            condition.broadcast()
        }
    }

    /// Wakes every waiting reader so it can see it was cancelled.
    func wake() {
        condition.withLock { condition.broadcast() }
    }
}

/// Reads a buffer's chunks in order from where it was made, as one byte
/// stream. `read` blocks; call it from the demuxing thread.
public final class TimeshiftReader: @unchecked Sendable {
    /// Why reading stopped without a failure.
    public enum Stop: Sendable, Equatable {
        /// The recording finished and every byte was read.
        case end
        /// The next chunk follows a gap in the recording.
        case gap
        /// The chunk being read was dropped by the hour or the storage cap.
        case dropped
    }

    private let buffer: TimeshiftBuffer
    private let id: UUID
    private let lock = NSLock()
    private var chunk: Int
    private var offset = 0
    private var cancelled = false
    private var stop: Stop?
    private var failed = false
    /// When the chunk the reader started at began recording.
    public let start: Date

    init(buffer: TimeshiftBuffer, id: UUID, chunk: Int, start: Date) {
        self.buffer = buffer
        self.id = id
        self.chunk = chunk
        self.start = start
    }

    deinit {
        buffer.unpin(id)
    }

    /// Copies up to `count` bytes into `destination`. Returns how many, 0
    /// when reading stopped (`stopped` says why), or -1 when the read failed
    /// or the reader was cancelled.
    public func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        var number = lock.withLock { chunk }
        var at = lock.withLock { offset }
        let step = buffer.next(id: id, chunk: &number, offset: &at, count: count) { [lock] in lock.withLock { cancelled } }
        lock.withLock {
            chunk = number
            offset = at
        }
        switch step {
        case .bytes(let data):
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.assumingMemoryBound(to: UInt8.self), count: data.count)
            }
            return data.count
        case .stop(let reason):
            lock.withLock { stop = reason }
            return 0
        case .failed:
            lock.withLock { failed = true }
            return -1
        case .cancelled:
            return -1
        }
    }

    /// Why the last read returned 0, nil before that.
    public var stopped: Stop? { lock.withLock { stop } }

    /// True after a read failed.
    public var hasFailed: Bool { lock.withLock { failed } }

    /// Stops reading; a blocked `read` returns -1.
    public func cancel() {
        lock.withLock { cancelled = true }
        buffer.wake()
        buffer.unpin(id)
    }
}
