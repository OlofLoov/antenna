import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaCore

/// The buffer on a simulated clock, with files in memory.
@Suite struct TimeshiftBufferTests {
    static let folder = URL(filePath: "/buffer", directoryHint: .isDirectory)

    static func buffer(
        _ clock: TestClock, files: MemoryFiles = MemoryFiles(), cap: Int = 1 << 30, configure: (inout TimeshiftLimits) -> Void = { _ in }
    ) -> TimeshiftBuffer {
        var limits = TimeshiftLimits.standard(for: .tv)
        configure(&limits)
        return TimeshiftBuffer(directory: folder, limits: limits, byteCap: cap, files: files, now: clock.reading)
    }

    /// Scans `data` and records it.
    static func feed(_ buffer: TimeshiftBuffer, _ scanner: inout TSStartPoints, _ data: Data) {
        let runs = scanner.scan(data)
        buffer.record(runs, pat: scanner.pat, pmt: scanner.pmt)
    }

    // MARK: Start points

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: start points are found across any split")
    func startPointsAcrossSplits() {
        let stream = TSPackets.middle() + TSPackets.group(tag: 1) + TSPackets.group(tag: 2)
        var whole = TSStartPoints()
        let runs = whole.scan(stream)
        #expect(runs.map(\.startPoint) == [false, true, true])
        var pieces = TSStartPoints()
        var split: [TSStartPoints.Run] = []
        for offset in stride(from: 0, to: stream.count, by: 100) {
            split += pieces.scan(stream.subdata(in: offset..<min(stream.count, offset + 100)))
        }
        #expect(split.filter(\.startPoint).count == 2)
        #expect(split.reduce(0) { $0 + $1.bytes.count } == stream.count)
        #expect(pieces.pat == TSPackets.pat)
        #expect(pieces.pmt == TSPackets.pmt)
    }

    @Test(
        "timeshift-catch-up-and-start-over/when-the-buffer-runs-out: keyframes of real streams are start points",
        arguments: ["channel.ts", "mpeg2.ts"])
    func fixtureStartPoints(name: String) throws {
        let data = try Data(contentsOf: try FixtureServer.fixtures().appending(path: name))
        var scanner = TSStartPoints()
        let points = scanner.scan(data).filter(\.startPoint).count
        // Six seconds with a keyframe every second.
        #expect(points >= 5)
        #expect(points <= 12)
    }

