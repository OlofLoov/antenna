import Foundation
import Testing

@testable import AntennaCore

/// The TV mode a stream asks for, and frame rates found from timestamps.
@Suite struct DisplayModeTests {
    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format frame rates come from the frames' times")
    func estimatesFromTimes() {
        let pal = (0..<12).map { Double($0) * 0.04 + 1.48 }.shuffled()
        #expect(FrameRate.estimate(presentationTimes: pal) == 25)
        let ntsc = (0..<12).map { Double($0) * 1001 / 60000 }
        #expect(FrameRate.estimate(presentationTimes: ntsc) == 59.94)
        let film = (0..<12).map { Double($0) * 1001 / 24000 }
        #expect(FrameRate.estimate(presentationTimes: film) == 23.976)
        #expect(FrameRate.estimate(presentationTimes: [1.0]) == nil)
        #expect(FrameRate.estimate(presentationTimes: [1.0, 1.0 + 1.0 / 7]) == nil)
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format zapping between channels in the same mode")
    func sameModeMatches() throws {
        let news = PresentationInfo.Video(width: 1920, height: 1080, frameRate: 25.0001, dynamicRange: .sdr, codec: "h264")
        let sport = PresentationInfo.Video(width: 1280, height: 720, frameRate: 25, dynamicRange: .sdr, codec: "hevc")
        let fast = PresentationInfo.Video(width: 1280, height: 720, frameRate: 50, dynamicRange: .sdr, codec: "h264")
        let hdr = PresentationInfo.Video(width: 3840, height: 2160, frameRate: 25, dynamicRange: .hdr10, codec: "hevc")
        #expect(try #require(DisplayMode(news)) == DisplayMode(sport))
        #expect(DisplayMode(news) != DisplayMode(fast))
        #expect(DisplayMode(news) != DisplayMode(hdr))
        #expect(DisplayMode(PresentationInfo.Video(width: 1, height: 1, frameRate: nil, dynamicRange: .sdr, codec: "h264")) == nil)
    }
}
