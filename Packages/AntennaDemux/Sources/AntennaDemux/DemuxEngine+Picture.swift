@preconcurrency import AVFoundation
import Foundation

extension DemuxEngine {
    /// Recovers a video renderer that stopped decoding: one whose decoder
    /// failed on bad data, or that needs a flush after the app comes back
    /// from the background. The renderer is flushed, keeping the last
    /// picture, and the run queues pictures again from the next keyframe,
    /// so no picture that refers to a dropped one is decoded
    /// (playback-engine/undecodable-pictures-are-not-shown).
    func checkPicture() {
        let renderer = videoLayer.sampleBufferRenderer
        guard renderer.status == .failed || renderer.requiresFlushToResumeDecoding, let current, current.start != nil else { return }
        let code = renderer.error.map { String(($0 as NSError).code) } ?? "none"
        log("demux video renderer stopped decoding (\(code)), pictures resume at the next keyframe")
        current.run.restartPictures()
        current.videoFeed.flush()
    }
}
