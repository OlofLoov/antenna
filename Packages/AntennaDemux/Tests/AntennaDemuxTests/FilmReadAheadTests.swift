import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// A film from a server faster than playback: what is read ahead goes to a
/// file in Caches and memory stays where it was. The 4K episode that
/// filled 2.2 GB in ten minutes on Apple TV did not.
@Suite(.serialized, .timeLimit(.minutes(2))) struct FilmReadAheadTests {
    @Test(
        "playback-engine/films-read-ahead-to-disk a film reads through a ring on disk in order, never further ahead than it holds"
    )
    func readsThroughTheRing() async throws {
        let harness = try await RingHarness(length: 48 << 20)
        let film = try #require(harness.film)
        #expect(film.capacity == 4 << 20)
        let reader = film.reader()
        var offset = 0
        var largestAhead = 0
        try harness.check(reader, from: &offset, count: 48 << 20) { largestAhead = max(largestAhead, film.heldAhead) }
        #expect(reader.read(into: harness.scratch, count: 1) == 0)
        #expect(largestAhead <= film.capacity)
        #expect(try harness.diskBytes() <= film.capacity)
        // One request per refill of about a megabyte, not one per read.
        #expect(film.requests < 80, "\(film.requests) requests")
        film.discard()
        #expect(await eventually { (try? harness.diskBytes()) == 0 })
        await harness.stop()
    }

    @Test("playback-engine/films-read-ahead-to-disk a skip within the bytes held reads no network; one outside moves the ring there")
    func skipsWithinAndOutside() async throws {
        let harness = try await RingHarness(length: 48 << 20)
        let film = try #require(harness.film)
        let reader = film.reader()
        var offset = 0
        try harness.check(reader, from: &offset, count: 10 << 20)
        #expect(await eventually { film.heldAhead >= 2 << 20 }, "ahead \(film.heldAhead), held \(film.held), offset \(offset)")
        let asked = await harness.server.requests(for: "/film.mkv").count
        offset -= 1 << 20
        #expect(reader.seek(to: offset))
        try harness.check(reader, from: &offset, count: 512 << 10)
        #expect(await harness.server.requests(for: "/film.mkv").count == asked)

        offset = 40 << 20
        #expect(reader.seek(to: offset))
        try harness.check(reader, from: &offset, count: 3 << 20)
        #expect(await eventually { film.held.lowerBound >= 40 << 20 }, "held \(film.held)")
        film.discard()
        await harness.stop()
    }

    @Test("playback-engine/films-read-ahead-to-disk with too little free space a film plays from its connection")
    func tooLittleSpace() async throws {
        let harness = try await RingHarness(length: 8 << 20, keepFree: Int.max / 2)
        #expect(harness.film == nil)
        #expect(try harness.diskBytes() == 0)
        await harness.stop()
    }

    /// The read-ahead waits while FFmpeg is ahead, so a paused film's
    /// connection can time out; it is opened again where it stopped.
    @Test("playback-engine/films-keep-memory-steady a film's connection that drops partway goes on at the byte it stopped at")
    func connectionDropsPartway() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let url = base.appending(path: "film.mkv")
        await server.script("/film.mkv", .cut(afterBytes: 100_000))
        let session = PlaybackNetwork.makeStreamingSession()
        defer { session.invalidateAndCancel() }
        let first = HTTPByteStream(url: url, session: session, asksForRange: true)
        try await first.open()
        let source = SeekableSource(first, url: url, session: session)
        let expected = try Data(contentsOf: FixtureServer.fixtures().appending(path: "film.mkv"))
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 << 10)
        defer { scratch.deallocate() }
        var read = Data()
        while case let taken = source.read(into: scratch, count: 64 << 10), taken > 0 {
            read.append(scratch, count: taken)
        }
        #expect(read == expected, "read \(read.count) of \(expected.count), \(String(describing: source.failureReason))")
        #expect(await server.requests(for: "/film.mkv").count == 2)
        await server.stop()
    }
}

extension DemuxMemoryTests {
    /// Before the fix a connection let URLSession deliver the whole body
    /// once it had been paused and resumed: a gigabyte in a second here.
    /// What the connection holds is measured after every read, not the
    /// process, which other suites share. The reader goes by bytes, not
    /// time, so a slow runner only takes longer.
    @Test("playback-engine/films-keep-memory-steady a film from a connection faster than its reader holds tens of megabytes at most")
    func connectionFasterThanItsReader() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.always("/film.mkv", .generated(length: 1 << 30))
        let session = PlaybackNetwork.makeStreamingSession()
        defer { session.invalidateAndCancel() }
        let url = base.appending(path: "film.mkv")
        let first = HTTPByteStream(url: url, session: session, asksForRange: true)
        try await first.open()
        let stream = SeekableSource(first, url: url, session: session)
        let goal = HTTPByteStream.overflowLimit + (16 << 20)
        let reader = SlowReader(stream, goal: goal)
        reader.start()
        let finished = await reader.finish(within: .seconds(90))
        stream.cancel()
        reader.join()
        let most = reader.mostHeld
        #expect(finished, "read \(reader.read >> 20) MB of \(goal >> 20) MB")
        // Whether URLSession went past the overflow, and the connection was
        // opened again, depends on the runner; the bytes are right either way.
        #expect(reader.read >= goal, "read \(reader.read >> 20) MB")
        #expect(reader.wrongByte == nil)
        #expect(most <= HTTPByteStream.overflowLimit + (4 << 20), "held \(most >> 20) MB while reading \(reader.read >> 20) MB")
        await server.stop()
    }
}

