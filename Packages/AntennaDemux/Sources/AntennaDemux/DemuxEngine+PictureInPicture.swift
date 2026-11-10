@preconcurrency import AVFoundation
import AntennaCore
import CoreMedia
import Foundation

#if os(iOS) || os(tvOS)
    import AVKit
#endif

extension DemuxEngine {
    /// The span the Picture in Picture window shows: unbounded for live TV,
    /// so it has no skip buttons and no scrubber, and the film's length,
    /// starting at its first picture, otherwise.
    nonisolated static func pictureInPictureRange(start: CMTime?, duration: CMTime?, isLive: Bool) -> CMTimeRange {
        guard !isLive, let start, let duration, start.isNumeric, duration.isNumeric else {
            return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
        }
        return CMTimeRange(start: start, duration: duration)
    }

    var pictureInPictureRange: CMTimeRange {
        Self.pictureInPictureRange(start: current?.start?.startTime, duration: current?.start?.duration, isLive: isLive)
    }
}

#if os(iOS) || os(tvOS)
    extension DemuxEngine {
        /// Lets the picture continue in the Picture in Picture window when
        /// the user leaves the app (playback-engine/leaving-the-app-phone-calls-and-picture-in-picture).
        /// The window's play and pause act on this engine; it shows 15-second
        /// skips on films and none on live TV.
        public func enablePictureInPicture() {
            guard pictureInPicture == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
            let playback = PictureInPicturePlayback(engine: self)
            let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoLayer, playbackDelegate: playback)
            let controller = AVPictureInPictureController(contentSource: source)
            #if os(iOS)
                controller.canStartPictureInPictureAutomaticallyFromInline = true
            #endif
            controller.requiresLinearPlayback = isLive
            pictureInPicture = controller
            pictureInPicturePlayback = playback
        }

        /// True while the picture plays, or can go on playing, in the
        /// Picture in Picture window once the app leaves the screen.
        public var continuesInPictureInPicture: Bool {
            guard let pictureInPicture else { return false }
            return pictureInPicture.isPictureInPictureActive || pictureInPicture.isPictureInPicturePossible
        }

        /// Tells the window the engine's play state or span changed.
        func pictureInPictureChanged() {
            pictureInPicture?.requiresLinearPlayback = isLive
            pictureInPicture?.invalidatePlaybackState()
        }
    }

    /// Answers the Picture in Picture window for a `DemuxEngine`.
    @MainActor
    final class PictureInPicturePlayback: NSObject, @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
        weak var engine: DemuxEngine?

        init(engine: DemuxEngine) {
            self.engine = engine
        }

        func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
            guard let engine else { return }
            Task { playing ? await engine.play() : await engine.pause() }
        }

        func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
            engine?.pictureInPictureRange ?? CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
        }

        func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
            engine.map { $0.state != .playing && $0.state != .buffering } ?? true
        }

        func pictureInPictureController(
            _ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions
        ) {}

        func pictureInPictureController(
            _ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime,
            completion completionHandler: @escaping () -> Void
        ) {
            guard let engine, let origin = engine.current?.start?.origin else {
                completionHandler()
                return
            }
            let now = CMTimeSubtract(engine.synchronizer.currentTime(), origin)
            let target = max(0, CMTimeAdd(now, skipInterval).seconds)
            Task {
                try? await engine.seek(to: .seconds(target))
                completionHandler()
            }
        }
    }
#endif
