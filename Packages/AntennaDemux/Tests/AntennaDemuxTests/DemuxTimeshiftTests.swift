import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// `DemuxEngine` recording live TV to the local buffer, against a fixture
/// server that sends the stream at about real time.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxTimeshiftTests {
    /// channel.ts is six seconds of 150 kbit/s video with sound.
    static let rate = 40_000

    @Test(
        "timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off pause records on, play needs no reload"
    )
    func pauseAndPlay() async throws {
        let harness = try await TimeshiftHarness()
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { harness.status.window != nil })
        #expect(harness.status.recording == .recording)

        await harness.engine.pause()
        #expect(harness.engine.state == .paused)
        let paused = try #require(harness.status.playhead)
        // The connection stays open and recording goes on.
        #expect(await harness.server.openPaths.contains("/channel.ts"))
        #expect(await eventually { (harness.status.window?.end ?? .distantPast) > paused.addingTimeInterval(1.5) })
        #expect(harness.status.behind > 1)
        #expect(abs(try #require(harness.status.playhead).timeIntervalSince(paused)) < 0.6)

        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await harness.server.requests(for: "/channel.ts").count == 1)
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/skip-scan-and-drag moving to the start of the buffer and back to live")
    func seekAndLive() async throws {
        let harness = try await TimeshiftHarness()
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually(timeout: .seconds(15)) { (harness.status.window?.duration ?? 0) > 3 })
        let window = try #require(harness.status.window)

        try await harness.engine.seek(to: window.start)
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { (harness.status.playhead?.timeIntervalSince(window.start) ?? 99) < 1.5 })
        #expect(await eventually { harness.status.behind > 2 })

        await harness.engine.seekToLive()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { harness.status.isAtLive(tolerance: 2) })
        #expect(await harness.server.requests(for: "/channel.ts").count == 1)
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh a new channel gets a new buffer and the old one goes")
    func changingChannel() async throws {
        let harness = try await TimeshiftHarness()
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually { harness.status.window != nil })
        let first = try #require(harness.folders().first)

        await harness.server.always("/mpeg2.ts", .paced(bytesPerSecond: Self.rate))
        try await harness.engine.load(harness.url("mpeg2.ts"), options: harness.options)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { harness.folders().count == 1 && harness.folders().first != first })
        #expect(harness.status.recording == .recording)
        await harness.engine.stop()
        #expect(await eventually { harness.folders().isEmpty })
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/changing-channel-starts-fresh trying the same channel again keeps its buffer")
    func sameChannelKeepsBuffer() async throws {
        let harness = try await TimeshiftHarness()
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually { harness.status.window != nil })
        let folder = harness.folders()
        let start = try #require(harness.status.window?.start)

        try await harness.engine.load(harness.url("channel.ts"), options: harness.options)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(harness.folders() == folder)
        #expect(harness.status.window?.start == start)
        #expect(harness.status.window?.gaps.isEmpty == false)
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded a stream the buffer cannot record plays as before")
    func cannotRecord() async throws {
        let harness = try await TimeshiftHarness()
        await harness.server.script("/channel.mkv", .stall(afterBytes: 100_000))
        try await harness.engine.load(harness.url("channel.mkv"), options: harness.options)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(harness.status.recording == .cannotRecord)
        #expect(harness.folders().isEmpty)
        // Pause lets the connection go and play opens it again at live.
        await harness.engine.pause()
        #expect(await eventually { await harness.server.openPaths.isEmpty })
        await #expect(throws: SeekRefusal.live) { try await harness.engine.seek(to: .now) }
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded too little free storage plays without a buffer")
    func storageShort() async throws {
        var limits = TimeshiftLimits.standard(for: .mac)
        limits.keepFree = Int.max / 2
        let harness = try await TimeshiftHarness(limits: limits)
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(harness.status.recording == .storageShort)
        #expect(harness.folders().isEmpty)
        await harness.stop()
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded a failed write partway goes back to live without stopping")
    func writeFailsPartway() async throws {
        let files = FailingFiles(after: 30)
        let harness = try await TimeshiftHarness(files: files)
        try await harness.loadPaced("channel.ts")
        await harness.engine.play()
        #expect(await eventually(timeout: .seconds(15)) { harness.status.recording == .stopped })
        #expect(harness.status.notice == .storageFull(wasBehind: false))
        #expect(harness.status.noticeCount == 1)
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { harness.folders().isEmpty })
        #expect(await harness.server.requests(for: "/channel.ts").count == 2)
        await harness.stop()
    }
}

/// Appends that start failing for lack of space after a number of them.
final class FailingFiles: TimeshiftFiles, @unchecked Sendable {
    private let disk = DiskTimeshiftFiles()
    private let lock = NSLock()
    private var left: Int

    init(after count: Int) {
        left = count
    }

    func create(_ url: URL) throws { try disk.create(url) }

    func append(_ data: Data, to url: URL) throws {
        let fail = lock.withLock {
            left -= 1
            return left < 0
        }
        if fail { throw TimeshiftFileError.noSpace }
        try disk.append(data, to: url)
    }

    func read(_ url: URL, offset: Int, count: Int) throws -> Data { try disk.read(url, offset: offset, count: count) }
    func remove(_ url: URL) { disk.remove(url) }
}

@MainActor
private final class TimeshiftHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine
    let store: TimeshiftStore
    let options: PlaybackOptions
    private var statuses: Recorded<TimeshiftStatus>?

    init(limits: TimeshiftLimits = .standard(for: .mac), files: any TimeshiftFiles = DiskTimeshiftFiles()) async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine = DemuxEngine(sleep: { _ in try await Task.sleep(for: .milliseconds(10)) }, log: { _ in })
        store = TimeshiftStore(root: FileManager.default.temporaryDirectory.appending(path: "timeshift-\(UUID().uuidString)"))
        options = PlaybackOptions(timeshift: TimeshiftRequest(store: store, limits: limits, files: files))
        statuses = Recorded(await engine.timeshift())
    }

    var status: TimeshiftStatus { statuses?.values.last ?? .off }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func loadPaced(_ path: String) async throws {
        await server.always("/\(path)", .paced(bytesPerSecond: DemuxTimeshiftTests.rate))
        try await engine.load(url(path), options: options)
    }

    /// The session folders in the store, without the retired ones.
    func folders() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: store.root.path)) ?? []).filter { !$0.hasPrefix("retired-") }.sorted()
    }

    func stop() async {
        statuses?.cancel()
        await engine.stop()
        await server.stop()
        try? FileManager.default.removeItem(at: store.root)
    }
}
