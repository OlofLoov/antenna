import AntennaCore
import Testing

@testable import Antenna

/// Where a row's posters sit while one of them is the Apple TV card: each
/// keeps its slot, the posters after the card are moved aside, and a move
/// changes only the places it has to
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
        #expect(places.map(\.front) == [false, false, true, false, false, false])
        #expect(tail.aside)
    }

    @Test func aStepAlongTheRowChangesTwoPlaces() {
        let row = makeRow()
        let (room, places) = (row.room, row.places)
        room.expand(titles[2].id, true)
        let before = places.map { ($0.aside, $0.front) }
        // The poster gaining the highlight tells the room first, then the one losing it.
        room.expand(titles[3].id, true)
        room.expand(titles[2].id, false)
        let changed = zip(before, places).filter { $0.0 != ($0.1.aside, $0.1.front) }
        #expect(changed.count == 2)
        #expect(places[3].front && !places[3].aside)
        #expect(!places[2].front && !places[2].aside)
    }

    @Test func leavingTheRowPutsEveryPosterBack() {
        let row = makeRow()
        let (room, places, tail) = (row.room, row.places, row.tail)
        room.expand(titles[1].id, true)
        room.expand(titles[1].id, false)
        #expect(places.allSatisfy { !$0.aside && !$0.front })
        #expect(!tail.aside)
    }

    @Test func aPosterThatComesIntoViewTakesItsPlace() {
        let room = makeRow().room
        room.expand(titles[0].id, true)
        let late = ShelfCardPlace()
        room.arrive(late, id: titles[4].id)
        #expect(late.aside)
    }

    @Test func aNewOrderPlacesThePostersAgain() {
        let row = makeRow()
        let (room, places) = (row.room, row.places)
        room.expand(titles[2].id, true)
        room.order = Array(titles.reversed())
        #expect(places.map(\.aside) == [true, true, false, false, false, false])
        #expect(places[2].front)
    }
}
