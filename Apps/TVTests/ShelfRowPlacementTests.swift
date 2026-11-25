import Foundation
import Testing

@testable import AntennaTV

/// When and where the focused row of Movies and Series comes to rest under
/// the Apple TV tab bar.
@MainActor
struct ShelfRowPlacementTests {
    let row: CGFloat = 392

    @Test(
        "movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a row above its place moves at once"
    )
    func rowAboveMovesAtOnce() {
        // Owner-found on 2026-11-23: the focus engine leaves the row above under the tab bar,
        // and it stayed hidden for the 350 ms wait before it slid down.
        #expect(ShelfRowPlacement.wait(top: 117, height: row) == .zero)
        #expect(ShelfRowPlacement.wait(top: -240, height: row) == .zero)
        #expect(ShelfRowPlacement.wait(top: ShelfRowPlacement.rowTop - 1, height: row) == .zero)
    }

    // Owner-found on 2026-11-25: moving down waited 350 ms before the row came up,
    // although the next row was already wholly on screen and the focus engine left it there.
    @Test(
        "movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a row on screen moves at once, a cut one waits"
    )
    func rowBelowWaitsOnlyWhenCut() {
        #expect(ShelfRowPlacement.wait(top: 560, height: row) == .zero)
        #expect(ShelfRowPlacement.wait(top: ShelfRowPlacement.screenHeight - row, height: row) == .zero)
        #expect(ShelfRowPlacement.wait(top: 980, height: row) == ShelfRowPlacement.settle)
        #expect(ShelfRowPlacement.wait(top: 600, height: nil) == ShelfRowPlacement.settle)
        #expect(ShelfRowPlacement.wait(top: nil, height: row) == ShelfRowPlacement.settle)
    }

    @Test(
        "movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a row left away from its place is placed again"
    )
    func rowLeftAwayIsPlacedAgain() {
        // CI on 2026-11-24: the focus engine's scroll landed after the screen's and left
        // the row at the tab bar's foot for good.
        #expect(ShelfRowPlacement.misplaced(top: ShelfRowPlacement.barHeight))
        #expect(ShelfRowPlacement.misplaced(top: 600))
        #expect(!ShelfRowPlacement.misplaced(top: ShelfRowPlacement.rowTop))
        #expect(!ShelfRowPlacement.misplaced(top: ShelfRowPlacement.rowTop + ShelfRowPlacement.slack))
        #expect(!ShelfRowPlacement.misplaced(top: nil))
    }
}
