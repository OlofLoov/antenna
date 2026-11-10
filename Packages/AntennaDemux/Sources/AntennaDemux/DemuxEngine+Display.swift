import AntennaCore
import CoreMedia
import Foundation

#if os(tvOS)
    import AVKit
#endif

extension DemuxEngine {
    /// The frame rate became known after the start: report it and match
    /// the TV to it.
    func frameRateFound(_ rate: Double, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        // The run can find the rate before `open` has stored the start; keep
        // it for `open` to use.
        guard var start = current?.start else {
            earlyFrameRate = rate
            return
        }
        guard start.frameRate == nil else { return }
        start.frameRate = rate
        current?.start = start
        publishFormat(start)
        matchDisplay(start)
    }

    /// Asks the TV for the stream's mode when it differs from the last one.
    func matchDisplay(_ start: DemuxStart) {
        #if os(tvOS)
            guard let rate = start.frameRate, let format = start.videoFormat else { return }
            let mode = DisplayMode(frameRate: rate, dynamicRange: start.dynamicRange)
            guard mode != displayMode else { return }
            displayMode = mode
            displayManager?.preferredDisplayCriteria = AVDisplayCriteria(refreshRate: Float(rate), formatDescription: format)
        #endif
    }

    func set(_ new: PlaybackState) {
        stateCast.sendIfChanged(new)
    }

    func publishFormat(_ start: DemuxStart) {
        presentationCast.sendIfChanged(start.presentation)
        tracksCast.sendIfChanged(start.trackList)
    }
}
