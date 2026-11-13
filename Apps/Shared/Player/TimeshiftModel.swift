import AntennaCore
import Foundation
import Observation

/// Moving in time on live TV, shared by every platform
/// (timeshift-catch-up-and-start-over capability): the buffer the engine
/// reports, the pause the user made, skips, scans, drags, back to live and
/// the notices.
///
/// `userPaused` is set only by a pause the user asked for, from the remote,
/// the on-screen button, Space or the lock screen, and cleared by any play.
/// Pauses from other tabs, calls and leaving the app never set it, so those
/// never resume a pause the user made.
@MainActor @Observable
final class TimeshiftModel {
    struct Dependencies {
        var engine: any PlaybackEngine
        var limits = TimeshiftLimits.app
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        /// How long a notice stays.
        var noticeFor = Duration.seconds(4)
        var now: @MainActor () -> Date = { Date() }
        /// How often Start over is checked again.
        var startOverCheck = Duration.seconds(2)
    }

    private(set) var status = TimeshiftStatus.off
    var userPaused = false
    /// The moment a scan or a drag shows before it seeks, nil otherwise.
    var preview: Date?
    /// The notice on screen, nil when none.
    private(set) var notice: String?
    /// The catch-up programme Start over plays, nil on live TV.
    var catchup: CatchupPlayback?
    /// Seconds into the catch-up stream, from the engine.
    var catchupPosition: TimeInterval = 0
    /// How Start over plays the programme on now on the channel playing.
    var startOver = StartOverPlan.none
    /// True from Start over until catch-up plays or falls back.
    var startingCatchup = false {
        didSet { failuresIgnoredUntil = startingCatchup ? .distantFuture : now().addingTimeInterval(2) }
    }
    /// A failed catch-up start shows no error; its failure can reach the
    /// player a moment after the fallback, so this runs on a little.
    @ObservationIgnored private var failuresIgnoredUntil = Date.distantPast

    /// True while a failure comes from a catch-up start.
    var ignoresFailures: Bool {
        now() < failuresIgnoredUntil
    }

