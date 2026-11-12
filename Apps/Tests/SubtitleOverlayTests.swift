import AntennaCore
import CoreGraphics
import Foundation
import Testing

@testable import Antenna

/// Where the overlay puts subtitles on the picture.
@MainActor
@Suite struct SubtitleOverlayTests {
    @Test("playback-engine/picture-subtitles-in-broadcast-streams scaled with the picture")
    func picturesScaleWithThePicture() {
        let frame = SubtitleImage.Frame(x: 0.4, y: 0.8, width: 0.2, height: 0.1)
        // A 16:9 picture letterboxed in a 4:3 box: 400 by 225, 37.5 pt from the top.
        let small = SubtitleOverlay.pictureRect(in: CGSize(width: 400, height: 300), aspect: 16 / 9)
        #expect(small == CGRect(x: 0, y: 37.5, width: 400, height: 225))
        #expect(SubtitleOverlay.place(frame, in: small) == CGRect(x: 160, y: 217.5, width: 80, height: 22.5))
        // Full screen on a 1920 by 1080 TV: the same place, five times larger.
        let full = SubtitleOverlay.pictureRect(in: CGSize(width: 1920, height: 1080), aspect: 16 / 9)
        #expect(SubtitleOverlay.place(frame, in: full) == CGRect(x: 768, y: 864, width: 384, height: 108))
    }

    @Test("playback-engine/picture-subtitles-in-broadcast-streams a picture's bytes become an image, and broken ones are skipped")
    func images() {
        let picture = SubtitleOverlay.previewPicture
        let image = SubtitleOverlay.cgImage(picture)
        #expect(image?.width == picture.width)
        #expect(image?.height == picture.height)
        var short = picture
        short.rgba = Data(count: 8)
        #expect(SubtitleOverlay.cgImage(short) == nil)
    }
}
