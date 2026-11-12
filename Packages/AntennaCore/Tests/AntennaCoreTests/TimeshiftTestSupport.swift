import Foundation

@testable import AntennaCore

/// A clock tests move by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_793_822_400)) {
        self.date = date
    }

    var now: Date { lock.withLock { date } }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(seconds) }
    }

    var reading: @Sendable () -> Date { { self.now } }
}

/// Hand-made MPEG-TS packets: a PAT naming a PMT on PID 0x100, a PMT with
/// H.264 video on 0x101 and AAC sound on 0x102, and video packets with or
/// without the random access flag.
enum TSPackets {
    static func packet(_ header: [UInt8], _ body: [UInt8]) -> Data {
        var bytes = header + body
        bytes += [UInt8](repeating: 0xFF, count: max(0, 188 - bytes.count))
        return Data(bytes.prefix(188))
    }

    static let pat = packet(
        [0x47, 0x40, 0x00, 0x10], [0x00, 0x00, 0xB0, 0x0D, 0x00, 0x01, 0xC1, 0x00, 0x00, 0x00, 0x01, 0xE1, 0x00, 0, 0, 0, 0])

    static let pmt = packet(
        [0x47, 0x41, 0x00, 0x10],
        [
            0x00, 0x02, 0xB0, 0x17, 0x00, 0x01, 0xC1, 0x00, 0x00, 0xE1, 0x01, 0xF0, 0x00, 0x1B, 0xE1, 0x01, 0xF0, 0x00, 0x0F, 0xE1, 0x02,
            0xF0, 0x00, 0, 0, 0, 0,
        ])

    /// A video packet starting a keyframe, marked with the random access flag.
    /// `tag` fills the payload so tests can tell packets apart.
    static func keyframe(_ tag: UInt8 = 0xAA) -> Data {
        packet(
            [0x47, 0x41, 0x01, 0x30, 0x01, 0x40],
            [0x00, 0x00, 0x01, 0xE0, 0x00, 0x00, 0x80, 0x00, 0x00] + [UInt8](repeating: tag, count: 170))
    }

    /// A video packet in the middle of a frame.
    static func middle(_ tag: UInt8 = 0xBB) -> Data {
        packet([0x47, 0x01, 0x01, 0x10], [UInt8](repeating: tag, count: 184))
    }

    /// The tables, then a keyframe and `following` middle packets.
    static func group(tag: UInt8, following: Int = 3) -> Data {
        var data = pat + pmt + keyframe(tag)
        for _ in 0..<following { data += middle(tag) }
        return data
    }
}

/// Files in memory that can fail on cue.
final class MemoryFiles: TimeshiftFiles, @unchecked Sendable {
    private let lock = NSLock()
    private var contents: [URL: Data] = [:]
    private var failWrites = 0
    private var writeError = TimeshiftFileError.noSpace
    private var failReads = false

    /// The next `count` appends throw `error`.
    func failNextWrites(_ count: Int, with error: TimeshiftFileError = .noSpace) {
        lock.withLock {
            failWrites = count
            writeError = error
        }
    }

    func failReadsFromNowOn() {
        lock.withLock { failReads = true }
    }

    var names: [String] { lock.withLock { contents.keys.map(\.lastPathComponent).sorted() } }

    func create(_ url: URL) throws {
        lock.withLock { contents[url] = Data() }
    }

    func append(_ data: Data, to url: URL) throws {
        try lock.withLock {
            if failWrites > 0 {
                failWrites -= 1
                throw writeError
            }
            contents[url, default: Data()].append(data)
        }
    }

    func read(_ url: URL, offset: Int, count: Int) throws -> Data {
        try lock.withLock {
            guard !failReads, let data = contents[url] else { throw TimeshiftFileError.failed }
            return Data(data.dropFirst(offset).prefix(count))
        }
    }

    func remove(_ url: URL) {
        lock.withLock { contents[url] = nil }
    }
}

/// Collects a buffer's events.
final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [TimeshiftEvent] = []

    var events: [TimeshiftEvent] { lock.withLock { list } }

    var handler: @Sendable (TimeshiftEvent) -> Void {
        { event in self.lock.withLock { self.list.append(event) } }
    }
}

extension TimeshiftReader {
    /// Everything readable now, up to `limit` bytes, in reads of 1000.
    func drain(limit: Int) -> (Data, Int) {
        var result = Data()
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 1000)
        defer { scratch.deallocate() }
        while result.count < limit {
            let count = read(into: scratch, count: min(1000, limit - result.count))
            guard count > 0 else { return (result, count) }
            result.append(scratch, count: count)
        }
        return (result, 1)
    }
}
