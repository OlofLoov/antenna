import Foundation

/// Where a title page's backdrop sits in the area the page gives it
/// (title-detail-and-episode-picker/what-the-title-is-about). The picture
/// shows whole at its own proportions; it fills the area edge to edge only
/// when that cuts at most `mostCut` of it. Where it does not reach, a
/// blurred copy of itself shows. The rule goes by the decoded picture's
/// shape, since many providers send the poster as the backdrop.
public struct TitleArtPlacement: Sendable, Hashable {
    /// A rectangle in points, from the top left.
    public struct Box: Sendable, Hashable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public var maxX: Double { x + width }
        public var maxY: Double { y + height }
    }

    public enum Look: Sendable, Hashable {
        /// Covers the area, cut by at most `mostCut` at two edges.
        case fills
        /// Whole, across the area's width or down its height, with the
        /// blurred copy on the other two sides.
        case whole
        /// A picture taller than wide, such as a poster, whole and inset
        /// by the margin, with rounded corners over the blurred copy.
        case framed
    }

    /// Where a picture that does not span the area's width sits.
    public enum Alignment: Sendable, Hashable {
        /// In the middle, on iPhone where nothing covers the picture.
        case center
        /// Against the right, on the wide cards and screens whose copy
        /// covers the left.
        case trailing
    }

    public var look: Look
    /// The picture's place; it reaches past the area only when it fills.
    public var picture: Box

    /// The most of a picture filling may cut: 8%, so a 1.85:1 picture in a
    /// 16:9 area fills rather than leaving thin bands of blur.
    public static let mostCut = 0.08

    /// Places a picture in `area`. `margin` insets a framed picture from the
    /// area's top and bottom, and from its right when aligned there. A
    /// picture or area with no size fills the area.
    public static func place(
        pictureWidth: Double, pictureHeight: Double, in area: Box, alignment: Alignment, margin: Double
    ) -> TitleArtPlacement {
        guard pictureWidth > 0, pictureHeight > 0, area.width > 0, area.height > 0 else {
            return TitleArtPlacement(look: .fills, picture: area)
        }
        let picture = pictureWidth / pictureHeight
        let frame = area.width / area.height
        if min(picture, frame) / max(picture, frame) >= 1 - mostCut {
            let scale = max(area.width / pictureWidth, area.height / pictureHeight)
            let width = pictureWidth * scale
            let height = pictureHeight * scale
            return TitleArtPlacement(
                look: .fills,
                picture: Box(x: area.x + (area.width - width) / 2, y: area.y + (area.height - height) / 2, width: width, height: height))
        }
        if picture > frame {
            let height = area.width / picture
            return TitleArtPlacement(
                look: .whole, picture: Box(x: area.x, y: area.y + (area.height - height) / 2, width: area.width, height: height))
        }
        if picture >= 1 {
            let width = area.height * picture
            return TitleArtPlacement(
                look: .whole, picture: Box(x: x(width, in: area, alignment, margin: 0), y: area.y, width: width, height: area.height))
        }
        let height = max(area.height - 2 * margin, area.height / 2)
        let width = height * picture
        return TitleArtPlacement(
            look: .framed,
            picture: Box(
                x: x(width, in: area, alignment, margin: margin), y: area.y + (area.height - height) / 2, width: width, height: height))
    }

    private static func x(_ width: Double, in area: Box, _ alignment: Alignment, margin: Double) -> Double {
        switch alignment {
        case .center: area.x + (area.width - width) / 2
        case .trailing: area.maxX - margin - width
        }
    }

    /// The share of the picture inside `area`, 1 when none of it is cut.
    public func shown(in area: Box) -> Double {
        guard picture.width > 0, picture.height > 0 else { return 0 }
        let width = max(0, min(picture.maxX, area.maxX) - max(picture.x, area.x))
        let height = max(0, min(picture.maxY, area.maxY) - max(picture.y, area.y))
        return width * height / (picture.width * picture.height)
    }
}

extension TitleArtPlacement {
    /// On iPhone the picture gets an exact 16:9 area under the status bar,
    /// as wide as the screen.
    public static func phoneArea(width: Double, top: Double) -> Box {
        Box(x: 0, y: top, width: width, height: width * 9 / 16)
    }

    /// The iPad and Mac card: 16:9 for its width, at least 380 tall so the
    /// copy fits over it and at most 560 so a wide window keeps the page's
    /// words in view. A 16:9 picture in a card held at 560 shows whole
    /// against the right.
    public static func cardHeight(width: Double) -> Double {
        min(max(width * 9 / 16, 380), 560)
    }
}
