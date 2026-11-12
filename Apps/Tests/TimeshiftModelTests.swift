import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// An engine that records what the timeshift model asks of it.
@MainActor
final class TimeshiftTestEngine: PlaybackEngine {
    private(set) var calls: [String] = []
    private(set) var seeks: [Date] = []
    private let stateCast = Broadcast(PlaybackState.playing)

    var state: PlaybackState { stateCast.value }
    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

    func load(_ url: URL, options: PlaybackOptions) async throws { calls.append("load") }
    func play() async {
        calls.append("play")
        stateCast.send(.playing)
    }
    func pause() async {
        calls.append("pause")
        stateCast.send(.paused)
    }
    func stop() async { calls.append("stop") }
    func seek(to time: Duration) async throws { throw SeekRefusal.live }
    func seek(to date: Date) async throws {
        calls.append("seek")
        seeks.append(date)
    }
    func seekToLive() async { calls.append("live") }
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
    func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
    func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}

@MainActor
@Suite struct TimeshiftModelTests {
    static let end = Date(timeIntervalSince1970: 1_793_826_000)
    static let window = TimeshiftWindow(start: end.addingTimeInterval(-3600), end: end)

    static func status(behind: TimeInterval, notice: TimeshiftNotice? = nil, count: Int = 0) -> TimeshiftStatus {
        TimeshiftStatus(
            recording: .recording, window: window, playhead: end.addingTimeInterval(-behind), notice: notice, noticeCount: count)
    }

    func model(_ engine: TimeshiftTestEngine, clock: SleepClock = SleepClock()) -> TimeshiftModel {
        TimeshiftModel(.init(engine: engine, sleep: { try await clock.sleep($0) }))
    }

    /// Lets the model's engine tasks run.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test("timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off: the user's pause and play")
    func userPause() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        model.statusChanged(Self.status(behind: 0))
        model.userPause()
        #expect(model.userPaused)
        model.statusChanged(Self.status(behind: 720))
        #expect(model.behindText == "12 min behind")
        #expect(model.markerFraction == 0.8)
        #expect(model.showsRewindRow)
        model.userPlay()
        #expect(!model.userPaused)
        await settle()
        #expect(engine.calls == ["pause", "play"])
    }

    @Test("timeshift-catch-up-and-start-over/skip-scan-and-drag: skips land 15 back or 30 forward, and now is live")
    func skips() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        model.statusChanged(Self.status(behind: 600))
        model.skip(forward: false)
        await settle()
        #expect(engine.seeks == [Self.end.addingTimeInterval(-615)])
        model.statusChanged(Self.status(behind: 35))
        model.skip(forward: true)
        await settle()
        #expect(engine.calls.suffix(2) == ["live", "play"])
        // Never before the start of the buffer.
        model.statusChanged(Self.status(behind: 3595))
        model.skip(forward: false)
        await settle()
        #expect(engine.seeks.last == Self.window.start)
    }

    @Test("timeshift-catch-up-and-start-over/skip-scan-and-drag: a drag seeks once, on release")
    func drag() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        model.statusChanged(Self.status(behind: 0))
        model.drag(to: 0.5)
        model.drag(to: 0.25)
        #expect(model.behindText == "45 min behind")
        #expect(engine.seeks.isEmpty)
        model.endDrag()
        await settle()
        #expect(engine.seeks == [Self.window.start.addingTimeInterval(900)])
    }

    @Test("timeshift-catch-up-and-start-over/back-to-live: back to live plays at live")
    func goLive() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        model.statusChanged(Self.status(behind: 600))
        model.userPause()
        model.holdForLive()
        await settle()
        #expect(!model.userPaused)
        #expect(engine.calls.suffix(2) == ["live", "play"])
        #expect(model.takeHeldPress())
        #expect(!model.takeHeldPress())
    }

    @Test("timeshift-catch-up-and-start-over/leaving-the-app-calls-and-other-interruptions: what comes back after an interruption")
    func interruptions() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        var restarts = 0
        model.restartChannel = { restarts += 1 }

        // At live: back at live with a new buffer.
        model.statusChanged(Self.status(behind: 0))
        model.interrupted()
        model.interruptionEnded()
        #expect(restarts == 1)

        // Behind by choice: goes on from where it was.
        model.statusChanged(Self.status(behind: 600))
        model.interrupted()
        model.interruptionEnded()
        await settle()
        #expect(restarts == 1)
        #expect(engine.calls.last == "play")

        // The user's pause stays.
        model.userPause()
        await settle()
        let before = engine.calls.count
        model.interrupted()
        model.interruptionEnded()
        await settle()
        #expect(engine.calls.count == before)
        #expect(model.userPaused)
    }

    @Test("timeshift-catch-up-and-start-over/when-the-buffer-runs-out: buffer full ends the pause and says so")
    func bufferFull() async {
        let engine = TimeshiftTestEngine()
        let clock = SleepClock()
        let model = model(engine, clock: clock)
        model.userPause()
        model.statusChanged(Self.status(behind: 3600, notice: .bufferFull, count: 1))
        #expect(!model.userPaused)
        #expect(model.notice == "Buffer full. Playing from the earliest point")
        // A status with the same notice again is not a new one.
        model.statusChanged(Self.status(behind: 3500, notice: .bufferFull, count: 1))
        await clock.advance(by: .seconds(5))
        #expect(model.notice == nil)
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: short storage says so on the first pause only")
    func storageShort() async {
        let engine = TimeshiftTestEngine()
        let model = model(engine)
        model.statusChanged(TimeshiftStatus(recording: .storageShort))
        #expect(!model.canRewind)
        model.userPause()
        #expect(model.notice == "Not enough free storage to rewind live TV")
        model.userPlay()
        await settle()
        // Play returns to live with no rewind row.
        #expect(engine.calls.suffix(2) == ["live", "play"])
    }

    @Test("timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded: the failure notices")
    func failureNotices() {
        #expect(TimeshiftText.notice(.storageFull(wasBehind: true)) == "Storage is full. Back to live TV")
        #expect(TimeshiftText.notice(.storageFull(wasBehind: false)) == "Storage is full")
        #expect(TimeshiftText.notice(.rewindFailed(wasBehind: true)) == "Rewind stopped working. Back to live TV")
        #expect(TimeshiftText.notice(.rewindFailed(wasBehind: false)) == "Rewind stopped working")
        #expect(TimeshiftText.notice(.skippedToLive) == "Skipped ahead to live")
        #expect(TimeshiftText.behind(10, tolerance: 10) == nil)
        #expect(TimeshiftText.behind(61, tolerance: 10) == "2 min behind")
    }
}
