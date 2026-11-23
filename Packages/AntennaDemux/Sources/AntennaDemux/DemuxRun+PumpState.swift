import AntennaCore
import CoreMedia
import Foundation

extension DemuxRun {
    /// What `pump` has seen so far.
    struct PumpState {
        var startTime: CMTime?
        var heldSound: [CMSampleBuffer] = []
        var announced = false
        var frameTimes: [Double] = []
        var rateKnown: Bool
        /// Set for a stream whose pictures may be interlaced.
        var fields: FieldPictures?
        /// True once any packet of the picture stream arrived.
        var sawVideoPacket = false
        var fieldsDecided = false
        /// Video before the first keyframe is dropped; after it, everything
        /// goes to the builder, even while a decoder holds pictures back.
        var sawKeyframe = false
        /// The time of the keyframe the picture started at, until the next
        /// keyframe. Pictures before it in time lead it and may refer to
        /// pictures that were never read.
        var startKeyframe: CMTime?
        /// The container stream of the sound that plays.
        var sound: Int?
        /// The newest packets of each sound stream with a builder.
        var rings: [Int: SoundRing] = [:]
        /// The channel count of the sound last reported.
        var soundChannels: Int?
        /// The picture size and dynamic range last reported.
        var picture: (size: CMVideoDimensions, range: PresentationInfo.DynamicRange)?
        /// Keeps a live stream's times running on across jumps; nil for films.
        var timeline: LiveTimeline?
        /// The container streams the run knows of.
        var streamCount = 0
        /// The codec of each text or DVB subtitle stream, by container stream index.
        var subtitleCodecs: [Int: String] = [:]
        /// Where the newest timed packet of each sound stream with a builder ends.
        var soundEnds: [Int: CMTime] = [:]
        /// Where the newest sound buffer queued ends.
        var soundQueuedTo: CMTime?
    }
}