    @ObservationIgnored let limits: TimeshiftLimits
    @ObservationIgnored private let dependencies: Dependencies
    private var engine: any PlaybackEngine { dependencies.engine }
    @ObservationIgnored private var seenNotices = 0
    @ObservationIgnored private var saidStorageShort = false
    @ObservationIgnored private var noticeTimer: Task<Void, Never>?
    @ObservationIgnored private var scan: Task<Void, Never>?
    /// Live was on screen when an interruption paused it.
    @ObservationIgnored private var interruptedAtLive: Bool?
    /// Starts the channel again with a new buffer. The owner sets it.
    @ObservationIgnored var restartChannel: @MainActor () -> Void = {}
    /// The channel playing and its programme on now. The owner sets it.
    @ObservationIgnored var nowPlaying: @MainActor () -> (channel: Channel, programme: Programme?)? = { nil }
    /// The catch-up address for a channel and request, nil when none can be built. The owner sets it.
    @ObservationIgnored var catchupAddress: @MainActor (Channel, CatchupRequest) async -> URL? = { _, _ in nil }
    @ObservationIgnored var catchupLoad: Task<Void, Never>?
    var engineForStartOver: any PlaybackEngine { engine }
    var startOverCheck: Duration { dependencies.startOverCheck }
    func now() -> Date { dependencies.now() }

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        limits = dependencies.limits
    }

    /// Follows the engine's buffer until the calling task ends.
    func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observeStatus() }
            group.addTask { await self.observeCatchupPosition() }
            group.addTask { await self.observeCatchupEnd() }
            group.addTask { await self.checkStartOver() }
        }
    }

    private func observeStatus() async {
        for await value in await engine.timeshift() {
            statusChanged(value)
        }
    }

    func statusChanged(_ value: TimeshiftStatus) {
        let previous = status
        status = value
        if value.noticeCount > seenNotices, let raised = value.notice {
            seenNotices = value.noticeCount
            if raised == .bufferFull { userPaused = false }
            say(TimeshiftText.notice(raised))
        }
        if value.recording != previous.recording, value.recording == .off {
            seenNotices = 0
            preview = nil
        }
    }

    // MARK: Reading

    /// What playback can move within: the buffer, or during catch-up the
    /// programme from its start to now.
    var window: TimeshiftWindow? {
        if let catchup { return TimeshiftWindow(start: catchup.programme.start, end: max(now(), catchup.programme.start)) }
        return status.recording == .recording ? status.window : nil
    }

    /// The moment on screen.
    var playhead: Date? {
        if let catchup { return catchup.start.addingTimeInterval(catchupPosition) }
        return status.playhead
    }

    /// True while playback can move: a buffer with something in it, or catch-up.
    var canRewind: Bool {
        window != nil
    }

    /// True while the picture is behind live by more than the tolerance.
    var isBehind: Bool {
        guard let window, let playhead else { return false }
        return catchup != nil || window.end.timeIntervalSince(playhead) > limits.liveEdgeTolerance
    }

    /// The moment on screen, or the one a scan or drag shows.
    var shownTime: Date? {
        preview ?? playhead
    }

    /// "12 min behind", nil at live.
    var behindText: String? {
        guard let window, let shown = shownTime else { return nil }
        return TimeshiftText.behind(window.end.timeIntervalSince(shown), tolerance: limits.liveEdgeTolerance)
    }

    /// The marker's place along the scrubber, 0 to 1.
    var markerFraction: Double? {
        guard let window, let shown = shownTime else { return nil }
        return TimeshiftText.fraction(of: shown, in: window)
    }

    /// The Apple TV rewind row shows while paused or behind live, or while
    /// a scan runs; left and right skip only then.
    var showsRewindRow: Bool {
        canRewind && (userPaused || isBehind || preview != nil)
    }

    var gaps: [ClosedRange<Double>] {
        catchup == nil ? status.window.map(TimeshiftText.gaps(in:)) ?? [] : []
    }

    // MARK: Pause and play

    /// The user's pause or play.
    func toggle(isPaused: Bool) {
        if isPaused {
            userPlay()
        } else {
            userPause()
        }
    }

    func userPause() {
        markPaused()
        Task { await engine.pause() }
    }

    /// The user's pause, returning once the engine was told.
    func pause() async {
        markPaused()
        await engine.pause()
    }

    private func markPaused() {
        userPaused = true
        if status.recording == .storageShort, !saidStorageShort {
            saidStorageShort = true
            say(TimeshiftText.storageShort)
        }
    }

    func userPlay() {
        userPaused = false
        Task { await play() }
    }

    /// The user's play, returning once the engine was told.
    func play() async {
        userPaused = false
        if catchup != nil, let playhead { return loadCatchup(at: playhead, coalesced: false) }
        if !canRewind { await engine.seekToLive() }
        await engine.play()
    }

    // MARK: Moving

    /// Back 15 seconds or forward 30 from what is on screen.
    func skip(forward: Bool) {
        skip(seconds: forward ? limits.skipForward : -limits.skipBack)
    }

    /// Moves `seconds` from what is on screen, back when negative.
    func skip(seconds: TimeInterval) {
        guard let window, let playhead = shownTime else { return }
        move(TimeshiftMove.skip(seconds, from: playhead, in: window, limits: limits))
    }

    /// A double-tap on a half of the picture: 15 seconds either way, or a
    /// note saying why nothing moved (live-tv-on-iphone-ipad-mac/double-tap-to-skip).
    func doubleTapSkip(forward: Bool) {
        guard canRewind else { return say(TimeshiftText.rewindUnavailable) }
        if forward, !isBehind { return say(TimeshiftText.alreadyLive) }
        skip(seconds: forward ? limits.skipBack : -limits.skipBack)
    }

    /// Starts a held scan; the shown time moves at the scan rate until `endScan`.
    func beginScan(forward: Bool) {
        guard canRewind, let from = shownTime else { return }
        scan?.cancel()
        let started = ContinuousClock.now
        preview = from
        scan = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let window else { return }
                let held = (ContinuousClock.now - started) / .seconds(1)
                preview = TimeshiftMove.scan(from: from, forward: forward, held: held, in: window, rate: limits.scanRate)
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    /// The hold ended: one seek to the time shown.
    func endScan() {
        scan?.cancel()
        scan = nil
        commitPreview()
    }

    /// The finger or pointer is at `fraction` of the scrubber.
    func drag(to fraction: Double) {
        guard let window else { return }
        preview = TimeshiftText.date(at: fraction, in: window)
    }

    /// The drag ended: one seek to where it stopped.
    func endDrag() {
        commitPreview()
    }

    private func commitPreview() {
        guard let target = preview, let window else { return preview = nil }
        move(TimeshiftMove.landing(target, in: window, limits: limits))
    }

    private func move(_ move: TimeshiftMove) {
        switch move {
        case .to(let date) where catchup != nil:
            preview = date
            loadCatchup(at: date, coalesced: true)
        case .live where catchup != nil:
            returnToLive()
        case .to(let date):
            preview = date
            Task {
                try? await engine.seek(to: date)
                preview = nil
            }
        case .live:
            goLive()
        }
    }

    /// Play/pause held for half a second on Apple TV. The press's release
    /// then does not also pause; see `takeHeldPress`.
    func holdForLive() {
        heldAt = .now
        goLive()
    }

    /// True once after a hold for live, so the release of that press is ignored.
    func takeHeldPress() -> Bool {
        guard let heldAt, ContinuousClock.now - heldAt < .milliseconds(1500) else { return false }
        self.heldAt = nil
        return true
    }

    @ObservationIgnored private var heldAt: ContinuousClock.Instant?

    /// Back to live, playing (timeshift-catch-up-and-start-over/back-to-live).
    func goLive() {
        if catchup != nil { return returnToLive() }
        preview = nil
        userPaused = false
        Task {
            await engine.seekToLive()
            await engine.play()
        }
    }

    /// A new channel starts at live with no pause of its own.
    func channelChanged() {
        userPaused = false
        preview = nil
        interruptedAtLive = nil
        saidStorageShort = false
        scan?.cancel()
    }

    // MARK: Interruptions

    /// Something other than the user paused playback: a call, leaving the
    /// app, another tab. Remembers whether live was on screen.
    func interrupted() {
        guard interruptedAtLive == nil else { return }
        interruptedAtLive = !isBehind && !userPaused
    }

    /// The interruption ended. A user pause stays. A channel that was at
    /// live comes back at live with a new buffer; one behind live by choice
    /// goes on from where it was
    /// (timeshift-catch-up-and-start-over/leaving-the-app-calls-and-other-interruptions).
    func interruptionEnded() async {
        let atLive = interruptedAtLive
        interruptedAtLive = nil
        guard !userPaused else { return }
        if atLive == true, canRewind {
            restartChannel()
        } else {
            await engine.play()
        }
    }

    // MARK: Notices

    private func say(_ text: String) {
        notice = text
        noticeTimer?.cancel()
        let hold = dependencies.noticeFor
        noticeTimer = Task { [weak self] in
            do { try await self?.dependencies.sleep(hold) } catch { return }
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// Says `text` as a notice, for Start over's own messages.
    func announce(_ text: String) {
        say(text)
    }
}

extension TimeshiftLimits {
    /// The limits for the device the app runs on.
    static var app: TimeshiftLimits {
        #if os(tvOS)
            .standard(for: .tv)
        #elseif os(macOS)
            .standard(for: .mac)
        #else
            .standard(for: .phone)
        #endif
    }
}

extension TimeshiftRequest {
    /// Recording into the app's caches with this device's limits.
    static var app: TimeshiftRequest {
        TimeshiftRequest(limits: .app)
    }
}

extension PlaybackOptions {
    /// These options with live TV recorded to the local buffer, for the
    /// main player only; multi-view tiles and films never record.
    func recordingLive() -> PlaybackOptions {
        var options = self
        options.timeshift = .app
        return options
    }
}

extension PlaybackLifecycle {
    /// Lets `timeshift` see the pauses this lifecycle makes and decide how
    /// playback comes back after them.
    func follow(_ timeshift: TimeshiftModel) {
        willPause = { [weak timeshift] in timeshift?.interrupted() }
        resume = { [weak timeshift] in await timeshift?.interruptionEnded() }
    }
}
