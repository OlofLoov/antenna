import Foundation
import Testing

@testable import AntennaCore

/// Posters decode at the size of the frame that shows them, never larger
/// than they are, and always large enough to cover the frame.
@Suite struct PosterFitTests {
    @Test("movies-and-series-browsing/browsing-stays-responsive a frame is its pixels with room for the focus lift, rounded up")
    func frame() throws {
        let card = try #require(PosterFit(width: 212, height: 318, scale: 1))
        #expect(card.width == 320 && card.height == 448, "265 and 397.5 rounded up to 64")
        let phone = try #require(PosterFit(width: 110, height: 165, scale: 3))
        #expect(phone.width == 448 && phone.height == 640)
        #expect(PosterFit(width: 0, height: 100, scale: 2) == nil, "no size yet, nothing loads")
        #expect(PosterFit(width: 100, height: 100, scale: 0) == nil)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a large poster decodes to cover the frame on both sides")
    func covers() throws {
        let card = try #require(PosterFit(width: 212, height: 318, scale: 1))
        let side = try #require(card.longestSide(pictureWidth: 2000, pictureHeight: 3000))
        #expect(side == 480, "the width needs the most: 2000 times 0.16 is 320, so 3000 becomes 480")
        let scale = Double(side) / 3000
        #expect(Double(2000) * scale >= Double(card.width) - 0.5)
        #expect(Double(3000) * scale >= Double(card.height) - 0.5)

        let wide = try #require(card.longestSide(pictureWidth: 3840, pictureHeight: 2160))
        #expect(Double(2160) * Double(wide) / 3840 >= Double(card.height) - 0.5, "a wide picture in a tall frame covers its height")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a picture no larger than the frame decodes as it is")
    func neverLarger() throws {
        let card = try #require(PosterFit(width: 212, height: 318, scale: 2))
        #expect(card.longestSide(pictureWidth: 300, pictureHeight: 450) == nil)
        #expect(card.longestSide(pictureWidth: card.width, pictureHeight: card.height) == nil)
        #expect(card.longestSide(pictureWidth: 0, pictureHeight: 10) == nil)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive frames a few points apart share a decoded picture")
    func sharedKeys() throws {
        let one = try #require(PosterFit(width: 212, height: 318, scale: 1))
        let two = try #require(PosterFit(width: 210, height: 316, scale: 1))
        #expect(one == two)
        #expect(one.key == "320x448")
    }
}
