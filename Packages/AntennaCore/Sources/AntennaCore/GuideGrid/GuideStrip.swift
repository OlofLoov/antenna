import Foundation

/// One channel's cards on the iPhone guide
/// (guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone): the
/// programme on at the row's time first, then each later one, with a card
/// holding just the times for each gap between two programmes.
public enum GuideStrip {
    /// Points per card, and the space between two cards.
    public static let cardWidth = 168.0
    public static let cardHeight = 54.0
    public static let spacing = 6.0

    /// The cards from the programme on at `anchor`, or from the first one
    /// after it when nothing is on. A gap before that first programme and
    /// after the last one is left out. Pass programmes sorted by start, as
    /// the guide store returns them.
    public static func cards(_ programmes: [Programme], from anchor: Date) -> [GuideSegment] {
        let later = programmes.filter { $0.stop > anchor }
        guard let first = later.first, let last = later.last else { return [] }
        return GuideRowLayout.segments(later, from: first.start, to: last.stop)
    }
}
