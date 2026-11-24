import Foundation

/// SVG path data as drawing commands, for the Antuna mark's shapes
/// (design-system/the-antuna-mark). Reads the absolute commands the
/// artwork uses, `M L H V C Q A Z`, and turns every arc into cubic curves,
/// so a caller only has to draw moves, lines, curves and closes.
public enum MarkPath {
    /// A point in the artwork's units, y pointing down.
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// One drawing command with absolute points.
    public enum Element: Equatable, Sendable {
        case move(Point)
        case line(Point)
        case quad(to: Point, control: Point)
        case cubic(to: Point, control1: Point, control2: Point)
        case close
    }

    /// An axis-aligned box.
    public struct Bounds: Equatable, Sendable {
        public var minX: Double
        public var minY: Double
        public var maxX: Double
        public var maxY: Double
    }

    /// Why path data could not be read.
    public enum ParseError: Error, Equatable {
        /// A command letter this reader does not know, such as a relative `m`.
        case unknownCommand(Character)
        /// A command ran out of numbers.
        case missingNumber(Character)
    }

    /// The commands in `data`, in order. Arcs come back as one to four
    /// cubics each, one per quarter turn or less.
    public static func elements(_ data: String) throws(ParseError) -> [Element] {
        var reader = Reader(data)
        var elements: [Element] = []
        var current = Point(0, 0)
        var start = Point(0, 0)
        while let command = reader.command() {
            func number() throws(ParseError) -> Double {
                guard let value = reader.number() else { throw .missingNumber(command) }
                return value
            }
            func point() throws(ParseError) -> Point { Point(try number(), try number()) }
            repeat {
                switch command {
                case "M":
                    current = try point()
                    start = current
                    elements.append(.move(current))
                case "L":
                    current = try point()
                    elements.append(.line(current))
                case "H":
                    current = Point(try number(), current.y)
                    elements.append(.line(current))
                case "V":
                    current = Point(current.x, try number())
                    elements.append(.line(current))
                case "C":
                    let (first, second, end) = (try point(), try point(), try point())
                    elements.append(.cubic(to: end, control1: first, control2: second))
                    current = end
                case "Q":
                    let (control, end) = (try point(), try point())
                    elements.append(.quad(to: end, control: control))
                    current = end
                case "A":
                    let (rx, ry, rotation) = (try number(), try number(), try number())
                    let (large, sweep, end) = (try number() != 0, try number() != 0, try point())
                    elements += arc(from: current, to: end, radii: (rx, ry), rotation: rotation, large: large, sweep: sweep)
                    current = end
                case "Z":
                    elements.append(.close)
                    current = start
                default:
                    throw .unknownCommand(command)
                }
            } while command != "Z" && reader.hasNumber()
        }
        return elements
    }

    /// The smallest box holding every point and control point. It can be
    /// a little larger than the drawn curve, never smaller.
    public static func bounds(_ elements: [Element]) -> Bounds {
        let points = elements.flatMap { element -> [Point] in
            switch element {
            case .move(let point), .line(let point): [point]
            case .quad(let to, let control): [to, control]
            case .cubic(let to, let first, let second): [to, first, second]
            case .close: []
            }
        }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return Bounds(minX: xs.min() ?? 0, minY: ys.min() ?? 0, maxX: xs.max() ?? 0, maxY: ys.max() ?? 0)
    }

    /// An SVG elliptical arc as cubics, by the endpoint-to-center
    /// conversion in SVG 1.1 appendix F.6.
    static func arc(
        from start: Point, to end: Point, radii: (Double, Double), rotation: Double, large: Bool, sweep: Bool
    ) -> [Element] {
        var (rx, ry) = (abs(radii.0), abs(radii.1))
        guard rx > 0, ry > 0, start != end else { return [.line(end)] }
        let phi = rotation * .pi / 180
        let (cosPhi, sinPhi) = (cos(phi), sin(phi))
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var factor = (max(0, numerator) / denominator).squareRoot()
        if large == sweep { factor = -factor }
        let cx1 = factor * rx * y1 / ry
        let cy1 = -factor * ry * x1 / rx
        let center = Point(
            cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2,
            sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2)
        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(segments)
        let handle = 4.0 / 3.0 * tan(step / 4)
        func on(_ angle: Double) -> Point {
            let (x, y) = (rx * cos(angle), ry * sin(angle))
            return Point(center.x + cosPhi * x - sinPhi * y, center.y + sinPhi * x + cosPhi * y)
        }
        func tangent(_ angle: Double) -> Point {
            let (x, y) = (-rx * sin(angle), ry * cos(angle))
            return Point(cosPhi * x - sinPhi * y, sinPhi * x + cosPhi * y)
        }
        var result: [Element] = []
        for index in 0..<segments {
            let from = theta + Double(index) * step
            let to = from + step
            let (p0, p3) = (on(from), index == segments - 1 ? end : on(to))
            let (t0, t3) = (tangent(from), tangent(to))
            result.append(
                .cubic(
                    to: p3,
                    control1: Point(p0.x + handle * t0.x, p0.y + handle * t0.y),
                    control2: Point(p3.x - handle * t3.x, p3.y - handle * t3.y)))
        }
        return result
    }

    /// Splits path data into command letters and numbers.
    private struct Reader {
        private let characters: [Character]
        private var index = 0

        init(_ data: String) { characters = Array(data) }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," || characters[index].isNewline {
                index += 1
            }
        }

        mutating func command() -> Character? {
            skipSeparators()
            guard index < characters.count else { return nil }
            defer { index += 1 }
            return characters[index]
        }

        mutating func hasNumber() -> Bool {
            skipSeparators()
            guard index < characters.count else { return false }
            let next = characters[index]
            return next.isNumber || next == "-" || next == "+" || next == "."
        }

        mutating func number() -> Double? {
            guard hasNumber() else { return nil }
            var text = String(characters[index])
            index += 1
            var seenDot = text == "."
            while index < characters.count {
                let next = characters[index]
                if next.isNumber {
                    text.append(next)
                } else if next == ".", !seenDot {
                    seenDot = true
                    text.append(next)
                } else if next == "e" || next == "E" {
                    text.append(next)
                    if index + 1 < characters.count, characters[index + 1] == "-" || characters[index + 1] == "+" {
                        index += 1
                        text.append(characters[index])
                    }
                } else {
                    break
                }
                index += 1
            }
            return Double(text)
        }
    }
}
