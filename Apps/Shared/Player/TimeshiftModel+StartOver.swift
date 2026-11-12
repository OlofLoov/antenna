import AntennaCore
import Foundation

/// A catch-up programme playing in place of live TV.
struct CatchupPlayback: Equatable {
    var channel: Channel
    var programme: Programme
    /// Where in the programme the stream playing starts.
    var start: Date
}

/// Start over (timeshift-catch-up-and-start-over capability): whether it
/// shows, and playing the programme on now from its start through the
/// provider's catch-up, or the buffer when there is none.
extension TimeshiftModel {
    /// Works out Start over again every few seconds, so it appears or goes
    /// within five seconds of a change
    /// (timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work).
    func checkStartOver() async {
        while !Task.isCancelled {
            await refreshStartOver()
            do { try await Task.sleep(for: startOverCheck) } catch { return }
        }
    }

    func refreshStartOver() async {
        guard catchup == nil, let playing = nowPlaying() else {
            startOver = .none
            return
        }
        let now = now()
        var address: URL?
        if let programme = playing.programme, programme.isAiring(at: now) {
            let request = CatchupRequest(start: programme.start, duration: programme.stop.timeIntervalSince(programme.start), now: now)
            address = await catchupAddress(playing.channel, request)
        }
        let window = status.recording == .recording ? status.window : nil
        startOver = StartOverPlanner.plan(
            channel: playing.channel, playing: playing.channel, programme: playing.programme, now: now, window: window
        ) { _ in address }
    }

    /// Start over chosen: catch-up when it can be built, else the buffer
    /// jumps to the programme's start with no reload
    /// (timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning).
    func startOverNow() {
        guard let playing = nowPlaying() else { return }
        switch startOver {
        case .catchup(let url, let programme):
            preview = nil
            userPaused = false
            let reachesStart = (status.window?.start).map { $0 <= programme.start } ?? false
            catchup = CatchupPlayback(channel: playing.channel, programme: programme, start: programme.start)
            catchupPosition = 0
            startOver = .none
            startingCatchup = true
            catchupLoad?.cancel()
            catchupLoad = Task { await playCatchup(url, parking: true, fallback: reachesStart ? programme.start : nil) }
        case .buffer(let programme):
            userPaused = false
            Task {
                try? await engineForStartOver.seek(to: programme.start)
                await engineForStartOver.play()
            }
        case .none:
            break
        }
    }

    /// Plays `url`. On the first catch-up load the live buffer is parked
    /// and kept until catch-up plays; when it fails to start, live comes
    /// back with its buffer at `fallback`, or at live saying Start over is
    /// not available (timeshift-catch-up-and-start-over/when-the-provider-s-catch-up-fails).
    private func playCatchup(_ url: URL, parking: Bool, fallback: Date?) async {
        let engine = engineForStartOver
        if parking { await engine.parkTimeshift() }
        do {
            try await engine.load(url, options: PlaybackOptions(isLive: false))
            guard !Task.isCancelled else { return }
            await engine.play()
            startingCatchup = false
            await engine.dropParkedTimeshift()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            catchup = nil
            do {
                try await engine.resumeParkedTimeshift(at: fallback)
            } catch {
                startingCatchup = false
                return restartChannel()
            }
            startingCatchup = false
            if fallback == nil { announce(TimeshiftText.startOverUnavailable) }
        }
    }

    /// Plays the catch-up programme from `date`, which never goes before its
    /// start. Skips within 400 ms of each other load once.
    func loadCatchup(at date: Date, coalesced: Bool) {
        guard var playing = catchup else { return }
        let start = max(date, playing.programme.start)
        playing.start = start
        catchup = playing
        catchupPosition = 0
        catchupLoad?.cancel()
        let wait = coalesced ? limits.catchupCoalesce : .zero
        catchupLoad = Task {
            do { try await Task.sleep(for: wait) } catch { return }
            let request = CatchupRequest(start: start, duration: playing.programme.stop.timeIntervalSince(start), now: now())
            guard let url = await catchupAddress(playing.channel, request) else { return returnToLive() }
            preview = nil
            await playCatchup(url, parking: false, fallback: nil)
        }
    }

    /// Leaves catch-up for the live channel, which loads again with a new buffer.
    func returnToLive() {
        catchupLoad?.cancel()
        catchup = nil
        preview = nil
        startingCatchup = false
        userPaused = false
        restartChannel()
    }

    /// Follows the catch-up stream's position; reaching now returns to live.
    func observeCatchupPosition() async {
        for await position in await engineForStartOver.position() {
            catchupMoved(to: position.time / .seconds(1))
        }
    }

    /// The end of the catch-up stream returns to live.
    func observeCatchupEnd() async {
        for await state in await engineForStartOver.states() {
            if state == .ended, catchup != nil { returnToLive() }
        }
    }

    private func catchupMoved(to seconds: TimeInterval) {
        guard catchup != nil, !startingCatchup else { return }
        catchupPosition = seconds
        if let playhead, playhead >= now() { returnToLive() }
    }
}
