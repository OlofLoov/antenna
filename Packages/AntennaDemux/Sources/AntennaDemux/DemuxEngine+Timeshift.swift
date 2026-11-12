import AntennaCore
import CoreMedia
import Foundation

/// Live TV through the local buffer (timeshift-catch-up-and-start-over
/// capability). With `PlaybackOptions.timeshift`, a raw broadcast stream is
/// recorded by a `TimeshiftRecorder` and every run reads the buffer, so
/// pause keeps the connection and recording going, and `seek(to:)` and
/// `seekToLive()` start a new run at another point with no new connection.
/// A stream that cannot be recorded, or a device short of storage, plays
/// straight from its connection as before.
extension DemuxEngine {
    /// True while the channel playing records into a buffer.
    var isTimeshifting: Bool {
        timeshift?.recordingBuffer != nil
    }

    // MARK: Loading

    /// A load of `url` keeps the session for the same address, as Try again
    /// does, and lets any other session go, deleting its buffer.
    func keepOrRetireTimeshift(for url: URL, options: PlaybackOptions) {
        guard let session = timeshift else { return }
        if options.timeshift != nil, session.url == url, session.recording != .stopped { return }
        retireTimeshift()
    }

    /// Lets the session go and deletes its buffer off the main path.
    func retireTimeshift() {
        timeshift?.discard()
        timeshift = nil
        timeshiftCast.send(.off)
    }