    // MARK: Writing only at start points

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: bytes before the first start point are not kept")
    func writesOnlyAtStartPoints() throws {
        let clock = TestClock()
        let files = MemoryFiles()
        let buffer = Self.buffer(clock, files: files)
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.pat + TSPackets.pmt + TSPackets.middle(9))
        #expect(buffer.window == nil)
        Self.feed(buffer, &scanner, TSPackets.keyframe(1) + TSPackets.middle(1))
        #expect(buffer.window?.bytes == 4 * 188)
        let reader = try #require(buffer.reader(at: nil))
        buffer.finish()
        let (data, last) = reader.drain(limit: 10_000)
        #expect(last == 0)
        #expect(reader.stopped == .end)
        // The tables come first, then the keyframe.
        #expect(data == TSPackets.pat + TSPackets.pmt + TSPackets.keyframe(1) + TSPackets.middle(1))
        #expect(files.names == ["0.ts"])
    }

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: chunks start at least a second apart and read in order")
    func chunksReadInOrder() throws {
        let clock = TestClock()
        let buffer = Self.buffer(clock)
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        clock.advance(0.5)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 2))
        clock.advance(1)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 3))
        let start = try #require(buffer.window?.start)
        let reader = try #require(buffer.reader(at: start))
        buffer.finish()
        let (data, _) = reader.drain(limit: 100_000)
        // The second group joins the first chunk. The tables before the third end the first chunk, and the third chunk starts with them again.
        #expect(data == TSPackets.group(tag: 1) + TSPackets.group(tag: 2) + TSPackets.pat + TSPackets.pmt + TSPackets.group(tag: 3))
    }

    // MARK: The hour and the cap

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: the window holds an hour at most")
    func holdsAnHour() throws {
        let clock = TestClock()
        let begin = clock.now
        let buffer = Self.buffer(clock)
        var scanner = TSStartPoints()
        for second in 0..<(2 * 3600) {
            Self.feed(buffer, &scanner, TSPackets.group(tag: UInt8(second % 200)))
            clock.advance(1)
        }
        let window = try #require(buffer.window)
        #expect(window.duration <= 3600)
        #expect(window.duration >= 3590)
        #expect(window.start >= clock.now.addingTimeInterval(-3601))
        #expect(window.start > begin)
    }

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: the storage cap drops the oldest chunks")
    func storageCap() throws {
        let clock = TestClock()
        let files = MemoryFiles()
        let group = TSPackets.group(tag: 1).count + 2 * 188
        let buffer = Self.buffer(clock, files: files, cap: 10 * group)
        var scanner = TSStartPoints()
        for second in 0..<30 {
            Self.feed(buffer, &scanner, TSPackets.group(tag: UInt8(second)))
            clock.advance(1)
        }
        let window = try #require(buffer.window)
        #expect(window.bytes <= 10 * group)
        #expect(files.names.count <= 10)
        #expect(window.duration < 12)
    }

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: a pause outlasting the hour reaches the reader once")
    func reachesPausedReader() throws {
        let clock = TestClock()
        let log = EventLog()
        let buffer = Self.buffer(clock)
        buffer.onEvent = log.handler
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        let paused = try #require(buffer.reader(at: nil))
        for second in 1...3601 {
            clock.advance(1)
            Self.feed(buffer, &scanner, TSPackets.group(tag: UInt8(second % 200)))
        }
        #expect(log.events == [.reachedReader])
        let (_, last) = paused.drain(limit: 1000)
        #expect(last == 0)
        #expect(paused.stopped == .dropped)
        // A reader made now starts at the earliest point kept.
        let earliest = try #require(buffer.window?.start)
        #expect(buffer.reader(at: .distantPast)?.start == earliest)
    }

    // MARK: Gaps

    @Test("timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off: a stall shows as a gap in one buffer")
    func stallGap() throws {
        let clock = TestClock()
        let buffer = Self.buffer(clock)
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        clock.advance(1)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 2))
        buffer.markGap()
        clock.advance(30)
        // A new connection: its first bytes before a keyframe are dropped.
        var next = TSStartPoints()
        Self.feed(buffer, &next, TSPackets.middle(7) + TSPackets.group(tag: 3))
        let window = try #require(buffer.window)
        #expect(window.gaps.count == 1)
        #expect(window.gaps.first?.duration == 30)
        let reader = try #require(buffer.reader(at: window.start))
        _ = reader.drain(limit: 100_000)
        #expect(reader.stopped == .gap)
        // A reader at the far side of the gap goes on.
        let after = try #require(buffer.reader(at: window.end))
        buffer.finish()
        #expect(after.drain(limit: 100_000).0 == TSPackets.group(tag: 3))
    }

    // MARK: Blocking reads

    @Test("timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off: a reader at live waits for new bytes")
    func readerWaits() async throws {
        let clock = TestClock()
        let buffer = Self.buffer(clock)
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        let reader = try #require(buffer.reader(at: nil))
        _ = reader.drain(limit: TSPackets.group(tag: 1).count)
        let more = Task.detached { reader.drain(limit: 188).0 }
        try await Task.sleep(for: .milliseconds(50))
        Self.feed(buffer, &scanner, TSPackets.middle(5))
        #expect(await more.value == TSPackets.middle(5))
        let cancelled = Task.detached { reader.drain(limit: 188).1 }
        try await Task.sleep(for: .milliseconds(50))
        reader.cancel()
        #expect(await cancelled.value == -1)
    }

    // MARK: Failures

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: a failed write drops the oldest tenth and tries once more")
    func writeRetry() throws {
        let clock = TestClock()
        let files = MemoryFiles()
        let log = EventLog()
        let buffer = Self.buffer(clock, files: files)
        buffer.onEvent = log.handler
        var scanner = TSStartPoints()
        for second in 0..<20 {
            Self.feed(buffer, &scanner, TSPackets.group(tag: UInt8(second)))
            clock.advance(1)
        }
        files.failNextWrites(1)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 99))
        #expect(log.events.isEmpty)
        #expect(buffer.isRecording)
        #expect(files.names.count == 19)

        files.failNextWrites(2)
        clock.advance(1)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 100))
        #expect(log.events == [.writeFailed(storageFull: true)])
        #expect(!buffer.isRecording)
        #expect(buffer.hasFailed)
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: a failed write that is not about space")
    func writeFailedOther() {
        let clock = TestClock()
        let files = MemoryFiles()
        let log = EventLog()
        let buffer = Self.buffer(clock, files: files)
        buffer.onEvent = log.handler
        var scanner = TSStartPoints()
        files.failNextWrites(2, with: .failed)
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        #expect(log.events == [.writeFailed(storageFull: false)])
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: a failed read stops the recording once")
    func readFailure() throws {
        let clock = TestClock()
        let files = MemoryFiles()
        let log = EventLog()
        let buffer = Self.buffer(clock, files: files)
        buffer.onEvent = log.handler
        var scanner = TSStartPoints()
        Self.feed(buffer, &scanner, TSPackets.group(tag: 1))
        let reader = try #require(buffer.reader(at: nil))
        files.failReadsFromNowOn()
        #expect(reader.drain(limit: 1000).1 == -1)
        #expect(reader.hasFailed)
        #expect(log.events == [.readFailed])
        #expect(!buffer.isRecording)
    }

    // MARK: Limits

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: too little free storage records nothing")
    func usableBytes() {
        let tv = TimeshiftLimits.standard(for: .tv)
        let phone = TimeshiftLimits.standard(for: .phone)
        #expect(tv.byteCap == 4 << 30)
        #expect(TimeshiftLimits.standard(for: .mac).byteCap == 4 << 30)
        #expect(phone.byteCap == 2 << 30)
        #expect(TimeshiftLimits.standard(for: .pad).byteCap == 2 << 30)
        #expect(tv.usableBytes(free: 100 << 30) == 4 << 30)
        #expect(tv.usableBytes(free: (1 << 30) + (500 << 20)) == 500 << 20)
        #expect(tv.usableBytes(free: (1 << 30) + (63 << 20)) == nil)
        #expect(tv.usableBytes(free: 0) == nil)
    }
}
