import AntennaCore
import Foundation
import Testing

@Suite struct MarkGeometryTests {
    private func shape(_ data: String) throws -> [MarkPath.Element] { try MarkPath.elements(data) }

    @Test("design-system/the-antuna-mark: every shape of the artwork reads as drawing commands")
    func everyShapeParses() throws {
        #expect(MarkGeometry.letters.count == 5)
        for data in MarkGeometry.letters + [MarkGeometry.head, MarkGeometry.mouth, MarkGeometry.tail, MarkGeometry.playHole] {
            let elements = try shape(data)
            #expect(elements.first.map { if case .move = $0 { true } else { false } } == true, "\(data.prefix(20))")
            #expect(elements.count > 1)
        }
        #expect(throws: MarkPath.ParseError.unknownCommand("m")) { try MarkPath.elements("m1 2l3 4") }
        #expect(throws: MarkPath.ParseError.missingNumber("L")) { try MarkPath.elements("M1 2L3") }
    }

    @Test("design-system/the-antuna-mark: the head is the artwork's, its arc a true half circle")
    func headMatchesTheArtwork() throws {
        let head = try shape(MarkGeometry.head)
        let bounds = MarkPath.bounds(head)
        #expect(abs(bounds.minY - -118) < 0.01 && abs(bounds.maxY - 0) < 0.5)
        #expect(bounds.minX >= 603 && bounds.minX <= 606)
        #expect(abs(bounds.maxX - 732) < 2, "the arc reaches x 732, its control points a little past it")
        // The arc from (673,-118) to (673,0), radius 59, clockwise: every curve point sits on the circle.
        guard case .cubic(let end, let first, let second) = head[1] else {
            Issue.record("the arc should come first after the move")
            return
        }
        func point(_ at: Double, _ p0: MarkPath.Point) -> MarkPath.Point {
            let rest = 1 - at
            let x = rest * rest * rest * p0.x + 3 * rest * rest * at * first.x + 3 * rest * at * at * second.x + at * at * at * end.x
            let y = rest * rest * rest * p0.y + 3 * rest * rest * at * first.y + 3 * rest * at * at * second.y + at * at * at * end.y
            return .init(x, y)
        }
        let middle = point(0.5, .init(673, -118))
        let radius = ((middle.x - 673) * (middle.x - 673) + (middle.y - -59) * (middle.y - -59)).squareRoot()
        #expect(abs(radius - 59) < 0.05)
        #expect(middle.x > 673, "clockwise from the top, through the right side")
    }

    @Test("design-system/the-antuna-mark: the pivots sit where the prototype put its transform origins")
    func pivots() throws {
        let hole = MarkPath.bounds(try shape(MarkGeometry.playHole))
        #expect(MarkGeometry.Pivot.playHole == .init((hole.minX + hole.maxX) / 2, (hole.minY + hole.maxY) / 2))
        let mouth = MarkPath.bounds(try shape(MarkGeometry.mouth))
        #expect(MarkGeometry.Pivot.mouth.x == mouth.maxX)
        #expect(abs(MarkGeometry.Pivot.mouth.y - (mouth.minY + 0.64 * (mouth.maxY - mouth.minY))) < 0.1)
        let tail = MarkPath.bounds(try shape(MarkGeometry.tail))
        #expect(MarkGeometry.Pivot.tail.x == tail.minX)
        let eye = MarkGeometry.eyeCenter
        let travelled = MarkPath.Point(
            MarkGeometry.Pivot.playHole.x + MarkGeometry.eyeTravel.x, MarkGeometry.Pivot.playHole.y + MarkGeometry.eyeTravel.y)
        #expect(abs(travelled.x - eye.x) < 7 && abs(travelled.y - eye.y) < 1, "the triangle slides to where the eye opens")
    }

    @Test("design-system/the-antuna-mark: the word and the a fit their boxes, antennae included")
    func boxes() throws {
        let word = MarkGeometry.wordBox
        for data in MarkGeometry.letters {
            let bounds = MarkPath.bounds(try shape(data))
            let half = MarkGeometry.letterStroke / 2
            #expect(bounds.minX - half >= word.x && bounds.maxX + half <= word.x + word.width)
            #expect(bounds.minY - half >= word.y && bounds.maxY + half <= word.y + word.height)
        }
        for box in [word, MarkGeometry.letterBox] {
            for antenna in MarkGeometry.antennae {
                let top = antenna.tip.y - antenna.tipRadius * 2.6 - 9
                #expect(top >= box.y, "a ring at its largest and a hopping tip stay inside")
                #expect(antenna.tip.x - antenna.tipRadius * 2.6 >= box.x && antenna.tip.x + antenna.tipRadius * 2.6 <= box.x + box.width)
            }
        }
        let letter = MarkGeometry.letterBox
        #expect(letter.x + letter.width / 2 == 675, "centered on the head as in the icon")
    }

    @Test("design-system/the-antuna-mark: the still mark has no eye and the play triangle in the middle")
    func stillMarkHasNoEye() {
        let still = MarkMotion.pose(.still, at: 12, reduceMotion: false)
        #expect(still == .still)
        #expect(still.eye.scaleX == 0 && still.eye.scaleY == 0)
        #expect(still.playHole == .identity)
    }

    @Test("design-system/the-mark-s-colors: the artwork's colors, teal shared with the profile accent")
    func colors() {
        #expect(MarkColor.ink == 0xF2F4F8 && MarkColor.tip == 0x4FD1C5)
        #expect(MarkColor.inkOnLight == 0x0B0E13 && MarkColor.tipOnLight == 0x119C8F)
        #expect(MarkColor.tip == ProfileAccent.teal.rgb)
        #expect(MarkColor.ground == ProfileAccent.surfaces[0])
        #expect(Contrast.ratio(MarkColor.ink, MarkColor.ground) > 17)
        #expect(Contrast.ratio(MarkColor.inkOnLight, 0xF2F4F8) > 17)
        #expect(Contrast.ratio(MarkColor.tipOnLight, 0xFFFFFF) >= 3, "the light tips read as graphics on white")
    }
}
