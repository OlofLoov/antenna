import Foundation
import Testing

@testable import AntennaTV

/// When and where the focused row of Movies and Series comes to rest under
/// the Apple TV preview.
@MainActor
struct ShelfRowPlacementTests {
    @Test(
        "movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv a row under the preview, as after moving up, is placed at once"
    )
    func rowUnderThePreviewMovesAtOnce() {
        // Owner-found on 2026-11-23: the focus engine leaves the row above under the preview,
        // and it stayed hidden for the 350 ms wait before it slid down.
        #expect(ShelfRowPlacement.wait(top: 117) == .zero)
        #expect(ShelfRowPlacement.wait(top: -240) == .zero)
        #expect(ShelfRowPlacement.wait(top: ShelfPreview.height - 1) == .zero)
    }

    @Test(
        "movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv a row below the preview waits for the focus engine's scroll"
    )
    func rowBelowThePreviewWaits() {
        #expect(ShelfRowPlacement.wait(top: 980) == ShelfRowPlacement.settle)
        #expect(ShelfRowPlacement.wait(top: ShelfPreview.height) == ShelfRowPlacement.settle)
        #expect(ShelfRowPlacement.wait(top: nil) == ShelfRowPlacement.settle)
    }

    @Test(
        "movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv a placed row left under the preview is placed again"
    )
    func rowLeftUnderThePreviewIsPlacedAgain() {
        // CI on 2026-11-24: the focus engine's scroll landed after the screen's and left
        // the row at 117 pt, under the preview, for good.
        #expect(ShelfRowPlacement.misplaced(top: 117))
        #expect(ShelfRowPlacement.misplaced(top: ShelfPreview.height - 1))
        #expect(!ShelfRowPlacement.misplaced(top: ShelfRowPlacement.rowTop))
        #expect(!ShelfRowPlacement.misplaced(top: ShelfPreview.height))
        #expect(!ShelfRowPlacement.misplaced(top: nil))
    }
}
