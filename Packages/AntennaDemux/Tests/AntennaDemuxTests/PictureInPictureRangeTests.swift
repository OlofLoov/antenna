import CoreMedia
import Testing

@testable import AntennaDemux

/// The span the Picture in Picture window shows.
@Suite struct PictureInPictureRangeTests {
    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture live TV gets no span to skip in")
    func liveIsUnbounded() {
        let range = DemuxEngine.pictureInPictureRange(start: CMTime(value: 148, timescale: 100), duration: nil, isLive: true)
        #expect(range.start == .negativeInfinity && range.duration == .positiveInfinity)
    }

    @Test("playback-engine/leaving-the-app-phone-calls-and-picture-in-picture a film shows its length from its first picture")
    func filmSpansItsLength() {
        let start = CMTime(value: 148, timescale: 100)
        let length = CMTime(value: 5400, timescale: 1)
        let range = DemuxEngine.pictureInPictureRange(start: start, duration: length, isLive: false)
        #expect(range == CMTimeRange(start: start, duration: length))
    }
}
