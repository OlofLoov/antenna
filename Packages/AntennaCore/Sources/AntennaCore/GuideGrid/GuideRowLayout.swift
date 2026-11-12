import Foundation

/// One stretch of a guide row: a programme, or a gap with no programme.
public struct GuideSegment: Sendable, Equatable {
    public var start: Date
    public var stop: Date
    /// Nil for a gap.
    public var programme: Programme?

    public init(start: Date, stop: Date, programme: Programme? = nil) {
        self.start = start
        self.stop = stop
        self.programme = programme
    }

    /// True from `start` until just before `stop`.
    public func contains(_ date: Date) -> Bool {
        start <= date && date < stop
    }
}

/// Whether a block is over, on now or still to come.
public enum GuideTiming: Sendable, Equatable {
    case past, now, future

    /// Past once `stop` is reached, now from `start`, future before that.
    public init(start: Date, stop: Date, now: Date) {
        if stop <= now {
            self = .past
        } else if start <= now {
            self = .now
        } else {
            self = .future
        }
    }
}

/// A segment as drawn in the window, in points from the window's left edge.
public struct GuideBlock: Sendable, Equatable {
    public var segment: GuideSegment
    public var leading: Double
    public var width: Double
    /// The segment began before the window and is cut at its left edge.
    public var startedEarlier: Bool
    public var timing: GuideTiming
}

/// Turns one row's programmes into blocks for the visible window
/// (tv-guide-grid/programmes-are-drawn-to-scale).
public enum GuideRowLayout {
    /// The space between two blocks.
    public static let gap = 4.0
    /// No block is drawn narrower than this on Apple TV.
    public static let minimumWidth = GuideScale.television.minimumBlockWidth
    public static let rowHeight = 84.0

    /// The row from `floor` to `ceiling` with no holes: every programme, in
    /// start order, and a gap wherever none is on. A gap starts at the
    /// previous programme's stop, or at `floor` before the first one, and
    /// ends at the next start or `ceiling`. Pass programmes sorted by start
    /// and free of overlaps, as the guide store returns them; one that starts
    /// before the previous stop begins at that stop. Empty when there are no
    /// programmes.
    public static func segments(_ programmes: [Programme], from floor: Date, to ceiling: Date) -> [GuideSegment] {
        guard !programmes.isEmpty else { return [] }
        var segments: [GuideSegment] = []
        var cursor = min(floor, programmes[0].start)
        for programme in programmes {
            let start = max(programme.start, cursor)
            guard programme.stop > start else { continue }
            if start > cursor { segments.append(GuideSegment(start: cursor, stop: start)) }
            segments.append(GuideSegment(start: start, stop: programme.stop, programme: programme))
            cursor = programme.stop
        }
        if ceiling > cursor { segments.append(GuideSegment(start: cursor, stop: ceiling)) }
        return segments
    }

    /// The segments that overlap `window`, laid out at `scale`'s column
    /// width, 370 pt per half hour on Apple TV, with a 4 pt gap after each.
    /// A block cut by the left edge starts at 0 and is marked as started
    /// earlier. One narrower than the scale's minimum, 40 pt on Apple TV,
    /// widens to it and pushes the next block's leading edge right while
    /// keeping that block's trailing edge, so blocks never overlap.
    public static func blocks(
        _ segments: [GuideSegment], in window: DateInterval, now: Date, scale: GuideScale = .television
    ) -> [GuideBlock] {
        let width = scale.offset(of: window.end, from: window.start)
        var previousTrailing = -Double.infinity
        var blocks: [GuideBlock] = []
        for segment in segments where segment.stop > window.start && segment.start < window.end {
            let naturalLeading = max(0, scale.offset(of: segment.start, from: window.start))
            let naturalTrailing = min(width, scale.offset(of: segment.stop, from: window.start)) - gap
            let leading = max(naturalLeading, previousTrailing + gap)
            let trailing = max(naturalTrailing, leading + scale.minimumBlockWidth)
            previousTrailing = trailing
            blocks.append(
                GuideBlock(
                    segment: segment, leading: leading, width: trailing - leading, startedEarlier: segment.start < window.start,
                    timing: GuideTiming(start: segment.start, stop: segment.stop, now: now)))
        }
        return blocks
    }

    /// The index of the segment on at `date`, or nil when `date` is outside the row.
    public static func index(of date: Date, in segments: [GuideSegment]) -> Int? {
        segments.firstIndex { $0.contains(date) }
    }
}
