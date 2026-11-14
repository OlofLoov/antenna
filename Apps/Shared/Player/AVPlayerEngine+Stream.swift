import AVFoundation
import AntennaCore
import Foundation

extension AVPlayerEngine {
    // MARK: Opening

    /// Probes `url`, puts a new item on the player, waits until it is ready
    /// and moves a film to `startAt` when that is inside it. Throws a
    /// `PlaybackFailure`, or `CancellationError` once a newer load or stop
    /// took over.
    func open(_ url: URL, options: PlaybackOptions, startAt: Duration?, generation mine: Int) async throws -> Stream {
        removeItem()
        let probe = try await StreamProbe.run(url, session: session)
        guard generation == mine else { throw CancellationError() }
        let isHLSAddress = url.pathExtension.lowercased() == "m3u8"
        // A web page, or raw video at an HLS address, is not a stream Apple's player can read.
        if probe.sniff == .html { throw PlaybackFailure.unreadable }
        if probe.sniff == .mpegTS, isHLSAddress { throw PlaybackFailure.unreadable }
        // Raw video, Matroska or AVI at a file address, such as an episode
        // the panel lists as mp4: the demuxer reads it.
        if probe.sniff.needsDemuxer { throw EngineHandoff.toDemuxer }
        // A file of known length whose server cannot skip: Apple's player
        // cannot read it. Endless radio has no length and plays.
        if probe.sniff != .hls, !probe.acceptsRanges, probe.length != nil, options.isLive != true {
            throw PlaybackFailure.unreadable
        }
        var assetOptions: [String: Any] = [AVURLAssetHTTPCookiesKey: [HTTPCookie]()]
        if probe.sniff == .hls, !isHLSAddress {
            assetOptions[AVURLAssetOverrideMIMETypeKey] = "application/vnd.apple.mpegurl"
        }
        let item = AVPlayerItem(asset: AVURLAsset(url: url, options: assetOptions))
        item.preferredForwardBufferDuration = 8
        applyMaximumVideoHeight(to: item)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        item.add(output)
        videoOutput = output
        addLegibleOutput(to: item)
        observe(item)
        player.replaceCurrentItem(with: item)
        let deadline = ContinuousClock.now + readyTimeout
        while item.status != .readyToPlay {
            if item.status == .failed { throw Self.failure(from: item.error, host: url.host()) }
            // An item can stay unknown for good, for example when no segment
            // ever arrives; without a limit `load` would never return.
            guard ContinuousClock.now < deadline else { throw PlaybackFailure.timedOut }
            try await Task.sleep(for: .milliseconds(50))
            guard generation == mine else { throw CancellationError() }
        }
        try await chooseTracks(for: item, options: options, generation: mine)
        let isLive = options.isLive ?? item.duration.isIndefinite
        let opened = Stream(url: url, options: options, isLive: isLive, canSeek: probe.sniff == .hls || probe.acceptsRanges)
        pictureInPicture?.requiresLinearPlayback = isLive
        if let startAt, !isLive, opened.canSeek, item.duration.isNumeric, startAt.seconds < item.duration.seconds {
            let target = CMTime(seconds: startAt.seconds, preferredTimescale: 600)
            await item.seek(to: target, toleranceBefore: Self.seekTolerance, toleranceAfter: Self.seekTolerance)
            guard generation == mine else { throw CancellationError() }
        }
        return opened
    }

    func observe(_ item: AVPlayerItem) {
        let id = ObjectIdentifier(item)
        itemObservation = item.observe(\.status) { [weak self] _, _ in
            Task { @MainActor in self?.itemStatusChanged(id) }
        }
        let host = (item.asset as? AVURLAsset)?.url.host()
        let failed: @Sendable (Notification) -> Void = { [weak self] note in
            let failure = Self.failure(from: note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error, host: host)
            MainActor.assumeIsolated { self?.dropped(failure) }
        }
        let ended: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.reachedEnd() }
        }
        let center = NotificationCenter.default
        itemTokens = [
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main, using: failed),
            center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main, using: ended),
        ]
        observePresentation(of: item)
    }

    /// Closes the connection: cancels any reconnect and takes the item off the player.
    func closeStream() {
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

    /// Takes the item off the player and cancels its asset's loading, so
    /// Apple's player stops fetching (and retrying) the old address at once
    /// instead of when the asset is freed.
    func removeItem() {
        holdPicture()
        itemObservation?.invalidate()
        itemObservation = nil
        presentationObservations.forEach { $0.invalidate() }
        presentationObservations = []
        selection = nil
        legibleRelay = nil
        videoOutput = nil
        itemTokens.forEach(NotificationCenter.default.removeObserver)
        itemTokens = []
        player.pause()
        let asset = player.currentItem?.asset
        player.replaceCurrentItem(with: nil)
        asset?.cancelLoading()
    }

    // MARK: Ending

    func reachedEnd() {
        guard let stream, !stream.isLive else { return }
        finish()
    }

    /// A film ended: it reports the end, then lets the connection go so
    /// nothing more is fetched until play starts it again.
    func finish() {
        guard let item = player.currentItem, let stream else { return }
        let duration = item.duration.isNumeric ? Duration.seconds(item.duration.seconds) : nil
        reconnect?.cancel()
        reconnect = nil
        stallWatch?.cancel()
        stallWatch = nil
        removeItem()
        wantsPlay = false
        positionCast.send(PlaybackPosition(time: duration ?? .zero, duration: duration, isLive: stream.isLive, canSkip: stream.canSeek))
        set(.ended)
    }

    // MARK: Observing

    func timeControlChanged() {
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
            publishPosition(onlyWhilePlaying: false)
        @unknown default:
            break
        }
    }

    func itemStatusChanged(_ id: ObjectIdentifier) {
        guard let item = player.currentItem, ObjectIdentifier(item) == id, item.status == .failed, stream != nil else { return }
        dropped(Self.failure(from: item.error, host: stream?.url.host()))
    }

    func startStallWatch() {
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

    /// Sends the current time. The periodic observer sends only while
    /// playing; pause and seek send once.
    func publishPosition(onlyWhilePlaying: Bool) {
        guard let stream, let item = player.currentItem else { return }
        if onlyWhilePlaying, state != .playing { return }
        let now = item.currentTime()
        guard now.isNumeric else { return }
        let duration = !stream.isLive && item.duration.isNumeric ? Duration.seconds(item.duration.seconds) : nil
        positionCast.send(
            PlaybackPosition(
                time: .seconds(now.seconds), duration: duration, isLive: stream.isLive, canSkip: !stream.isLive && stream.canSeek))
    }

    // MARK: Reconnecting

    /// The stream was lost after it opened. Reconnects with numbered
    /// attempts, or fails with `failure` when it is not retried or the
    /// attempts ran out.
    func dropped(_ failure: PlaybackFailure) {
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

    func reopen(_ previous: Stream, at time: CMTime?, generation mine: Int) async {
        reconnect = nil
        do {
            let resume = time.flatMap { $0.isNumeric ? Duration.seconds($0.seconds) : nil }
            let opened = try await open(previous.url, options: previous.options, startAt: resume, generation: mine)
            guard generation == mine else { return }
            stream = opened
            player.play()
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            dropped(failure)
        } catch {
            return
        }
    }

    // MARK: Reasons

    func set(_ new: PlaybackState) {
        switch new {
        case .playing:
            hold.clear()
            Task { await publishPresentation() }
        case .failed:
            hold.clear()
        default:
            break
        }
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
    func startPlayback() {
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
