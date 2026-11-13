import AVKit
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

/// The Picture in Picture window on the FFmpeg path, which these tests
/// run on a Mac.
@MainActor
@Suite struct PictureInPictureWindowTests {
    @Test("player-controls-and-playback-errors/picture-in-picture-on-a-mac the FFmpeg path offers the window where the system has it")
    func offersTheWindow() async {
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let supported = AVPictureInPictureController.isPictureInPictureSupported()
        #expect(await engine.capabilities.supportsPictureInPicture == supported)
        engine.enablePictureInPicture()
        let window = engine.pictureInPicture
        #expect((window != nil) == supported)
        engine.enablePictureInPicture()
        #expect(engine.pictureInPicture === window, "a second call keeps the same window")
    }
}
