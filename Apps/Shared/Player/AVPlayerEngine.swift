import AVFoundation
import AntennaCore
import Foundation

/// Apple's player behind `PlaybackEngine`. It plays HLS and the files the
/// system can read. Until the demuxing engine exists it also stands behind
/// the demuxer route, so a raw MPEG-TS stream fails here as unreadable.
///
/// Before each open it probes the address once through the ephemeral
/// playback session, so refusals map to the same reasons the demuxer will
/// give, and HLS at a raw-looking address plays as HLS.
@MainActor
final class AVPlayerEngine: PlaybackEngine {
    /// What is open now.
    private struct Stream: Sendable {
        var url: URL
        var options: PlaybackOptions
        var isLive: Bool
        var acceptsRanges: Bool
    }

    private let player = AVPlayer()
    private let session: URLSession
    private let sleep: @Sendable (Duration) async throws -> Void

    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    private let cuesCast = Broadcast([SubtitleCue]())

    private var stream: Stream?
    private var generation = 0
    private var wantsPlay = false
    private var hasPlayed = false
    private var budget = ReconnectBudget()
    private var reconnect: Task<Void, Never>?
    private var opening: Task<Stream, any Error>?
    private var stallWatch: Task<Void, Never>?
    private var itemObservation: NSKeyValueObservation?
    private var itemTokens: [any NSObjectProtocol] = []
    private var playerObservation: NSKeyValueObservation?

    /// `sleep` waits between retries and times the stall budget; tests pass
    /// a faster one.
    init(
        session: URLSession = PlaybackNetwork.makeSession(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.session = session
        self.sleep = sleep
        playerObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            Task { @MainActor in self?.timeControlChanged() }
        }
    }

    /// The Apple player engine behind `engine`: the engine itself, or the
    /// system route of a `RoutedEngine`.
    static func resolve(_ engine: any PlaybackEngine) -> AVPlayerEngine? {
        (engine as? AVPlayerEngine) ?? ((engine as? RoutedEngine)?.system as? AVPlayerEngine)
    }

    /// Draws this engine's picture into `layer`.
    func attach(to layer: AVPlayerLayer) {
        if layer.player !== player { layer.player = player }
    }

    var state: PlaybackState { stateCast.value }

    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

    // MARK: Load and stop

    /// How long Apple's player takes to close the old connection after its
    /// item is removed. It closes it from another process, so the engine
    /// waits this long before it opens the next one. Measured at under 100 ms
    /// on a Mac.
    static let releaseGrace = Duration.milliseconds(200)

    func load(_ url: URL, options: PlaybackOptions) async throws {
        generation += 1
        let mine = generation
        let hadItem = player.currentItem != nil
        closeStream()
        stream = nil
        wantsPlay = false
        hasPlayed = false
        budget = ReconnectBudget()
        set(.loading)
        let task = Task { [weak self, sleep] in
            if hadItem { try await Task.sleep(for: Self.releaseGrace) }
            return try await RetryPolicy.tune.run(sleep: sleep) { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.open(url, options: options, generation: mine)
            }
        }
        opening = task
        do {
            let opened = try await task.value
            guard generation == mine else { throw CancellationError() }
            opening = nil
            stream = opened
            if wantsPlay { player.play() }
        } catch let failure as PlaybackFailure {
            guard generation == mine else { throw CancellationError() }
            closeStream()
            set(.failed(failure))
            throw failure
        } catch {
            guard generation == mine else { throw CancellationError() }
            throw error
        }
    }

    func stop() async {
        generation += 1
        closeStream()
        stream = nil
        wantsPlay = false
        hasPlayed = false
        set(.idle)
    }

    // MARK: Play and pause

    func play() async {
        switch state {
        case .loading:
            wantsPlay = true
            if stream != nil { player.play() }
        case .paused:
            wantsPlay = true
            player.play()
        case .idle, .playing, .buffering, .reconnecting, .ended, .failed:
            return
        }
    }

    func pause() async {
        switch state {
        case .loading:
            wantsPlay = false
            player.pause()
        case .playing, .buffering:
            wantsPlay = false
            stallWatch?.cancel()
            player.pause()
            set(.paused)
        case .idle, .paused, .reconnecting, .ended, .failed:
            return
        }
    }

    // MARK: Seek and tracks

