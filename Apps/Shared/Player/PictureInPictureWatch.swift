import AVKit
import AntennaCore
import AntennaDemux

/// What the player model needs from Picture in Picture
/// (player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad).
@MainActor
struct PictureInPictureHooks {
    /// Yields true while the picture plays in the small window.
    var activity: () -> AsyncStream<Bool>
    /// Closes the window, when one is open.
    var stop: () -> Void

    /// Nothing ever opens.
    static let none = PictureInPictureHooks(activity: { AsyncStream { $0.yield(false) } }, stop: {})
}

#if os(iOS)
    /// Watches the Picture in Picture window of both engines: when it opens,
    /// when the user restores the app from it, and when the user closes it,
    /// which pauses the channel.
    @MainActor
    final class PictureInPictureWatch: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
        private let engine: any PlaybackEngine
        private let cast = Broadcast(false)
        private var restoring = false

        init(engine: any PlaybackEngine) {
            self.engine = engine
            super.init()
            AVPlayerEngine.resolve(engine)?.pictureInPictureDelegate = self
            DemuxEngine.resolve(engine)?.pictureInPictureDelegate = self
        }

        var hooks: PictureInPictureHooks {
            PictureInPictureHooks(
                activity: { [cast] in cast.stream() },
                stop: { [weak self] in self?.stop() })
        }

        private func stop() {
            AVPlayerEngine.resolve(engine)?.pictureInPicture?.stopPictureInPicture()
            DemuxEngine.resolve(engine)?.stopPictureInPicture()
        }

        func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
            started()
        }

        func pictureInPictureController(
            _ controller: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            restoringApp()
            completionHandler(true)
        }

        func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
            stopped()
        }

        // MARK: What each event does

        func started() {
            cast.send(true)
        }

        func restoringApp() {
            restoring = true
        }

        /// Closing the window pauses; restoring the app plays on with no reload.
        func stopped() {
            cast.send(false)
            if !restoring { Task { [engine] in await engine.pause() } }
            restoring = false
        }
    }
#endif

extension PictureInPictureHooks {
    /// The window of `engine`'s players on iPhone and iPad; nothing elsewhere.
    static func app(_ engine: any PlaybackEngine) -> PictureInPictureHooks {
        #if os(iOS)
            let watch = PictureInPictureWatch(engine: engine)
            return PictureInPictureHooks(activity: { watch.hooks.activity() }, stop: { watch.hooks.stop() })
        #else
            .none
        #endif
    }
}
