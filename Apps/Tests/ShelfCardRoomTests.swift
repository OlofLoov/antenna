import AntennaCore
import CoreGraphics
import Testing

@testable import Antenna

/// Where a row's posters sit while one of them is the Apple TV card: each
/// keeps its slot, the posters after the card are moved aside, the row
/// draws the card over the focused slot, and a move changes only the
/// places it has to
/// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv,
/// movies-and-series-browsing/browsing-stays-responsive).
@MainActor @Suite struct ShelfCardRoomTests {
    private let titles = (0..<6).map { ShelfFixtures.movie($0) }

    /// A room for the six titles with every poster and the tail tile on screen.
    private struct Row {
        let room = ShelfCardRoom()
        var places: [ShelfCardPlace] = []
        let tail = ShelfCardPlace()
    }

    private func makeRow() -> Row {
        var row = Row()
        row.room.order = titles
        row.places = titles.map { title in
            let place = ShelfCardPlace()
            row.room.arrive(place, id: title.id)
            return place
        }
        row.room.arrive(row.tail, id: nil)
        return row
    }

    @Test func theCardMovesThePostersAfterItAside() {
        let row = makeRow()
        let (room, places, tail) = (row.room, row.places, row.tail)
        room.expand(titles[2].id, true)
        #expect(places.map(\.aside) == [false, false, false, true, true, true])
        #expect(room.spot.card == ShelfCardSpot.Card(title: titles[2], index: 2))
        #expect(tail.aside)
    }

    @Test func aStepAlongTheRowMovesOnePosterAndTheCard() {
        let row = makeRow()
        let (room, places) = (row.room, row.places)
        room.expand(titles[2].id, true)
        let before = places.map(\.aside)
        // The poster gaining the highlight tells the room first, then the one losing it.
        room.expand(titles[3].id, true)
        room.expand(titles[2].id, false)
        let changed = zip(before, places).filter { $0.0 != $0.1.aside }
        #expect(changed.count == 1)
        #expect(!places[3].aside && !places[2].aside)
        #expect(room.spot.card == ShelfCardSpot.Card(title: titles[3], index: 3))
    }

    @Test func leavingTheRowPutsEveryPosterBack() {
        let row = makeRow()
        let (room, places, tail) = (row.room, row.places, row.tail)
        room.expand(titles[1].id, true)
        room.expand(titles[1].id, false)
        #expect(places.allSatisfy { !$0.aside })
        #expect(room.spot.card == nil)
        #expect(!tail.aside)
    }

    @Test func aPosterThatComesIntoViewTakesItsPlace() {
        let room = makeRow().room
        room.expand(titles[0].id, true)
        let late = ShelfCardPlace()
        room.arrive(late, id: titles[4].id)
        #expect(late.aside)
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, the card keeps the row's spacing
    // The card's lift grew it 17 pt past its slot on each side, leaving 3 pt to each neighbour on the device.
    @Test(arguments: [0, 1, 4])
    func theCardKeepsTheRowsGapOnBothSides(index: Int) {
        let geometry = ShelfExpandedCard.Geometry(metrics: .tv)
        let card = geometry.card(at: index)
        let after = geometry.poster(index + 1, card: index)
        #expect(abs(after.minX - card.maxX - ShelfView.Metrics.tv.gap) < 0.01)
        if index > 0 {
            let before = geometry.poster(index - 1, card: index)
            #expect(abs(card.minX - before.maxX - ShelfView.Metrics.tv.gap) < 0.01)
        }
        // The posters further on keep the gap between them.
        #expect(abs(geometry.poster(index + 2, card: index).minX - after.maxX - ShelfView.Metrics.tv.gap) < 0.01)
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, the highlight is the card
    // The system card style lifted the poster's slot under the card, so its edge and shadow showed at the poster's size.
    @Test func theHighlightIsTheCardAsDrawn() {
        let geometry = ShelfExpandedCard.Geometry(metrics: .tv)
        let card = geometry.card(at: 2)
        #expect(card.size == CGSize(width: 566 * ShelfExpandedCard.lift, height: 318 * ShelfExpandedCard.lift))
        #expect(card.minX == geometry.slot(2))
        #expect(card.midY == ShelfView.Metrics.tv.poster.height / 2)
        // The poster's slot is inside the card on every side, so nothing of it shows around the card.
        #expect(card.contains(geometry.poster(2, card: 2)))
    }

    @Test func aNewOrderPlacesThePostersAgain() {
        let row = makeRow()
        let (room, places) = (row.room, row.places)
        room.expand(titles[2].id, true)
        room.order = Array(titles.reversed())
        #expect(places.map(\.aside) == [true, true, false, false, false, false])
        #expect(room.spot.card == ShelfCardSpot.Card(title: titles[2], index: 3))
    }
}
