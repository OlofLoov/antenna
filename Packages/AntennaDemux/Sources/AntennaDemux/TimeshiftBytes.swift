import AntennaCore
import Foundation

/// The bytes a `DemuxRun` reads: a connection to the provider, or the local
/// buffer. Every method but `cancel` blocks; call them from the demuxing thread.
protocol DemuxBytes: AnyObject, Sendable {
    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int
    /// Up to `count` bytes from the read position, without taking them.
    func peek(_ count: Int) -> Data
    var failureReason: PlaybackFailure? { get }
    var canSeek: Bool { get }
    var length: Int? { get }
    var position: Int { get }
    func seek(to target: Int) -> Bool
    func cancel()
}

/// A buffer reader as the bytes of a run. It cannot seek; the engine moves
/// in time by starting a new run on a new reader.
final class TimeshiftBytes: DemuxBytes, @unchecked Sendable {
    let reader: TimeshiftReader
    private let lock = NSLock()
    private var peeked = Data()
    private var taken = 0

    init(_ reader: TimeshiftReader) {
        self.reader = reader
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let held = lock.withLock { () -> Data in
            let part = peeked.prefix(count)
            peeked.removeFirst(part.count)
            return Data(part)
        }
        if !held.isEmpty {
            held.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.assumingMemoryBound(to: UInt8.self), count: held.count)
            }
            lock.withLock { taken += held.count }
            return held.count
        }
        let count = reader.read(into: destination, count: count)
        if count > 0 { lock.withLock { taken += count } }
        return count
    }

    func peek(_ count: Int) -> Data {
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { scratch.deallocate() }
        while lock.withLock({ peeked.count }) < count {
            let needed = count - lock.withLock { peeked.count }
            let got = reader.read(into: scratch, count: needed)
            guard got > 0 else { break }
            lock.withLock { peeked.append(scratch, count: got) }
        }
        return lock.withLock { Data(peeked.prefix(count)) }
    }

    var failureReason: PlaybackFailure? {
        reader.hasFailed ? .unreadable : nil
    }

    var canSeek: Bool { false }
    var length: Int? { nil }
    var position: Int { lock.withLock { taken } }

    func seek(to target: Int) -> Bool {
        target == position
    }

    func cancel() {
        reader.cancel()
    }
}

/// Pulls a live stream from its connection into a buffer on a thread of
/// its own, until the bytes end, fail or `cancel` is called.
///
/// Before it takes any bytes it looks at the first ones: a stream that is
/// not MPEG-TS is left untouched, so the engine can play it straight from
/// the connection. A stream with no point to start from in its first
/// `searchLimit` bytes cannot be recorded either, and its connection closes.
final class TimeshiftRecorder: @unchecked Sendable {
    /// What the recorder found at the start of the stream.
    enum Check: Sendable, Equatable {
        /// Recording started at a start point.
        case recording
        /// Not MPEG-TS; nothing was taken from the connection.
        case untouched
        /// Bytes were taken and no start point came, or it was cancelled first.
        case consumed
    }

    let bytes: HTTPByteStream
    private let buffer: TimeshiftBuffer
    private let lock = NSLock()
    private var cancelled = false
    /// How far into a stream a start point must turn up.
    static let searchLimit = 8 * 1024 * 1024

    init(bytes: HTTPByteStream, buffer: TimeshiftBuffer) {
        self.bytes = bytes
        self.buffer = buffer
    }

    /// Starts the thread. `checked` is called once with what the start of
    /// the stream showed. `ended` is called after `.recording` when the
    /// bytes stop, with why, unless cancelled.
    func start(checked: @escaping @Sendable (Check) -> Void, ended: @escaping @Sendable (PlaybackFailure?) -> Void) {
        let thread = Thread { [self] in
            run(checked: checked, ended: ended)
        }
        thread.name = "se.codecrave.antenna.timeshift"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    func cancel() {
        lock.withLock { cancelled = true }
        bytes.cancel()
    }

    private var isCancelled: Bool { lock.withLock { cancelled } }

    private func run(checked: @escaping @Sendable (Check) -> Void, ended: @escaping @Sendable (PlaybackFailure?) -> Void) {
        guard StreamSniff(bytes.peek(512)) == .mpegTS else { return checked(isCancelled ? .consumed : .untouched) }
        var scanner = TSStartPoints()
        var answered = false
        var searched = 0
        let size = 64 * 1024
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { scratch.deallocate() }
        while !isCancelled {
            let count = bytes.read(into: scratch, count: size)
            guard count > 0 else { break }
            let runs = scanner.scan(Data(bytes: scratch, count: count))
            buffer.record(runs, pat: scanner.pat, pmt: scanner.pmt)
            if !answered {
                searched += count
                if runs.contains(where: \.startPoint) {
                    answered = true
                    checked(.recording)
                } else if searched > Self.searchLimit {
                    bytes.cancel()
                    return checked(.consumed)
                }
            }
        }
        guard answered else { return checked(.consumed) }
        guard !isCancelled else { return }
        ended(bytes.failureReason)
    }
}
