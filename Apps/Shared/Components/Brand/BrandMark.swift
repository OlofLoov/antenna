import AntennaCore
import SwiftUI

/// The Antuna mark (design-system/the-antuna-mark, `Brand-Mark` board):
/// `Word` is "antuna" with its antennae, `Letter` the last a alone. Each
/// plays a `MarkMoment` from AntennaCore's tables and stands still after a
/// one-shot moment ends. The play triangle, the mouth and the eye are cut
/// out, so whatever is behind the mark shows through them.
enum BrandMark {
    /// The letters' and the tips' colors (design-system/the-mark-s-colors).
    /// The tips stay teal on every profile.
    struct Ink: Equatable {
        var letters: Color
        var tips: Color

        static let onDark = Ink(letters: Color(hex: MarkColor.ink), tips: Color(hex: MarkColor.tip))
        static let onLight = Ink(letters: Color(hex: MarkColor.inkOnLight), tips: Color(hex: MarkColor.tipOnLight))
    }

    /// Where a mark's time comes from.
    enum Clock: Equatable {
        /// The display's clock, from the moment the mark first shows this moment.
        case live
        /// A fixed number of seconds into the moment, for previews.
        case frozen(TimeInterval)
    }

    /// The word with its antennae, 760 by 198 in the artwork's units.
    struct Word: View {
        let moment: MarkMoment
        var ink = Ink.onDark
        var clock = Clock.live

        var body: some View {
            Player(moment: moment, ink: ink, clock: clock, box: MarkGeometry.wordBox, letters: Shapes.letters)
                .aspectRatio(MarkGeometry.wordBox.width / MarkGeometry.wordBox.height, contentMode: .fit)
                .modifier(Named(moment: moment))
        }
    }

    /// The last a with its antennae, square.
    struct Letter: View {
        let moment: MarkMoment
        var ink = Ink.onDark
        var clock = Clock.live

        var body: some View {
            Player(moment: moment, ink: ink, clock: clock, box: MarkGeometry.letterBox, letters: [])
                .aspectRatio(1, contentMode: .fit)
                .modifier(Named(moment: moment))
        }
    }

    /// One image named "Antuna". Debug builds expose the moment as the
    /// value, which UI tests read.
    private struct Named: ViewModifier {
        let moment: MarkMoment

