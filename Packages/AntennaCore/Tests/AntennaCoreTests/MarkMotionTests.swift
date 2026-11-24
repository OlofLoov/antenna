import AntennaCore
import Foundation
import Testing

@Suite struct MarkMotionTests {
    private func pose(_ moment: MarkMoment, _ seconds: Double, reduceMotion: Bool = false) -> MarkPose {
        MarkMotion.pose(moment, at: seconds, reduceMotion: reduceMotion)
    }

    /// Whether two poses match to a thousandth in every number.
    private func same(_ first: MarkPose, _ second: MarkPose) -> Bool {
        func numbers(_ pose: MarkPose) -> [Double] {
            var all = [pose.opacity, pose.bodyScale, pose.tailSkew, pose.mouthOpen]
            for part in [pose.playHole, pose.eye] { all += [part.dx, part.dy, part.scaleX, part.scaleY] }
            for stroke in pose.letters { all += [stroke.drawn, stroke.opacity] }
            for antenna in pose.antennae {
                all += [
                    antenna.lean, antenna.stick.drawn, antenna.stick.opacity, antenna.tipScale, antenna.tipLift, antenna.tipOpacity,
                    antenna.ringOpacity,
                ]
            }
            return all
        }
        return zip(numbers(first), numbers(second)).allSatisfy { abs($0 - $1) < 0.001 }
    }

    @Test("design-system/the-mark-moves-at-three-moments: Hello lasts 3.2 s, Got it 1.2 s, Tuning loops")
    func durations() {
        #expect(MarkMotion.duration(.hello, reduceMotion: false) == 3.2)
        #expect(MarkMotion.duration(.gotIt, reduceMotion: false) == 1.2)
        #expect(MarkMotion.duration(.tuning, reduceMotion: false) == nil)
        #expect(MarkMotion.duration(.still, reduceMotion: false) == nil)
        #expect(MarkMotion.tuningPeriod == 2.4)
    }

    @Test("design-system/the-mark-moves-at-three-moments: Hello writes the word, opens the triangle and pops the tips")
    func helloSequence() {
        let start = pose(.hello, 0)
        #expect(start.letters.allSatisfy { $0.drawn == 0 && $0.opacity == 0 })
        #expect(start.bodyScale == 0 && start.playHole.scaleX == 0)
        #expect(start.antennae.allSatisfy { $0.stick.drawn == 0 && $0.tipScale == 0 })

        let writing = pose(.hello, 0.4)
        #expect(writing.letters[0].drawn > writing.letters[4].drawn, "left to right")

        let landed = pose(.hello, 1.0)
        #expect(landed.letters.allSatisfy { $0.drawn > 0.99 })
        #expect(landed.bodyScale > 0.99 && landed.playHole.scaleX > 0.99)
        #expect(landed.antennae.allSatisfy { $0.tipScale == 0 }, "the antennae rise after the head lands")

        #expect(pose(.hello, 1.75).mouthOpen > 2, "the mouth says hello")
        #expect(pose(.hello, 1.75).antennae.allSatisfy { $0.tipScale > 0.9 })

        let eye = pose(.hello, 2.35)
        #expect(eye.eye.scaleX > 0.99 && eye.playHole.scaleX == 0, "the triangle has become the eye")
        #expect(abs(eye.playHole.dx - -21) < 0.001 && abs(eye.playHole.dy - -21) < 0.001)
        #expect(pose(.hello, 2.57).eye.scaleY < 0.2, "one blink")
    }

    @Test("design-system/the-mark-moves-at-three-moments: Hello and Got it end on the still mark")
    func oneShotsEndStill() {
        #expect(same(pose(.hello, 3.2), .still))
        #expect(same(pose(.hello, 60), .still))
        #expect(same(pose(.gotIt, 1.2), .still))
        #expect(same(pose(.gotIt, 60), .still))
    }

