import AVFoundation
import AntennaCore
import Foundation
import os

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
    private let log: @Sendable (String) -> Void

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
    private var firstFrameWatch: Task<Void, Never>?

    /// Data but no picture for this long fails the stream as unreadable.
    static let firstFrameTimeout = Duration.seconds(15)

    private nonisolated static let logger = Logger(subsystem: "se.codecrave.antenna", category: "playback")

    /// `sleep` waits between retries and times the stall budget; tests pass
    /// a faster one. `log` gets every line the engine logs, each made only of
    /// the redacted address and a reason.
    init(
        session: URLSession = PlaybackNetwork.makeSession(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        log: @escaping @Sendable (String) -> Void = { AVPlayerEngine.logger.info("\($0, privacy: .public)") }
    ) {
        self.session = session
        self.sleep = sleep
        self.log = log
        // Apple's player stores a stream server's cookies in the shared
        // storage even when it sends none, and a cookie can carry the token.
        // Nothing else in the app uses the shared storage.
        HTTPCookieStorage.shared.cookieAcceptPolicy = .never
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
        log("load \(redacted(url))")
        do {
            try StreamAddress.check(url)
        } catch {
            log("failed \(redacted(url)) \(PlaybackFailure.unreadable)")
            set(.failed(.unreadable))
            throw PlaybackFailure.unreadable
        }
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
            if wantsPlay { startPlayback() }
        } catch let failure as PlaybackFailure {
            guard generation == mine else { throw CancellationError() }
            log("failed \(redacted(url)) \(failure)")
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
            if stream != nil { startPlayback() }
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

}

extension AVPlayerEngine {
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
        // A web page, or raw video at an HLS address, is not a stream Apple's player can read.
        if probe?.sniff == .html { throw PlaybackFailure.unreadable }
        if probe?.sniff == .mpegTS, url.pathExtension.lowercased() == "m3u8" { throw PlaybackFailure.unreadable }
        var assetOptions: [String: Any] = [AVURLAssetHTTPCookiesKey: [HTTPCookie]()]
        if probe?.sniff == .hls, url.pathExtension.lowercased() != "m3u8" {
            assetOptions[AVURLAssetOverrideMIMETypeKey] = "application/vnd.apple.mpegurl"
        }
        let item = AVPlayerItem(asset: AVURLAsset(url: url, options: assetOptions))
        item.preferredForwardBufferDuration = 8
        observe(item)
        player.replaceCurrentItem(with: item)
        while item.status != .readyToPlay {
            if item.status == .failed { throw Self.failure(from: item.error, host: url.host()) }
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
        let host = (item.asset as? AVURLAsset)?.url.host()
        let failed: @Sendable (Notification) -> Void = { [weak self] note in
            let failure = Self.failure(from: note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error, host: host)
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
        firstFrameWatch?.cancel()
        firstFrameWatch = nil
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
            firstFrameWatch?.cancel()
            firstFrameWatch = nil
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
        dropped(Self.failure(from: item.error, host: stream?.url.host()))
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
            log("failed \(redacted(stream.url)) \(failure)")
            closeStream()
            set(.failed(failure))
            return
        }
        log("reconnect \(next.attempt)/\(budget.maxAttempts) \(redacted(stream.url)) \(failure)")
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

    /// The reason for an error Apple's player reports. The error itself,
    /// whose user info can hold the address, is not kept.
    nonisolated static func failure(from error: (any Error)?, host: String?) -> PlaybackFailure {
        guard let error else { return .unreadable }
        return PlaybackFailure.fromPlayerError(error, host: host)
    }

    // MARK: First frame

    /// Plays the opened stream and fails it as unreadable when no picture
    /// or sound starts within `firstFrameTimeout`.
    private func startPlayback() {
        player.play()
        guard firstFrameWatch == nil, state == .loading else { return }
        let mine = generation
        firstFrameWatch = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.firstFrameTimeout)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.generation == mine, self.state == .loading, let stream = self.stream else { return }
            self.log("failed \(redacted(stream.url)) \(PlaybackFailure.unreadable)")
            self.closeStream()
            self.set(.failed(.unreadable))
        }
    }
}
