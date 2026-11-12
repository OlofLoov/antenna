import Foundation

/// How big a guide grid draws time: the width of a half-hour column, the
/// narrowest block and the channel column beside the rows. The Apple TV grid
/// uses `television`; the iPad and Mac grid takes its width from `GuideZoom`.
public struct GuideScale: Sendable, Equatable {
    /// Points per half hour.
    public var columnWidth: Double
    /// No block is drawn narrower than this.
    public var minimumBlockWidth: Double
    /// The channel column, the 4 pt gap after it included.
    public var channelColumn: Double

    public init(columnWidth: Double, minimumBlockWidth: Double, channelColumn: Double) {
        self.columnWidth = columnWidth
        self.minimumBlockWidth = minimumBlockWidth
        self.channelColumn = channelColumn
    }

    /// The Apple TV guide: 370 pt per half hour, 40 pt blocks, a 300 pt channel column.
    public static let television = GuideScale(columnWidth: 370, minimumBlockWidth: 40, channelColumn: 300)

    /// Points from `start` to `date`.
    public func offset(of date: Date, from start: Date) -> Double {
        date.timeIntervalSince(start) / GuideTimeline.column * columnWidth
    }

    /// The time `offset` points after `start`.
    public func date(at offset: Double, from start: Date) -> Date {
        start.addingTimeInterval(offset / columnWidth * GuideTimeline.column)
    }
}

/// The four zoom steps of the iPad and Mac guide
/// (guide-on-iphone-ipad-and-mac/zoom): 90, 120, 180 and 270 pt per half
/// hour, 180 by default. The step is kept per device.
public struct GuideZoom: Sendable, Equatable {
    public static let widths: [Double] = [90, 120, 180, 270]
    public static let defaultStep = 2
    /// Blocks narrower than this widen and push the next one right.
    public static let minimumBlockWidth = 28.0
    public static let channelColumn = 200.0

    /// An index into `widths`.
    public private(set) var step: Int

    /// `step` kept inside the four steps.
    public init(step: Int = defaultStep) {
        self.step = min(max(step, 0), Self.widths.count - 1)
    }

    public var scale: GuideScale {
        GuideScale(columnWidth: Self.widths[step], minimumBlockWidth: Self.minimumBlockWidth, channelColumn: Self.channelColumn)
    }

    public var canZoomIn: Bool { step < Self.widths.count - 1 }
    public var canZoomOut: Bool { step > 0 }

    /// One step wider, or the same at the widest.
    public var zoomedIn: GuideZoom { GuideZoom(step: step + 1) }
    /// One step narrower, or the same at the narrowest.
    public var zoomedOut: GuideZoom { GuideZoom(step: step - 1) }

    /// The step closest to the current width times `magnification`, as a
    /// pinch ends.
    public func pinched(by magnification: Double) -> GuideZoom {
        let target = Self.widths[step] * magnification
        let nearest = Self.widths.indices.min { abs(Self.widths[$0] - target) < abs(Self.widths[$1] - target) } ?? step
        return GuideZoom(step: nearest)
    }

    /// The horizontal scroll offset that keeps `time` at `x` points from the
    /// grid's left edge after a zoom, with the timeline starting at `origin`.
    public static func offset(keeping time: Date, at x: Double, origin: Date, scale: GuideScale) -> Double {
        max(0, scale.offset(of: time, from: origin) - x)
    }
}
