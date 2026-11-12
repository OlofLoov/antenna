#if os(tvOS)
    import AntennaCore
    import Foundation

    extension ShellModel {
        /// Select or Watch on `channel` in the channel overlay: another
        /// channel tunes (tv-channel-overlay/select-changes-channel); the
        /// playing one carries on, resumes when paused, and loads again
        /// when it failed or never started
        /// (tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it).
        /// Either way the overlay closes on full-screen Live.
        func pickFromOverlay(_ channel: Channel) async {
            if channel == tuned {
                switch await engine.state {
                // Watch is the user's own play, so it ends their pause too.
                case .paused: await player.timeshift.play()
                case .failed, .idle: tune(channel)
                case .loading, .playing, .buffering, .reconnecting, .ended: break
                }
            }
            await pick(channel)
        }

        /// Play/pause with the overlay open pauses or resumes the video; the overlay stays.
        func togglePlayback() async {
            if await engine.state == .paused {
                await player.timeshift.play()
            } else {
                await player.timeshift.pause()
            }
        }
    }

    extension PlaybackState {
        /// Failed, or idle after a movie stopped it.
        var hasStopped: Bool {
            switch self {
            case .failed, .idle: true
            case .loading, .playing, .paused, .buffering, .reconnecting, .ended: false
            }
        }
    }
#endif
