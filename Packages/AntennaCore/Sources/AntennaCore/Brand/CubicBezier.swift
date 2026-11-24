import Foundation

/// A CSS timing curve, `cubic-bezier(x1, y1, x2, y2)`, as a browser
/// evaluates it: the curve runs from (0, 0) to (1, 1), x is time and y is
/// progress, which may overshoot 1 when a control point's y does.
public struct CubicBezier: Equatable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2)
    }

    public static let linear = CubicBezier(0, 0, 1, 1)
    public static let ease = CubicBezier(0.25, 0.1, 0.25, 1)
    public static let easeIn = CubicBezier(0.42, 0, 1, 1)
    public static let easeOut = CubicBezier(0, 0, 0.58, 1)
    public static let easeInOut = CubicBezier(0.42, 0, 0.58, 1)

    /// Progress at `time` from 0 to 1; times outside that range are clamped.
    public func callAsFunction(_ time: Double) -> Double {
        let time = min(max(time, 0), 1)
        if self == .linear { return time }
        return sample(y1, y2, parameter(for: time))
    }

    private func sample(_ first: Double, _ second: Double, _ param: Double) -> Double {
        let inverse = 1 - param
        return 3 * inverse * inverse * param * first + 3 * inverse * param * param * second + param * param * param
    }

    private func slope(_ first: Double, _ second: Double, _ param: Double) -> Double {
        let inverse = 1 - param
        return 3 * inverse * inverse * first + 6 * inverse * param * (second - first) + 3 * param * param * (1 - second)
    }

    /// The curve parameter whose x is `time`: Newton's method, then
    /// bisection if it stalls. x always rises, since both x control
    /// points are within 0 and 1.
    private func parameter(for time: Double) -> Double {
        var param = time
        for _ in 0..<8 {
            let error = sample(x1, x2, param) - time
            if abs(error) < 1e-7 { return param }
            let derivative = slope(x1, x2, param)
            if abs(derivative) < 1e-6 { break }
            param -= error / derivative
        }
        var (low, high) = (0.0, 1.0)
        param = time
        for _ in 0..<60 {
            let x = sample(x1, x2, param)
            if abs(x - time) < 1e-7 { break }
            if x < time { low = param } else { high = param }
            param = (low + high) / 2
        }
        return param
    }
}
