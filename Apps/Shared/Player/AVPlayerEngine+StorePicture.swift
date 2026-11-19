#if DEBUG
    import AVFoundation

    extension AVPlayerEngine {
        /// A clip looping on a muted player, which the store screenshots
        /// draw on every player surface (`UITestingStoreShots`). Debug builds only.
        @MainActor
        final class StorePicture {
            private let player = AVQueuePlayer()
            private let looper: AVPlayerLooper

            init(url: URL) {
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                player.isMuted = true
                player.preventsDisplaySleepDuringVideoPlayback = false
                player.play()
            }

            func attach(to layer: AVPlayerLayer) {
                if layer.player !== player { layer.player = player }
            }
        }
    }
#endif
