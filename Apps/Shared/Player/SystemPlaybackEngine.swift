#if os(tvOS)
    import AVFoundation
    import AntennaCore
    import Foundation

    /// The AVPlayer engine behind `PlaybackEngine`. Both `EngineRouter`
    /// routes, demuxer included, play through `AVPlayer` until the demuxing
    /// engine exists. It reports state only; format, tracks, time and cues
    /// stay empty for now.
    @MainActor
    final class SystemPlaybackEngine: PlaybackEngine {
        /// The player a video surface draws. Only the engine changes what it plays.
        let player = AVPlayer()
        private var failure: PlaybackFailure?
        private var loading = false
        private var generation = 0
        private let stateBroadcast = Broadcast(PlaybackState.idle)

        var state: PlaybackState {
            if let failure { return .failed(failure) }
            if player.currentItem?.status == .failed { return .failed(.unreadable) }
            if loading { return .loading }
            guard player.currentItem != nil else { return .idle }
            switch player.timeControlStatus {
            case .playing, .waitingToPlayAtSpecifiedRate: return .playing
            case .paused: return .paused
            @unknown default: return .paused
            }
        }

        var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

        /// Replaces the current item and returns once it is ready to play.
        /// Throws `PlaybackFailure.unreadable` when the item fails first, and
        /// `CancellationError` when a newer `load` replaced it.
        func load(_ url: URL, options: PlaybackOptions) async throws {
            switch EngineRouter.route(for: url) {
            case .system, .demuxer:
                break
            }
            generation += 1
            let mine = generation
            failure = nil
            loading = true
            publish()
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            while true {
                guard generation == mine else { throw CancellationError() }
                switch item.status {
                case .readyToPlay:
                    loading = false
                    publish()
                    return
                case .failed:
                    loading = false
                    failure = .unreadable
                    publish()
                    throw PlaybackFailure.unreadable
                case .unknown:
                    break
                @unknown default:
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        func play() async {
            player.play()
            publish()
        }

        func pause() async {
            player.pause()
            publish()
        }

        func stop() async {
            generation += 1
            loading = false
            failure = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            publish()
        }

        func seek(to time: Duration) async throws { throw SeekRefusal.notSeekable }
        func selectAudio(_ id: MediaTrack.ID) async {}
        func selectSubtitle(_ id: MediaTrack.ID?) async {}
        func states() async -> AsyncStream<PlaybackState> { stateBroadcast.stream() }
        func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
        func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
        func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
        func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }

        private func publish() {
            stateBroadcast.sendIfChanged(state)
        }
    }
#endif
