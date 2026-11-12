#if DEBUG
    import AntennaCore
    import Foundation

    /// The buffer the scripted engines of `UITestingLive` and
    /// `UITestingShell` report, for the timeshift UI tests
    /// (timeshift-catch-up-and-start-over capability). Debug builds only.
    ///
    /// `UITESTING_TIMESHIFT` in the launch environment picks a script:
    /// - unset: nothing records, as before.
    /// - `buffer`: each load starts with 20 minutes already recorded.
    /// - `none`: the stream cannot be recorded.
    /// - `short`: too little free storage.
    /// - `full`: as `buffer`; a pause of 2 seconds runs out of buffer and plays on.
    /// - `fail`: as `buffer`; 2 seconds after the first play a write fails.
    /// - `catchup`: as `buffer`, and every channel has catch-up at
    ///   `http://catchup.invalid/…`, which plays.
    /// - `catchup-fail`: as `catchup`, but the catch-up stream fails to start.
    @MainActor
    final class UITestingTimeshift {
        nonisolated static let variable = "UITESTING_TIMESHIFT"

        enum Script: String {
            case buffer, none, short, full, fail, catchup
            case catchupFail = "catchup-fail"
        }

        nonisolated static let catchupHost = "catchup.invalid"

        /// How many minutes each load starts with: `UITESTING_TIMESHIFT_MINUTES`, 20 unless set.
        static var minutes: Double {
            ProcessInfo.processInfo.environment["UITESTING_TIMESHIFT_MINUTES"].flatMap(Double.init) ?? 20
        }

        /// The scripted catch-up address for a channel, with the scripts that have one.
        nonisolated static func address(for channel: Channel, request: CatchupRequest) -> URL? {
            let value = ProcessInfo.processInfo.environment[variable]
            guard value == Script.catchup.rawValue || value == Script.catchupFail.rawValue else { return nil }
            return URL(string: "http://\(catchupHost)/timeshift/secret-user/secret-pass/\(Int(request.start.timeIntervalSince1970)).ts")
        }

        /// True when loading `url` is a scripted catch-up stream that fails.
        static func catchupFails(_ url: URL) -> Bool {
            url.host() == catchupHost && script == .catchupFail
        }

        private var parked = false

        func park() {
            parked = true
        }

        func resume(at date: Date?) throws {
            guard parked else { throw SeekRefusal.live }
            parked = false
            recording = .recording
            playhead = date.map { max($0, start) } ?? Date()
            playing = true
            publish()
        }

        static var script: Script? {
            ProcessInfo.processInfo.environment[variable].flatMap(Script.init(rawValue:))
        }

        let cast = Broadcast(TimeshiftStatus.off)
        /// Called when the script starts playback by itself.
        var played: @MainActor () -> Void = {}
        private var start = Date()
        private var playhead = Date()
        private var playing = false
        private var notices = 0
        private var recording = TimeshiftStatus.Recording.off
        private var ticker: Task<Void, Never>?
        private var scripted: Task<Void, Never>?

        func loaded() {
            guard let script = Self.script else { return }
            let now = Date()
            start = now.addingTimeInterval(-Self.minutes * 60)
            playhead = now
            playing = false
            switch script {
            case .none: recording = .cannotRecord
            case .short: recording = .storageShort
            case .buffer, .full, .fail, .catchup, .catchupFail: recording = .recording
            }
            ticker?.cancel()
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    self?.tick()
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
            publish()
        }

        func play() {
            playing = true
            if Self.script == .fail, scripted == nil {
                scripted = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    self?.failWrite()
                }
            }
            publish()
        }

        func pause() {
            playing = false
            guard Self.script == .full else { return publish() }
            scripted?.cancel()
            scripted = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.runOut()
            }
            publish()
        }

        func stop() {
            ticker?.cancel()
            recording = .off
            publish()
        }

        func seek(to date: Date) {
            playhead = min(max(date, start), Date())
            publish()
        }

        func seekToLive() {
            playhead = Date()
            publish()
        }

        private func tick() {
            if playing { playhead = min(Date(), playhead.addingTimeInterval(0.25)) }
            publish()
        }

        private func runOut() {
            start = Date().addingTimeInterval(-Self.minutes * 60)
            playhead = start
            playing = true
            say(.bufferFull)
            played()
        }

        private func failWrite() {
            let behind = Date().timeIntervalSince(playhead) > 10
            recording = .stopped
            playhead = Date()
            say(.storageFull(wasBehind: behind))
        }

        private var lastNotice: TimeshiftNotice?

        private func say(_ notice: TimeshiftNotice) {
            notices += 1
            lastNotice = notice
            publish()
        }

        private func publish() {
            guard recording == .recording else {
                return cast.send(TimeshiftStatus(recording: recording, notice: lastNotice, noticeCount: notices))
            }
            let window = TimeshiftWindow(start: start, end: Date())
            cast.send(TimeshiftStatus(recording: recording, window: window, playhead: playhead, notice: lastNotice, noticeCount: notices))
        }
    }

    extension UITestingLive.Engine {
        func seek(to date: Date) async throws { buffer.seek(to: date) }
        func seekToLive() async { buffer.seekToLive() }
        func timeshift() async -> AsyncStream<TimeshiftStatus> { buffer.cast.stream() }
        func parkTimeshift() async { buffer.park() }
        func resumeParkedTimeshift(at date: Date?) async throws {
            try buffer.resume(at: date)
            state = .playing
        }
    }

    #if os(tvOS)
        extension UITestingShell.Engine {
            func seek(to date: Date) async throws { buffer.seek(to: date) }
            func seekToLive() async { buffer.seekToLive() }
            func timeshift() async -> AsyncStream<TimeshiftStatus> { buffer.cast.stream() }
            func parkTimeshift() async { buffer.park() }
            func resumeParkedTimeshift(at date: Date?) async throws {
                try buffer.resume(at: date)
                state = .playing
            }
        }
    #endif
#endif
