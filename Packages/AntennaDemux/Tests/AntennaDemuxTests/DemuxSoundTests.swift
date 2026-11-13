@preconcurrency import AVFoundation
import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Sound on the FFmpeg path that changes format, needs SBR, has eight
/// channels or starts on a track the device cannot decode, checked by
/// decoding the built buffers with Apple's decoder.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxSoundTests {
    private static func fixture(_ name: String) throws -> URL {
        try FixtureServer.fixtures().appending(path: name)
    }

    @Test(
        "playback-engine/sound-keeps-playing-when-its-format-changes every buffer decodes after the channel count changes",
        arguments: [("sound-change-aac.ts", [2, 6]), ("sound-change-ac3.ts", [2, 6]), ("sound-change-mp2.ts", [2, 1])])
    func formatChange(file: String, channels: [Int]) throws {
        let outcome = try SoundDecoding.decode(try Self.fixture(file))
        #expect(outcome.failures == 0)
        #expect(outcome.pieces.map(\.channels) == channels)
        for piece in outcome.pieces {
            #expect(abs(Double(piece.frames) / piece.sampleRate - 2) < 0.1, "each half plays its 2 seconds")
            #expect(piece.level > 0.01, "each half carries its tone")
        }
    }

    @Test("playback-engine/sound-keeps-playing-when-its-format-changes HE-AAC in ADTS decodes with its upper band")
    func heAAC() throws {
        let outcome = try SoundDecoding.decode(try Self.fixture("he-aac.ts"))
        #expect(outcome.failures == 0)
        let piece = try #require(outcome.pieces.first)
        #expect(outcome.pieces.count == 1)
        // The 15 kHz tone lives in the SBR layer. Decoded as plain AAC at
        // 24 kHz it is gone, around 0.0002.
        #expect(piece.level > 0.002)
        #expect(piece.channels == 2)
    }

    @Test("playback-engine/sound-keeps-playing-when-its-format-changes 7.1 AAC decodes on all eight channels")
    func sevenOne() throws {
        let outcome = try SoundDecoding.decode(try Self.fixture("aac-7.1.mkv"))
        #expect(outcome.failures == 0)
        #expect(outcome.pieces.map(\.channels) == [8])
        #expect((outcome.pieces.first?.level ?? 0) > 0.01)
    }

    @Test("playback-engine/sound-keeps-playing-when-its-format-changes the screen learns the new channel count")
    func reportsChange() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let format = Recorded(await engine.presentation())
        try await engine.load(base.appending(path: "sound-change-aac.ts"))
        await engine.play()
        #expect(await eventually { format.values.contains { $0?.audio?.channels == 2 } })
        #expect(await eventually { format.values.last??.audio?.channels == 6 })
        #expect(format.values.last??.audio?.isDecodable == true)
        format.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/streams-start-with-sound-the-device-can-play a DTS default starts on the Dolby Digital track")
    func skipsUndecodableDefault() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "dts-and-ac3.mkv"))
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.audio.map(\.id) == ["audio-0", "audio-1"])
        #expect(tracks.selectedAudio == "audio-1")
        let format = try #require(await current(engine.presentation()).flatMap { $0 })
        #expect(format.audio == PresentationInfo.Audio(codec: "ac3", channels: 2, isDecodable: true))
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/sound-keeps-playing-when-its-format-changes sound the renderer dropped is queued again from that time")
    func resendsAfterFlush() async throws {
        let data = try Data(contentsOf: try Self.fixture("channel.ts"))
        let bytes = GatedBytes(data, gate: data.count / 2)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        let clock = try #require(timebase)
        let video = RecordingRenderer(timebase: clock)
        let audio = RecordingRenderer(timebase: clock)
        let run = DemuxRun(
            bytes: bytes, videoFeed: SampleFeed(renderer: video, label: "test.video", limit: 1000),
            audioFeed: SampleFeed(renderer: audio, label: "test.audio", limit: 1000))
        let started = Started()
        run.start(ready: { result in started.set((try? result.get()) != nil) }, ended: { _ in })
        #expect(await eventually { started.value == true })
        // Everything before the gate is queued; the run waits for more bytes.
        #expect(await eventually { bytes.waiting })
        try await Task.sleep(for: .milliseconds(200))
        let queued = audio.times
        let from = try #require(queued.dropFirst(queued.count / 2).first)
        let newest = try #require(queued.last)
        run.resendSound(from: from)
        bytes.open()
        #expect(await eventually { audio.timesSinceFlush.count > 1 })
        #expect(audio.timesSinceFlush.first == from, "the sound starts again at the flush time, not at \(newest.seconds)")
        run.cancel()
    }
}

/// Bytes from memory that stop at `gate` until `open`, as a live stream
/// waits for the next bytes.
private final class GatedBytes: DemuxBytes, @unchecked Sendable {
    private let data: Data
    private let condition = NSCondition()
    private var gate: Int
    private var offset = 0
    private var cancelled = false
    private var isWaiting = false

    /// True while a read waits at the gate.
    var waiting: Bool {
        condition.lock()
        defer { condition.unlock() }
        return isWaiting
    }

    init(_ data: Data, gate: Int) {
        self.data = data
        self.gate = gate
    }

    func open() {
        condition.lock()
        gate = data.count
        condition.broadcast()
        condition.unlock()
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        condition.lock()
        defer { condition.unlock() }
        while offset >= gate, gate < data.count, !cancelled {
            isWaiting = true
            condition.wait()
        }
        isWaiting = false
        let taken = min(count, gate - offset)
        guard taken > 0, !cancelled else { return 0 }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            destination.update(from: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: taken)
        }
        offset += taken
        return taken
    }

    func peek(_ count: Int) -> Data {
        data.prefix(count)
    }

    var failureReason: PlaybackFailure? { nil }
    var canSeek: Bool { false }
    var length: Int? { nil }
    var position: Int { offset }
    func seek(to target: Int) -> Bool { false }

    func cancel() {
        condition.lock()
        cancelled = true
        condition.broadcast()
        condition.unlock()
    }
}

/// Whether a run started, set from its thread.
private final class Started: @unchecked Sendable {
    private let lock = NSLock()
    private var started: Bool?

    var value: Bool? { lock.withLock { started } }

    func set(_ value: Bool) {
        lock.withLock { started = value }
    }
}

/// A renderer that takes every buffer and keeps their times.
private final class RecordingRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var all: [CMTime] = []
    private var afterFlush: [CMTime] = []
    private var flushed = false

    let timebase: CMTimebase

    init(timebase: CMTimebase) {
        self.timebase = timebase
    }

    var times: [CMTime] { lock.withLock { all } }
    var timesSinceFlush: [CMTime] { lock.withLock { afterFlush } }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lock.withLock {
            all.append(time)
            if flushed { afterFlush.append(time) }
        }
    }

    func flush() {
        lock.withLock {
            flushed = true
            afterFlush = []
        }
    }

    var isReadyForMoreMediaData: Bool { true }
    // swiftlint:disable:next identifier_name
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { true }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {}
    func stopRequestingMediaData() {}
}
