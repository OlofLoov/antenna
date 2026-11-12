import AntennaCore
import Foundation
import Testing

private typealias Frame = MultiViewLayout.Frame

/// The worked frames on the boards: TV-MultiView, TV-MultiView-Two,
/// TV-MultiView-Failed and the Mac boards in the iPad frame.
@Suite struct MultiViewLayoutTests {
    @Test("multi-view/add-more-tiles-up-to-the-limit two tiles side by side on the 1920 by 1080 TV")
    func twoOnTelevision() {
        #expect(
            MultiViewLayout.television.frames(count: 2, width: 1920, height: 1080) == [
                Frame(x: 24, y: 279, width: 928, height: 522), Frame(x: 968, y: 279, width: 928, height: 522),
            ])
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit three tiles put the third centered on the second row")
    func threeOnTelevision() {
        #expect(
            MultiViewLayout.television.frames(count: 3, width: 1920, height: 1080) == [
                Frame(x: 49, y: 25, width: 903, height: 507), Frame(x: 968, y: 25, width: 903, height: 507),
                Frame(x: 508, y: 548, width: 903, height: 507),
            ])
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit four tiles in two rows on the TV")
    func fourOnTelevision() {
        #expect(
            MultiViewLayout.television.frames(count: 4, width: 1920, height: 1080) == [
                Frame(x: 49, y: 25, width: 903, height: 507), Frame(x: 968, y: 25, width: 903, height: 507),
                Frame(x: 49, y: 548, width: 903, height: 507), Frame(x: 968, y: 548, width: 903, height: 507),
            ])
    }

    @Test("multi-view/add-more-tiles-up-to-the-limit four and three tiles in the Mac board's 842 by 782 tile area")
    func mac() {
        let four = MultiViewLayout.mac.frames(count: 4, width: 842, height: 782)
        #expect(
            four == [
                Frame(x: 16, y: 161, width: 399, height: 224), Frame(x: 427, y: 161, width: 399, height: 224),
                Frame(x: 16, y: 397, width: 399, height: 224), Frame(x: 427, y: 397, width: 399, height: 224),
            ])
        let three = MultiViewLayout.mac.frames(count: 3, width: 842, height: 782)
        #expect(three.last == Frame(x: 221, y: 397, width: 399, height: 224))
    }

    @Test("multi-view/one-tile-full-screen-and-back one tile fills the container, and none gives no frames")
    func edges() {
        #expect(MultiViewLayout.television.frames(count: 1, width: 1920, height: 1080) == [Frame(x: 0, y: 0, width: 1920, height: 1080)])
        #expect(MultiViewLayout.mac.frames(count: 0, width: 800, height: 600).isEmpty)
    }

    @Test("multi-view/start-multi-view-on-a-mac tiles fit a wide, short window by height")
    func wideWindow() {
        let frames = MultiViewLayout.mac.frames(count: 4, width: 1600, height: 500)
        let bottom = frames.map { $0.y + $0.height }.max() ?? 0
        #expect(bottom <= 500 - 16)
        #expect(frames.allSatisfy { $0.width / $0.height > 1.76 && $0.width / $0.height < 1.79 })
    }
}