    @Test("design-system/the-mark-moves-at-three-moments: Tuning leans every 2.4 s with the triangle as the eye")
    func tuningLoops() {
        let lean = pose(.tuning, 0.72)
        #expect(abs(lean.antennae[0].lean - -14) < 0.001 && abs(lean.antennae[1].lean - -9) < 0.001)
        let other = pose(.tuning, 1.56)
        #expect(abs(other.antennae[0].lean - 9) < 0.001 && abs(other.antennae[1].lean - 14) < 0.001)
        for time in [1.0, 1.7, 2.1] {
            #expect(same(pose(.tuning, time), pose(.tuning, time + 2.4)), "at \(time) s")
            #expect(same(pose(.tuning, time), pose(.tuning, time + 24)), "ten loops later")
        }
        let settled = pose(.tuning, 1.0)
        #expect(settled.playHole.scaleX == 0 && settled.eye.scaleX > 0.99)
        #expect(pose(.tuning, 2.064).eye.scaleY < 0.2, "a blink at 86% of the loop")
        #expect(pose(.tuning, 1.2).mouthOpen > 2, "the mouth breathes")
        #expect(pose(.tuning, 0.1).antennae[1].ringOpacity == 0, "the right ring starts 0.6 s later")
        #expect(pose(.tuning, 0.7).antennae[1].ringOpacity > 0.5)
        #expect(pose(.tuning, 0.1).antennae[0].ringOpacity > 0.5)
    }

    @Test("design-system/the-mark-moves-at-three-moments: Got it flicks, hops, squints and gulps, then the eye goes home")
    func gotItSequence() {
        let start = pose(.gotIt, 0)
        #expect(start.eye.scaleX == 1 && start.playHole.scaleX == 0, "it takes over from Tuning's eye")
        let middle = pose(.gotIt, 0.33)
        #expect(middle.tailSkew < -15)
        #expect(middle.eye.scaleY < 0.5 && middle.eye.scaleX > 1, "a happy squint")
        #expect(pose(.gotIt, 0.28).mouthOpen > 3, "a gulp")
        #expect(pose(.gotIt, 0.5).antennae[0].tipLift > 8)
        let home = pose(.gotIt, 1.08)
        #expect(home.eye.scaleX == 0 && home.playHole.scaleX > 0.99)
    }

    @Test("design-system/reduce-motion-stills-the-mark: nothing draws, leans, hops or slides")
    func reduceMotionMovesNothing() {
        for moment in MarkMoment.allCases {
            for step in 0...50 {
                let time = Double(step) * 0.1
                var still = pose(moment, time, reduceMotion: true)
                still.opacity = 1
                for side in still.antennae.indices { still.antennae[side].tipOpacity = 1 }
                #expect(still == .still, "\(moment) at \(time) s")
            }
        }
    }

    @Test("design-system/reduce-motion-stills-the-mark: Hello and Got it fade over 0.4 s, Tuning pulses the tips")
    func reduceMotionFadesAndPulses() {
        #expect(MarkMotion.duration(.hello, reduceMotion: true) == 0.4)
        #expect(MarkMotion.duration(.gotIt, reduceMotion: true) == 0.4)
        #expect(MarkMotion.duration(.tuning, reduceMotion: true) == nil)
        #expect(pose(.hello, 0, reduceMotion: true).opacity == 0)
        #expect(pose(.hello, 0.4, reduceMotion: true).opacity == 1)
        #expect(pose(.gotIt, 0, reduceMotion: true).opacity == 0.5)
        #expect(pose(.gotIt, 0.4, reduceMotion: true).opacity == 1)
        let dim = pose(.tuning, 1.2, reduceMotion: true)
        #expect(dim.antennae.allSatisfy { abs($0.tipOpacity - 0.35) < 0.001 } && dim.opacity == 1)
        #expect(pose(.tuning, 2.4, reduceMotion: true).antennae.allSatisfy { $0.tipOpacity == 1 })
        #expect(pose(.tuning, 1.2, reduceMotion: true).eye == .hidden, "no eye")
    }

    @Test("design-system/the-mark-moves-at-three-moments: the timing curves match the browser's")
    func curves() {
        #expect(CubicBezier.linear(0.3) == 0.3)
        #expect(abs(CubicBezier.easeInOut(0.5) - 0.5) < 0.0001)
        #expect(CubicBezier.easeIn(0.25) < 0.25 && CubicBezier.easeOut(0.25) > 0.25)
        // CSS `ease` at 25% of the time is about 41% of the way, as browsers compute it.
        #expect(abs(CubicBezier.ease(0.25) - 0.4085) < 0.002)
        let overshoot = CubicBezier(0.3, 1.8, 0.5, 1)
        #expect((1...9).map { overshoot(Double($0) / 10) }.max()! > 1.1, "the tips pop past full size")
        #expect(overshoot(0) == 0 && overshoot(1) == 1)
    }
}
