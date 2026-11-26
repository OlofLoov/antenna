import Foundation
import Testing

@testable import AntennaCore

@Suite struct TitleArtPlacementTests {
    private typealias Box = TitleArtPlacement.Box

    private func place(
        _ picture: (Double, Double), in area: Box, _ alignment: TitleArtPlacement.Alignment = .center, margin: Double = 12
    ) -> TitleArtPlacement {
        TitleArtPlacement.place(pictureWidth: picture.0, pictureHeight: picture.1, in: area, alignment: alignment, margin: margin)
    }

    private func close(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 0.001
    }

    private func close(_ first: Box, _ second: Box) -> Bool {
        close(first.x, second.x) && close(first.y, second.y) && close(first.width, second.width) && close(first.height, second.height)
    }

    /// An iPhone 17 Pro: 402 wide, 62 under the status bar.
    private let phone = TitleArtPlacement.phoneArea(width: 402, top: 62)

    @Test("title-detail-and-episode-picker/what-the-title-is-about on iPhone a 16:9 backdrop shows whole under the status bar")
    func phoneBackdrop() {
        #expect(phone == Box(x: 0, y: 62, width: 402, height: 226.125))
        let placed = place((1280, 720), in: phone)
        #expect(placed.look == .fills)
        #expect(close(placed.picture, phone))
        #expect(close(placed.shown(in: phone), 1))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about on iPhone a poster sent as the backdrop shows whole in the middle")
    func phonePoster() {
        let placed = place((400, 600), in: phone)
        #expect(placed.look == .framed)
        #expect(close(placed.picture.height, 202.125))
        #expect(close(placed.picture.x + placed.picture.width / 2, 201))
        #expect(close(placed.shown(in: phone), 1))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a picture close to the area's shape fills it and loses at most 8%")
    func nearlyTheShape() {
        let placed = place((1998, 1080), in: phone)
        #expect(placed.look == .fills)
        #expect(placed.shown(in: phone) > 0.92)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a wider or squarer picture shows whole over its blur")
    func otherShapes() {
        let scope = place((2390, 1000), in: phone)
        #expect(scope.look == .whole)
        #expect(close(scope.picture.width, 402))
        #expect(close(scope.shown(in: phone), 1))
        let square = place((1024, 768), in: phone)
        #expect(square.look == .whole)
        #expect(close(square.picture.height, phone.height))
        #expect(close(square.shown(in: phone), 1))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about the iPad card is 16:9 for its width, between 380 and 560 tall")
    func padCard() {
        #expect(close(TitleArtPlacement.cardHeight(width: 866), 487.125))
        #expect(TitleArtPlacement.cardHeight(width: 600) == 380)
        #expect(TitleArtPlacement.cardHeight(width: 1400) == 560)
        let card = Box(x: 0, y: 0, width: 866, height: TitleArtPlacement.cardHeight(width: 866))
        #expect(close(place((1920, 1080), in: card, .trailing).shown(in: card), 1))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about in a card or band wider than 16:9 the backdrop shows whole at the right")
    func wideBands() {
        let card = Box(x: 0, y: 0, width: 1400, height: 560)
        let backdrop = place((1920, 1080), in: card, .trailing)
        #expect(backdrop.look == .whole)
        #expect(close(backdrop.picture.maxX, 1400))
        #expect(close(backdrop.shown(in: card), 1))
        let band = Box(x: 0, y: 0, width: 1920, height: 520)
        #expect(place((1280, 720), in: band, .trailing).picture.width < 1000)
        let screen = Box(x: 0, y: 0, width: 1920, height: 1080)
        #expect(place((1280, 720), in: screen, .trailing).look == .fills)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a poster on a wide card shows whole at the right, inset by the margin")
    func posterOnACard() {
        let card = Box(x: 0, y: 0, width: 866, height: 487)
        let placed = place((600, 900), in: card, .trailing, margin: 28)
        #expect(placed.look == .framed)
        #expect(close(placed.picture.maxX, 838))
        #expect(close(placed.picture.y, 28))
        #expect(close(placed.shown(in: card), 1))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a picture or area with no size fills")
    func empty() {
        #expect(place((0, 0), in: phone).look == .fills)
        #expect(place((600, 900), in: Box(x: 0, y: 0, width: 0, height: 0)).look == .fills)
    }
}