    /// The bytes a new run reads from the connection `bytes` just opened:
    /// the buffer when the load asked for timeshift and the stream can be
    /// recorded, the connection itself otherwise.
    func timeshiftSource(_ bytes: HTTPByteStream, url: URL, options: PlaybackOptions, generation mine: Int) async throws -> any DemuxBytes {
        guard let request = options.timeshift else { return SeekableSource(bytes, url: url, session: session) }
        let session = timeshift ?? makeTimeshiftSession(url: url, request: request)
        timeshift = session
        guard let buffer = session.recordingBuffer else {
            publishTimeshift()
            return SeekableSource(bytes, url: url, session: self.session)
        }
        if session.hasRecorded { buffer.markGap() }
        session.reconnect?.cancel()
        session.recorder?.cancel()
        let recorder = TimeshiftRecorder(bytes: bytes, buffer: buffer)
        session.recorder = recorder
        let check = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                recorder.start(checked: { continuation.resume(returning: $0) }) { [weak self] failure in
                    Task { @MainActor in self?.recordingEnded(failure, by: recorder) }
                }
            }
        } onCancel: {
            recorder.cancel()
        }
        guard generation == mine else {
            recorder.cancel()
            throw CancellationError()
        }
        switch check {
        case .recording:
            session.hasRecorded = true
            if let reader = buffer.reader(at: nil) {
                publishTimeshift()
                return timeshiftBytes(reader)
            }
            session.stopRecording(.cannotRecord)
        case .untouched:
            // The connection plays on; only the buffer goes.
            session.recorder = nil
            session.stopRecording(.cannotRecord)
            publishTimeshift()
            return SeekableSource(bytes, url: url, session: self.session)
        case .consumed:
            session.stopRecording(.cannotRecord)
        }
        publishTimeshift()
        log("demux timeshift \(redacted(url)) cannot record")
        let fresh = HTTPByteStream(url: url, session: self.session)
        try await fresh.open()
        guard generation == mine else {
            fresh.cancel()
            throw CancellationError()
        }
        return SeekableSource(fresh, url: url, session: self.session)
    }

    private func makeTimeshiftSession(url: URL, request: TimeshiftRequest) -> TimeshiftSession {
        guard let free = request.store.freeBytes(), let cap = request.limits.usableBytes(free: free),
            let folder = try? request.store.makeSession()
        else { return TimeshiftSession(url: url, request: request, recording: .storageShort) }
        let buffer = TimeshiftBuffer(directory: folder, limits: request.limits, byteCap: cap, files: request.files, now: request.now)
        let session = TimeshiftSession(url: url, request: request, folder: folder, buffer: buffer)
        buffer.onEvent = { [weak self, weak session] event in
            Task { @MainActor in
                guard let self, let session, self.timeshift === session else { return }
                await self.handle(event)
            }
        }
        return session
    }

    private func timeshiftBytes(_ reader: TimeshiftReader) -> TimeshiftBytes {
        timeshift?.reader?.cancel()
        timeshift?.reader = reader
        timeshift?.runStart = nil
        return TimeshiftBytes(reader)
    }

    /// A run on the buffer queued its first frame at `time` on the stream's clock.
    func timeshiftRunStarted(_ source: any DemuxBytes, at time: CMTime) {
        guard let bytes = source as? TimeshiftBytes, let session = timeshift, session.reader === bytes.reader else { return }
        session.runStart = (bytes.reader.start, time)
        publishTimeshift()
    }

    // MARK: Moving in time

    public func seek(to date: Date) async throws {
        guard let session = timeshift, let buffer = session.recordingBuffer, let window = buffer.window,
            let reader = buffer.reader(at: window.clamped(date))
        else { throw SeekRefusal.live }
        try await restart(on: reader)
    }

    public func seekToLive() async {
        guard let reader = timeshift?.recordingBuffer?.reader(at: nil) else { return }
        try? await restart(on: reader)
    }

    /// Starts a new run on `reader`, keeping play or pause and the connection.
    private func restart(on reader: TimeshiftReader) async throws {
        guard let request else { return reader.cancel() }
        let playing = wantsPlay || state == .playing || state == .buffering
        generation += 1
        let mine = generation
        release()
        wantsPlay = playing
        set(.loading)
        timeshift?.playhead = reader.start
        do {
            try await startRun(timeshiftBytes(reader), url: request.url, options: request.options, origin: nil, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            close()
            set(.failed(failure))
            throw failure
        } catch {
            throw CancellationError()
        }
        guard generation == mine else { return }
        if !playing { set(.paused) }
        publishTimeshift()
    }

    // MARK: Ends, gaps and failures

    /// The run on the buffer stopped reading and its last frame played:
    /// at a gap it jumps to live, and when its chunk was dropped it goes on
    /// from the earliest point. False when the drop is not the buffer's, so
    /// the engine treats it as a lost stream.
    func timeshiftRunEnded() -> Bool {
        guard let session = timeshift, session.recordingBuffer != nil, let stop = session.reader?.stopped else { return false }
        switch stop {
        case .gap:
            let wasBehind = !currentStatus.isAtLive(tolerance: session.request.limits.liveEdgeTolerance)
            Task {
                await seekToLive()
                if wasBehind { say(.skippedToLive) }
            }
            return true
        case .dropped:
            Task { await resumeFromEarliest() }
            return true
        case .end:
            return false
        }
    }

    private func handle(_ event: TimeshiftEvent) async {
        switch event {
        case .reachedReader:
            await resumeFromEarliest()
        case .writeFailed(let storageFull):
            await stopRecordingAndGoLive(storageFull ? .storageFull(wasBehind: isBehind) : .rewindFailed(wasBehind: isBehind))
        case .readFailed:
            await stopRecordingAndGoLive(.rewindFailed(wasBehind: isBehind))
        }
    }

    private var isBehind: Bool {
        guard let session = timeshift else { return false }
        return state == .paused || !currentStatus.isAtLive(tolerance: session.request.limits.liveEdgeTolerance)
    }

    /// The hour or the cap reached the paused point: play from the earliest
    /// point kept (timeshift-catch-up-and-start-over/when-the-buffer-runs-out).
    private func resumeFromEarliest() async {
        guard let reader = timeshift?.recordingBuffer?.reader(at: .distantPast) else { return }
        wantsPlay = true
        try? await restart(on: reader)
        say(.bufferFull)
    }

    /// Recording failed partway: the buffer goes and live plays straight
    /// from a new connection, without stopping
    /// (timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded).
    private func stopRecordingAndGoLive(_ notice: TimeshiftNotice) async {
        guard let session = timeshift, session.recording == .recording else { return }
        session.stopRecording(.stopped)
        say(notice)
        log("demux timeshift stopped: \(notice)")
        generation += 1
        release()
        reopensOnPlay = false
        await startAgain()
    }

    /// The recorder's connection ended. At live and playing, the engine
    /// reconnects as for any drop and the buffer carries on after a gap;
    /// paused or behind, playback goes on from the buffer while the
    /// recorder reconnects on its own.
    func recordingEnded(_ failure: PlaybackFailure?, by recorder: TimeshiftRecorder) {
        guard let session = timeshift, session.recorder === recorder, let buffer = session.recordingBuffer else { return }
        session.recorder = nil
        buffer.markGap()
        let atLive = currentStatus.isAtLive(tolerance: session.request.limits.liveEdgeTolerance)
        if atLive, state == .playing || state == .buffering {
            dropped(failure ?? .stoppedSendingData)
            return
        }
        reconnectRecorder(after: failure ?? .stoppedSendingData)
    }

    private func reconnectRecorder(after failure: PlaybackFailure) {
        guard let session = timeshift, let buffer = session.recordingBuffer else { return }
        guard let next = session.budget.dropped(failure, at: .now) else {
            buffer.finish()
            return
        }
        let url = session.url
        let network = self.session
        let sleep = self.sleep
        log("demux timeshift reconnect \(next.attempt) \(redacted(url))")
        session.reconnect = Task { [weak self] in
            do {
                try await sleep(next.delay)
                let bytes = HTTPByteStream(url: url, session: network)
                try await bytes.open()
                guard !Task.isCancelled, let self, self.timeshift === session else { return bytes.cancel() }
                buffer.markGap()
                let recorder = TimeshiftRecorder(bytes: bytes, buffer: buffer)
                session.recorder = recorder
                recorder.start(checked: { _ in }) { [weak self] failure in
                    Task { @MainActor in self?.recordingEnded(failure, by: recorder) }
                }
                session.budget.playing(at: .now)
            } catch {
                guard !Task.isCancelled else { return }
                self?.reconnectRecorder(after: (error as? PlaybackFailure) ?? .unreachable)
            }
        }
    }

    private func say(_ notice: TimeshiftNotice) {
        timeshift?.say(notice)
        publishTimeshift()
    }

    // MARK: Reporting

    /// What the buffer holds and where playback is now.
    var currentStatus: TimeshiftStatus {
        guard let session = timeshift else { return .off }
        var playhead = session.playhead
        if let start = session.runStart, current?.start != nil {
            let elapsed = CMTimeSubtract(synchronizer.currentTime(), start.time)
            if elapsed.isNumeric { playhead = start.date.addingTimeInterval(max(0, elapsed.seconds)) }
        }
        let window = session.recordingBuffer?.window
        if let found = playhead, let window { playhead = window.clamped(found) }
        session.playhead = playhead
        return TimeshiftStatus(
            recording: session.recording, window: window, playhead: window == nil ? nil : playhead, notice: session.notice,
            noticeCount: session.noticeCount)
    }

    func publishTimeshift() {
        timeshiftCast.sendIfChanged(currentStatus)
    }

    public func timeshift() async -> AsyncStream<TimeshiftStatus> { timeshiftCast.stream() }
}
