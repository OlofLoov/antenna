#if os(tvOS)
    import AVFoundation
    import AntennaCore
    import Foundation

    /// The AVPlayer engine behind `PlaybackEngine`. It stands in for spec
    /// 0017's engines: until then both `EngineRouter` routes, demuxer
    /// included, play through `AVPlayer`, as `PlayerView` does today.
    @MainActor
    final class SystemPlaybackEngine: PlaybackEngine {
        /// The player a video surface draws. Only the engine changes what it plays.
        let player = AVPlayer()
        private var failure: String?
        private var loading = false
        private var generation = 0

        enum LoadError: Error, Equatable {
            /// The item could not be played.
            case failed
        }

        var state: PlaybackState {
            if let failure { return .failed(failure) }
            if player.currentItem?.status == .failed { return .failed("The stream stopped.") }
            if loading { return .loading }
            guard player.currentItem != nil else { return .idle }
            switch player.timeControlStatus {
            case .playing, .waitingToPlayAtSpecifiedRate: return .playing
            case .paused: return .paused
            @unknown default: return .paused
            }
        }

        /// Replaces the current item and returns once it is ready to play.
        /// Throws `LoadError.failed` when the item fails first, and
        /// `CancellationError` when a newer `load` replaced it.
        func load(_ url: URL) async throws {
            switch EngineRouter.route(for: url) {
            case .system, .demuxer:
                break
            }
            generation += 1
            let mine = generation
            failure = nil
            loading = true
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            while true {
                guard generation == mine else { throw CancellationError() }
                switch item.status {
                case .readyToPlay:
                    loading = false
                    return
                case .failed:
                    loading = false
                    failure = "The stream could not be played."
                    throw LoadError.failed
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
        }

        func pause() async {
            player.pause()
        }

        func stop() async {
            generation += 1
            loading = false
            failure = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
#endif
