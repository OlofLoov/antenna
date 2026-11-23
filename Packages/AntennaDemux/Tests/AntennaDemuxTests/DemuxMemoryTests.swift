@preconcurrency import AVFoundation
import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// Memory over a long live stream: what the run and the connection are
/// done with is let go while the stream plays on, not when it ends.
@Suite(.serialized) struct DemuxMemoryTests {
    /// Every read of these bytes autoreleases an object, as reading back
    /// the local buffer does through Foundation and as the deinterlacer's
    /// Metal calls do for each picture. Before the run drained its pool per
    /// packet, every one of them lived until the channel changed: each read
    /// of the buffer held its bytes, and each 1080i or 576i picture about
    /// 1.4 KB of the GPU's bookkeeping.
    @Test(
        "playback-engine/live-playback-keeps-memory-steady what a run autoreleases for a packet is let go while live TV plays"
    )
    func autoreleasedPerPacketIsLetGo() async throws {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: "channel.ts"))
        let bytes = EndlessBytes(data, readSize: 4096)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        let clock = try #require(timebase)
        let run = DemuxRun(
            bytes: bytes, videoFeed: SampleFeed(renderer: TakingRenderer(timebase: clock), label: "memory.video", limit: 8),
            audioFeed: SampleFeed(renderer: TakingRenderer(timebase: clock), label: "memory.audio", limit: 64))
        run.start(ready: { _ in }, options: PlaybackOptions(isLive: true), ended: { _ in })
        defer { run.cancel() }

        let deadline = ContinuousClock.now + .seconds(120)
        while bytes.tally.made < 3000, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let (made, alive) = bytes.tally.counts
        #expect(made >= 3000)
        // The reads FFmpeg makes while it opens the stream come before the
        // first packet and stay with the thread; a few hundred at most.
        #expect(alive < made / 4, "\(alive) of \(made) autoreleased objects still alive")
    }

    @Test(
        "playback-engine/live-playback-keeps-memory-steady bytes taken from the connection are let go",
        arguments: [false, true])
    func connectionLetsGoOfBytesTaken(standby: Bool) throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let stream = HTTPByteStream(url: try #require(URL(string: "http://127.0.0.1:9/live.ts")), session: session)
        let task = session.dataTask(with: try #require(URL(string: "http://127.0.0.1:9/live.ts")))
        let part = Data(repeating: 0x47, count: 188 * 349)
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: part.count)
        defer { scratch.deallocate() }
        if standby { stream.standbyWindow = part.count * 4 }
        let before = Self.bytesInUse()
        // About 200 MB, 25 minutes of a 1 Mbit/s channel or 6 of an HD one.
        for _ in 0..<3200 {
            stream.urlSession(session, dataTask: task, didReceive: part)
            if !standby { _ = stream.read(into: scratch, count: part.count) }
        }
        let grown = Self.bytesInUse() - before
        #expect(grown < 16 << 20, "grew \(grown >> 20) MB over \((3200 * part.count) >> 20) MB received")
    }

    /// Bytes the process has allocated with malloc and not freed.
    static func bytesInUse() -> Int {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        return stats.size_in_use
    }
}

/// A live stream that never ends: `data` over and over, until cancelled,
/// at most `readSize` bytes a read. Each read autoreleases an object
/// `tally` counts.
private final class EndlessBytes: DemuxBytes, @unchecked Sendable {
    private let data: Data
    private let readSize: Int
    private let lock = NSLock()
    private var offset = 0
    private var cancelled = false
    let tally = Tally()

    init(_ data: Data, readSize: Int) {
        self.data = data
        self.readSize = readSize
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        _ = Unmanaged.passRetained(Tracked(tally)).autorelease()
        return lock.withLock {
            guard !cancelled else { return 0 }
            let within = offset % data.count
            let taken = min(count, readSize, data.count - within)
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.advanced(by: within).assumingMemoryBound(to: UInt8.self), count: taken)
            }
            offset += taken
            return taken
        }
    }

    func peek(_ count: Int) -> Data { data.prefix(count) }
    var failureReason: PlaybackFailure? { nil }
    var canSeek: Bool { false }
    var length: Int? { nil }
    var position: Int { lock.withLock { offset } }
    func seek(to target: Int) -> Bool { false }
    func cancel() { lock.withLock { cancelled = true } }
}

/// How many `Tracked` objects were made and how many are gone.
private final class Tally: @unchecked Sendable {
    private let lock = NSLock()
    private var madeCount = 0
    private var goneCount = 0

    var made: Int { lock.withLock { madeCount } }
    /// Made, and made less gone.
    var counts: (made: Int, alive: Int) { lock.withLock { (madeCount, madeCount - goneCount) } }
    func add() { lock.withLock { madeCount += 1 } }
    func remove() { lock.withLock { goneCount += 1 } }
}

/// Tells its tally when it is made and when it goes.
private final class Tracked {
    private let tally: Tally

    init(_ tally: Tally) {
        self.tally = tally
        tally.add()
    }

    deinit { tally.remove() }
}

/// A renderer that takes every buffer at once.
private final class TakingRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    let timebase: CMTimebase

    init(timebase: CMTimebase) {
        self.timebase = timebase
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {}
    func flush() {}
    var isReadyForMoreMediaData: Bool { true }
    // swiftlint:disable:next identifier_name
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { true }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {}
    func stopRequestingMediaData() {}
}