        func body(content: Content) -> some View {
            let named =
                content
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: "Antuna"))
                .accessibilityAddTraits(.isImage)
            #if DEBUG
                named.accessibilityValue(moment.rawValue)
            #else
                named
            #endif
        }
    }

    /// Runs a moment's clock and hands each frame's pose to `Drawing`. A
    /// one-shot moment starts once per moment, so a screen coming back from
    /// a sheet or a pushed page does not play it again, and the timeline
    /// pauses once it ends.
    private struct Player: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let moment: MarkMoment
        let ink: Ink
        let clock: Clock
        let box: MarkGeometry.Box
        let letters: [Path]
        @State private var start: Date?
        @State private var started: MarkMoment?
        @State private var finished = false

        var body: some View {
            switch clock {
            case .frozen(let seconds):
                drawing(at: seconds)
            case .live:
                TimelineView(.animation(paused: moment == .still || finished)) { context in
                    drawing(at: start.map { context.date.timeIntervalSince($0) } ?? 0)
                }
                .task(id: moment) { await run() }
            }
        }

        private func drawing(at seconds: TimeInterval) -> Drawing {
            Drawing(pose: MarkMotion.pose(moment, at: seconds, reduceMotion: reduceMotion), ink: ink, box: box, letters: letters)
        }

        private func run() async {
            if started != moment {
                started = moment
                start = .now
            }
            finished = false
            guard let start, let duration = MarkMotion.duration(moment, reduceMotion: reduceMotion) else { return }
            let remaining = duration - Date.now.timeIntervalSince(start)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled else { return }
            }
            finished = true
        }
    }

    /// One pose of the mark in a Canvas, scaled to fit `box`. The head and
    /// tail draw in their own layer, and the triangle, the mouth and the eye
    /// are erased from it with `.destinationOut`.
    struct Drawing: View {
        let pose: MarkPose
        let ink: Ink
        let box: MarkGeometry.Box
        let letters: [Path]

        var body: some View {
            Canvas { context, size in
                let scale = min(size.width / box.width, size.height / box.height)
                context.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -box.x, y: -box.y)
                context.opacity = pose.opacity
                drawLetters(in: context)
                drawBody(in: context)
                drawAntennae(in: context)
            }
            .accessibilityHidden(true)
        }

        private func drawLetters(in context: GraphicsContext) {
            let style = StrokeStyle(lineWidth: MarkGeometry.letterStroke, lineCap: .round, lineJoin: .round)
            for (path, stroke) in zip(letters, pose.letters) where stroke.drawn > 0 {
                var letter = context
                letter.opacity *= stroke.opacity
                letter.stroke(path.trimmedPath(from: 0, to: min(stroke.drawn, 1)), with: .color(ink.letters), style: style)
            }
        }

        private func drawBody(in context: GraphicsContext) {
            guard pose.bodyScale > 0 else { return }
            context.drawLayer { layer in
                layer.concatenate(.about(MarkGeometry.Pivot.body, CGAffineTransform(scaleX: pose.bodyScale, y: pose.bodyScale)))
                layer.fill(Shapes.head, with: .color(ink.letters))
                var tail = layer
                tail.concatenate(
                    .about(MarkGeometry.Pivot.tail, CGAffineTransform(a: 1, b: tan(pose.tailSkew * .pi / 180), c: 0, d: 1, tx: 0, ty: 0)))
                tail.fill(Shapes.tail, with: .color(ink.letters))

                layer.blendMode = .destinationOut
                var mouth = layer
                mouth.concatenate(.about(MarkGeometry.Pivot.mouth, CGAffineTransform(scaleX: 1, y: pose.mouthOpen)))
                mouth.fill(Shapes.mouth, with: .color(.black))

                let hole = pose.playHole
                if hole.scaleX > 0, hole.scaleY > 0 {
                    var cut = layer
                    cut.concatenate(
                        .about(
                            MarkGeometry.Pivot.playHole,
                            CGAffineTransform(scaleX: hole.scaleX, y: hole.scaleY)
                                .concatenating(CGAffineTransform(translationX: hole.dx, y: hole.dy))))
                    cut.fill(Shapes.playHole, with: .color(.black))
                    cut.stroke(
                        Shapes.playHole, with: .color(.black), style: StrokeStyle(lineWidth: MarkGeometry.playHoleStroke, lineJoin: .round))
                }

                let eye = pose.eye
                if eye.scaleX > 0, eye.scaleY > 0 {
                    let center = MarkPath.Point(MarkGeometry.eyeCenter.x + eye.dx, MarkGeometry.eyeCenter.y + eye.dy)
                    var cut = layer
                    cut.concatenate(.about(center, CGAffineTransform(scaleX: eye.scaleX, y: eye.scaleY)))
                    cut.fill(Path(ellipseIn: .around(center, radius: MarkGeometry.eyeRadius)), with: .color(.black))
                }
            }
        }

        private func drawAntennae(in context: GraphicsContext) {
            for (antenna, part) in zip(MarkGeometry.antennae, pose.antennae) {
                var lean = context
                lean.concatenate(.about(antenna.base, CGAffineTransform(rotationAngle: part.lean * .pi / 180)))
                if part.stick.drawn > 0 {
                    var stick = lean
                    stick.opacity *= part.stick.opacity
                    var path = Path()
                    path.move(to: CGPoint(antenna.base))
                    path.addLine(to: CGPoint(antenna.stickEnd))
                    stick.stroke(
                        path.trimmedPath(from: 0, to: min(part.stick.drawn, 1)), with: .color(ink.letters),
                        style: StrokeStyle(lineWidth: antenna.stickWidth, lineCap: .round))
                }
                let tip = Path(ellipseIn: .around(antenna.tip, radius: antenna.tipRadius))
                if part.ringOpacity > 0 {
                    var ring = lean
                    ring.opacity *= part.ringOpacity
                    ring.concatenate(.about(antenna.tip, CGAffineTransform(scaleX: part.ringScale, y: part.ringScale)))
                    ring.stroke(tip, with: .color(ink.tips), lineWidth: MarkGeometry.ringStroke)
                }
                if part.tipScale > 0 {
                    var ball = lean
                    ball.opacity *= part.tipOpacity
                    ball.translateBy(x: 0, y: -part.tipLift)
                    ball.concatenate(.about(antenna.tip, CGAffineTransform(scaleX: part.tipScale, y: part.tipScale)))
                    ball.fill(tip, with: .color(ink.tips))
                }
            }
        }
    }

    /// The artwork's shapes as paths, read once.
    enum Shapes {
        static let letters = MarkGeometry.letters.map(path)
        static let head = path(MarkGeometry.head)
        static let mouth = path(MarkGeometry.mouth)
        static let tail = path(MarkGeometry.tail)
        static let playHole = path(MarkGeometry.playHole)

        /// A shape from path data; empty if the data does not read, which a
        /// core test rules out for every shape above.
        static func path(_ data: String) -> Path {
            var path = Path()
            for element in (try? MarkPath.elements(data)) ?? [] {
                switch element {
                case .move(let point): path.move(to: CGPoint(point))
                case .line(let point): path.addLine(to: CGPoint(point))
                case .quad(let to, let control): path.addQuadCurve(to: CGPoint(to), control: CGPoint(control))
                case .cubic(let to, let first, let second):
                    path.addCurve(to: CGPoint(to), control1: CGPoint(first), control2: CGPoint(second))
                case .close: path.closeSubpath()
                }
            }
            return path
        }
    }
}

