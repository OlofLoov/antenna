@preconcurrency import AVFoundation
import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// A run's memory over a long live stream: what it takes for each packet
/// is let go while the stream plays on, not when its thread ends.
@Suite(.serialized) struct DemuxMemoryTests {
    @Test(
        "playback-engine/live-playback-keeps-memory-steady memory stays flat while interlaced live TV plays",
        arguments: ["interlaced-576i.ts", "interlaced-1080i.ts"])
    func interlacedLiveStaysFlat(file: String) async throws {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: file))
        let bytes = EndlessBytes(data)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        let clock = try #require(timebase)
        let video = CountingRenderer(timebase: clock)
        let audio = CountingRenderer(timebase: clock)
        let run = DemuxRun(
            bytes: bytes, videoFeed: SampleFeed(renderer: video, label: "memory.video", limit: 8),
            audioFeed: SampleFeed(renderer: audio, label: "memory.audio", limit: 64))
        run.start(ready: { _ in }, options: PlaybackOptions(isLive: true), ended: { _ in })
        defer { run.cancel() }

        // Past the start, the decoder, deinterlacer and feeds hold all they will.
        try await video.wait(for: 300)
        let settled = Self.bytesInUse()
        try await video.wait(for: 300 + Self.pictures)
        let grown = Self.bytesInUse() - settled
        // Each picture left about 2 KB of the GPU's bookkeeping behind
        // before the run drained its autorelease pool per packet.
        #expect(grown < Self.pictures * 256, "grew \(grown) bytes over \(Self.pictures) pictures")
    }

    static let pictures = 5000

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

/// A live stream that never ends: `data` over and over, until cancelled.
private final class EndlessBytes: DemuxBytes, @unchecked Sendable {
    private let data: Data
    private let lock = NSLock()
    private var offset = 0
    private var cancelled = false

    init(_ data: Data) {
        self.data = data
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        lock.withLock {
            guard !cancelled else { return 0 }
            let within = offset % data.count
            let taken = min(count, data.count - within)
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

/// A renderer that takes every buffer at once and counts them.
private final class CountingRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    let timebase: CMTimebase
    private let lock = NSLock()
    private var taken = 0

    init(timebase: CMTimebase) {
        self.timebase = timebase
    }

    var count: Int { lock.withLock { taken } }

    /// Returns once `target` buffers arrived; fails after a minute.
    func wait(for target: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(60)
        while count < target {
            guard ContinuousClock.now < deadline else { throw Timeout() }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) { lock.withLock { taken += 1 } }
    func flush() {}
    var isReadyForMoreMediaData: Bool { true }
    // swiftlint:disable:next identifier_name
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { true }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {}
    func stopRequestingMediaData() {}

    struct Timeout: Error {}
}