    func seek(to time: Duration) async throws {
        throw SeekRefusal.notSeekable
    }

    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}

    // MARK: Streams

    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }

    // MARK: Opening

    /// Probes `url`, puts a new item on the player and waits until it is
    /// ready. Throws a `PlaybackFailure`, or `CancellationError` once a newer
    /// load or stop took over.
    private func open(_ url: URL, options: PlaybackOptions, generation mine: Int) async throws -> Stream {
        removeItem()
        var probe: StreamProbe?
        if url.scheme == "http" || url.scheme == "https" {
            probe = try await StreamProbe.run(url, session: session)
        }
        guard generation == mine else { throw CancellationError() }
        if probe?.sniff == .html { throw PlaybackFailure.unreadable }
        var assetOptions: [String: Any] = [AVURLAssetHTTPCookiesKey: [HTTPCookie]()]
        if probe?.sniff == .hls, url.pathExtension.lowercased() != "m3u8" {
            assetOptions[AVURLAssetOverrideMIMETypeKey] = "application/vnd.apple.mpegurl"
        }
        let item = AVPlayerItem(asset: AVURLAsset(url: url, options: assetOptions))
        item.preferredForwardBufferDuration = 8
        observe(item)
        player.replaceCurrentItem(with: item)
        while item.status != .readyToPlay {
            if item.status == .failed {
                for event in item.errorLog()?.events ?? [] {
                    print("DIAG errorLog:", event.errorStatusCode, event.errorDomain, event.errorComment ?? "-", event.uri ?? "-")
                }
                for event in item.accessLog()?.events ?? [] {
                    print("DIAG accessLog:", event.uri ?? "-", event.numberOfBytesTransferred)
                }
                throw Self.failure(from: item.error)
            }
            try await Task.sleep(for: .milliseconds(50))
            guard generation == mine else { throw CancellationError() }
        }
        let isLive = options.isLive ?? item.duration.isIndefinite
        return Stream(url: url, options: options, isLive: isLive, acceptsRanges: probe?.acceptsRanges ?? true)
    }

    private func observe(_ item: AVPlayerItem) {
        let id = ObjectIdentifier(item)
        itemObservation = item.observe(\.status) { [weak self] _, _ in
            Task { @MainActor in self?.itemStatusChanged(id) }
        }
        let failed: @Sendable (Notification) -> Void = { [weak self] note in
            let failure = Self.failure(from: note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error)
            MainActor.assumeIsolated { self?.dropped(failure) }
        }
        let center = NotificationCenter.default
        itemTokens = [
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main, using: failed)
        ]
    }

    /// Closes the connection: cancels any reconnect and takes the item off the player.
    private func closeStream() {
        opening?.cancel()
        opening = nil
        reconnect?.cancel()
        reconnect = nil
        stallWatch?.cancel()
        stallWatch = nil
        removeItem()
        presentationCast.send(nil)
        tracksCast.send(.empty)
        positionCast.send(.zero)
        cuesCast.send([])
    }

    private func removeItem() {
        itemObservation?.invalidate()
        itemObservation = nil
        itemTokens.forEach(NotificationCenter.default.removeObserver)
        itemTokens = []
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: Observing

    private func timeControlChanged() {
        guard player.currentItem != nil, stream != nil else { return }
        switch player.timeControlStatus {
        case .playing:
            stallWatch?.cancel()
            stallWatch = nil
            switch state {
            case .loading, .buffering, .reconnecting, .paused:
                wantsPlay = true
                hasPlayed = true
                budget.playing(at: .now)
                set(.playing)
            case .idle, .playing, .ended, .failed:
                break
            }
        case .waitingToPlayAtSpecifiedRate:
            guard state == .playing else { return }
            set(.buffering)
            startStallWatch()
        case .paused:
            // Picture in Picture and the system can pause the player directly.
            guard state == .playing || state == .buffering, player.currentItem?.status == .readyToPlay else { return }
            wantsPlay = false
            stallWatch?.cancel()
            set(.paused)
        @unknown default:
            break
        }
    }

    private func itemStatusChanged(_ id: ObjectIdentifier) {
        guard let item = player.currentItem, ObjectIdentifier(item) == id, item.status == .failed, stream != nil else { return }
        dropped(Self.failure(from: item.error))
    }

    private func startStallWatch() {
        stallWatch?.cancel()
        let mine = generation
        stallWatch = Task { [weak self, sleep] in
            do {
                try await sleep(RetryPolicy.stallBudget)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.generation == mine, self.state == .buffering else { return }
            self.dropped(.stoppedSendingData)
        }
    }

    // MARK: Reconnecting

    /// The stream was lost after it opened. Reconnects with numbered
    /// attempts, or fails with `failure` when it is not retried or the
    /// attempts ran out.
    private func dropped(_ failure: PlaybackFailure) {
        guard let stream, reconnect == nil else { return }
        guard hasPlayed, let next = budget.dropped(failure, at: .now) else {
            closeStream()
            set(.failed(failure))
            return
        }
        let resumeAt = stream.isLive ? nil : player.currentTime()
        stallWatch?.cancel()
        set(.reconnecting(attempt: next.attempt, of: budget.maxAttempts))
        let mine = generation
        reconnect = Task { [weak self, sleep] in
            do {
                try await sleep(next.delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.generation == mine else { return }
            await self.reopen(stream, at: resumeAt, generation: mine)
        }
    }

    private func reopen(_ previous: Stream, at time: CMTime?, generation mine: Int) async {
        reconnect = nil
        do {
            let opened = try await open(previous.url, options: previous.options, generation: mine)
            guard generation == mine else { return }
            stream = opened
            if let time, !opened.isLive, opened.acceptsRanges {
                await player.currentItem?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            guard generation == mine else { return }
            player.play()
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            dropped(failure)
        } catch {
            return
        }
    }

    // MARK: Reasons

    private func set(_ new: PlaybackState) {
        stateCast.sendIfChanged(new)
    }

    /// The reason for an error Apple's player reports. Only the code is
    /// read; the error and its user info, which can hold the address, are
    /// dropped.
    nonisolated static func failure(from error: (any Error)?) -> PlaybackFailure {
        var trace = error as NSError?
        var chain: [String] = []
        while let nsError = trace {
            chain.append("\(nsError.domain) \(nsError.code)")
            trace = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        print("DIAG engine failure:", chain.isEmpty ? "no error" : chain.joined(separator: " <- "))
        guard let error else { return .unreadable }
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == NSURLErrorDomain { return PlaybackFailure(URLError(URLError.Code(rawValue: nsError.code))) }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return .unreadable
    }
}