extension CGPoint {
    fileprivate init(_ point: MarkPath.Point) { self.init(x: point.x, y: point.y) }
}

extension CGRect {
    fileprivate static func around(_ center: MarkPath.Point, radius: Double) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

extension CGAffineTransform {
    /// `transform` applied about `pivot` instead of the origin.
    fileprivate static func about(_ pivot: MarkPath.Point, _ transform: CGAffineTransform) -> CGAffineTransform {
        CGAffineTransform(translationX: -pivot.x, y: -pivot.y)
            .concatenating(transform)
            .concatenating(CGAffineTransform(translationX: pivot.x, y: pivot.y))
    }
}

#Preview("Brand mark, still, on dark and light") {
    VStack(spacing: Metrics.Spacing.xLarge) {
        BrandMark.Word(moment: .still).frame(width: 320)
        BrandMark.Word(moment: .still, ink: .onLight)
            .frame(width: 320)
            .padding(Metrics.Spacing.large)
            .background(Color(hex: 0xF2F4F8), in: Metrics.Corner.large.shape())
        HStack(spacing: Metrics.Spacing.large) {
            BrandMark.Letter(moment: .still).frame(width: 96)
            BrandMark.Letter(moment: .still)
                .frame(width: 96)
                .background(LinearGradient(colors: [.purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    .padding(Metrics.Spacing.xLarge)
    .background(Palette.ground)
}

#Preview("Brand mark, Hello") {
    VStack(spacing: Metrics.Spacing.large) {
        ForEach([0.4, 0.9, 1.4, 1.75, 2.35, 2.57], id: \.self) { seconds in
            BrandMark.Word(moment: .hello, clock: .frozen(seconds)).frame(width: 280)
        }
    }
    .padding(Metrics.Spacing.xLarge)
    .background(Palette.ground)
}

#Preview("Brand mark, Tuning and Got it") {
    VStack(spacing: Metrics.Spacing.large) {
        HStack(spacing: Metrics.Spacing.large) {
            ForEach([0.1, 0.72, 1.56, 2.064], id: \.self) { seconds in
                BrandMark.Letter(moment: .tuning, clock: .frozen(seconds)).frame(width: 96)
            }
        }
        HStack(spacing: Metrics.Spacing.large) {
            ForEach([0.0, 0.33, 0.5, 0.9], id: \.self) { seconds in
                BrandMark.Letter(moment: .gotIt, clock: .frozen(seconds)).frame(width: 96)
            }
        }
    }
    .padding(Metrics.Spacing.xLarge)
    .background(Palette.ground)
}

#Preview("Brand mark, Reduce Motion") {
    HStack(spacing: Metrics.Spacing.large) {
        let frames: [(MarkMoment, TimeInterval)] = [(.hello, 0.2), (.tuning, 0), (.tuning, 1.2), (.gotIt, 0.1)]
        ForEach(frames.indices, id: \.self) { index in
            BrandMark.Drawing(
                pose: MarkMotion.pose(frames[index].0, at: frames[index].1, reduceMotion: true), ink: .onDark,
                box: MarkGeometry.letterBox, letters: []
            )
            .frame(width: 96, height: 96)
        }
    }
    .padding(Metrics.Spacing.xLarge)
    .background(Palette.ground)
}