/// The engine keeps a film's read-ahead over skips and lets it go on stop.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct FilmReadAheadEngineTests {
    @Test("playback-engine/films-read-ahead-to-disk a skip within a film read ahead asks the server for nothing, stop deletes the file")
    func skipNeedsNoNetwork() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let folder = FileManager.default.temporaryDirectory.appending(path: "film-engine-\(UUID().uuidString)")
        let store = TimeshiftStore(root: folder)
        let engine = DemuxEngine(sleep: { _ in })
        engine.filmLimits.store = store
        engine.filmLimits.keepFree = 0
        try await engine.load(base.appending(path: "channel.mkv"), options: PlaybackOptions(isLive: false))
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        let film = try #require(engine.film)
        #expect(await eventually { film.held.upperBound == film.length })
        let asked = await server.requests(for: "/channel.mkv").count
        try await engine.seek(to: .seconds(4))
        #expect(await eventually { engine.state == .playing })
        try await engine.seek(to: .seconds(1))
        #expect(await eventually { engine.state == .playing })
        #expect(await server.requests(for: "/channel.mkv").count == asked)
        #expect(engine.film === film)
        await engine.stop()
        #expect(engine.film == nil)
        #expect(await eventually { RingHarness.bytes(under: folder) == 0 })
        await server.stop()
        try? FileManager.default.removeItem(at: folder)
    }
}

/// A read-ahead with a 4 MB ring over a generated film on the fixture server.
private final class RingHarness: @unchecked Sendable {
    let server: FixtureServer
    let session: URLSession
    let folder: URL
    let film: FilmReadAhead?
    let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 << 10)

    init(length: Int, keepFree: Int = 0) async throws {
        server = try FixtureServer()
        let base = try await server.start()
        await server.always("/film.mkv", .generated(length: length))
        session = PlaybackNetwork.makeStreamingSession()
        folder = FileManager.default.temporaryDirectory.appending(path: "film-ring-\(UUID().uuidString)")
        let url = base.appending(path: "film.mkv")
        let first = HTTPByteStream(url: url, session: session, asksForRange: true)
        try await first.open()
        var limits = FilmReadAhead.Limits()
        limits.largest = 4 << 20
        limits.smallest = 1 << 20
        limits.keepFree = keepFree
        limits.chunk = 64 << 10
        limits.unknownRateAhead = 2 << 20
        limits.pinned = 512 << 10
        limits.adoptAfter = 1 << 20
        limits.forwardWait = 1 << 20
        limits.store = TimeshiftStore(root: folder)
        film = FilmReadAhead.make(first, url: url, session: session, limits: limits)
        if film == nil { first.cancel() }
    }

    /// Reads `count` bytes from `offset` on and checks each is the generated one.
    func check(_ reader: FilmReader, from offset: inout Int, count: Int, each: () -> Void = {}) throws {
        let end = offset + count
        while offset < end {
            let taken = reader.read(into: scratch, count: min(64 << 10, end - offset))
            try #require(taken > 0, "read \(taken) at \(offset)")
            guard Data(bytes: scratch, count: taken) == FixtureServer.generated(from: offset, count: taken) else {
                Issue.record("wrong bytes from \(offset)")
                return
            }
            offset += taken
            each()
        }
    }

    func diskBytes() throws -> Int { Self.bytes(under: folder) }

    /// Bytes the files under `folder` take on disk.
    static func bytes(under folder: URL) -> Int {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
        return (files?.allObjects as? [URL] ?? []).reduce(0) {
            $0 + ((try? $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
    }

    func stop() async {
        film?.discard()
        session.invalidateAndCancel()
        await server.stop()
        scratch.deallocate()
        try? FileManager.default.removeItem(at: folder)
    }
}

/// Reads a film until `goal` bytes, checks each byte against the generated
/// film, and notes the most the connection held after each read. Past 8 MB,
/// when the download has been paused and resumed, it stops until the
/// connection holds `overflowLimit` or stops growing, and half a second
/// more, however slow the runner.
private final class SlowReader: @unchecked Sendable {
    private let stream: SeekableSource
    private let goal: Int
    private let lock = NSLock()
    private let done = DispatchSemaphore(value: 0)
    private var total = 0
    private var wrong: Int?
    private var most = 0
    private var ended = false

    init(_ stream: SeekableSource, goal: Int) {
        self.stream = stream
        self.goal = goal
    }

    var read: Int { lock.withLock { total } }
    var wrongByte: Int? { lock.withLock { wrong } }
    var mostHeld: Int { lock.withLock { most } }

    /// Waits until the reader stopped, true when it did within `limit`.
    func finish(within limit: Duration) async -> Bool {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if lock.withLock({ ended }) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    func start() {
        Thread { [self] in
            let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 << 10)
            defer {
                scratch.deallocate()
                lock.withLock { ended = true }
                done.signal()
            }
            var offset = 0
            while offset < goal, case let taken = stream.read(into: scratch, count: 64 << 10), taken > 0 {
                if wrongByte == nil, Data(bytes: scratch, count: taken) != FixtureServer.generated(from: offset, count: taken) {
                    lock.withLock { wrong = offset }
                }
                offset += taken
                if offset >= 8 << 20, offset - taken < 8 << 20 { waitUntilFull() }
                let held = stream.heldBytes
                lock.withLock {
                    total = offset
                    most = max(most, held)
                }
                Thread.sleep(forTimeInterval: 0.002)
            }
        }.start()
    }

    func join() { done.wait() }

    /// Waits until the connection holds `overflowLimit` or stops growing.
    private func waitUntilFull() {
        let deadline = Date(timeIntervalSinceNow: 30)
        var last = -1
        while case let held = stream.heldBytes, held < HTTPByteStream.overflowLimit, held != last, Date() < deadline {
            last = held
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 0.5)
    }
}
