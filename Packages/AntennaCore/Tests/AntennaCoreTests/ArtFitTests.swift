import Foundation
import Testing

@testable import AntennaCore

@Suite struct ArtFitTests {
    private func fit(_ picture: (Double, Double), in frame: (Double, Double)) -> ArtFit {
        ArtFit.choose(pictureWidth: picture.0, pictureHeight: picture.1, frameWidth: frame.0, frameHeight: frame.1)
    }

    @Test("movies-and-series-browsing/new-titles-up-front a poster sent as the backdrop shows whole in the wide banner")
    func posterInTheBanner() {
        #expect(fit((600, 900), in: (1920, 640)) == .whole)
        #expect(fit((800, 800), in: (1920, 640)) == .whole)
        #expect(fit((600, 900), in: (914, 330)) == .whole)
    }

    @Test("movies-and-series-browsing/new-titles-up-front a 16:9 backdrop fills the banner")
    func backdropInTheBanner() {
        #expect(fit((1280, 720), in: (1920, 640)) == .fill)
        #expect(fit((3840, 2160), in: (914, 330)) == .fill)
    }

    @Test("movies-and-series-browsing/new-titles-up-front a frame taller than wide always fills, so the iPhone banner fills with a poster")
    func tallFramesFill() {
        #expect(fit((600, 900), in: (390, 520)) == .fill)
        #expect(fit((1280, 720), in: (390, 520)) == .fill)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about the movie page fills with a backdrop and shows a poster whole")
    func moviePage() {
        #expect(fit((1280, 720), in: (1920, 1080)) == .fill)
        #expect(fit((1024, 768), in: (1920, 1080)) == .fill)
        #expect(fit((600, 900), in: (1920, 1080)) == .whole)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about the series band shows a 16:9 backdrop whole rather than its middle half")
    func seriesBand() {
        #expect(fit((1280, 720), in: (1920, 520)) == .whole)
        #expect(fit((2560, 1080), in: (1920, 520)) == .fill)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a picture or frame with no area fills")
    func empty() {
        #expect(fit((0, 0), in: (1920, 640)) == .fill)
        #expect(fit((600, 900), in: (0, 0)) == .fill)
    }

    @Test("movies-and-series-browsing/new-titles-up-front on Apple TV focus on the banner does not stop it; elsewhere it holds")
    func bannerHold() {
        #expect(BannerPager.rotates(count: 4, interacting: true, reduceMotion: false, hold: .restartsOnInput))
        #expect(BannerPager.rotates(count: 4, interacting: false, reduceMotion: false, hold: .restartsOnInput))
        #expect(!BannerPager.rotates(count: 4, interacting: true, reduceMotion: true, hold: .restartsOnInput))
        #expect(!BannerPager.rotates(count: 1, interacting: false, reduceMotion: false, hold: .restartsOnInput))
        #expect(!BannerPager.rotates(count: 4, interacting: true, reduceMotion: false, hold: .whileInteracting))
    }
}
