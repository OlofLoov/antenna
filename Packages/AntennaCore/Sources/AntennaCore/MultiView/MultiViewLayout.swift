import Foundation

/// Where multi-view's tiles sit in their container
/// (multi-view/add-more-tiles-up-to-the-limit). Two to four tiles use two
/// columns, three and four use two rows, every tile is 16:9 at the largest
/// whole width that fits, the grid is centered, and a third tile is
/// centered on the second row. One tile fills the container.
public struct MultiViewLayout: Sendable, Equatable {
    /// A tile's frame in points from the container's top left.
    public struct Frame: Sendable, Equatable {
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
    }

    /// Space between the container's edge and the grid.
    public var margin: Double
    /// Space between tiles.
    public var gap: Double

    public init(margin: Double, gap: Double) {
        self.margin = margin
        self.gap = gap
    }

    /// The Apple TV screen, 1920 by 1080 with margin 24 and gap 16.
    public static let television = MultiViewLayout(margin: 24, gap: 16)
    /// The Mac window's tile area, margin 16 and gap 12.
    public static let mac = MultiViewLayout(margin: 16, gap: 12)

    /// The frames of `count` tiles in a `width` by `height` container, in
    /// tile order. Empty for no tiles; more than four lay out as four.
    public func frames(count: Int, width: Double, height: Double) -> [Frame] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [Frame(x: 0, y: 0, width: width, height: height)] }
        let tiles = min(count, 4)
        let rows = tiles > 2 ? 2.0 : 1.0
        let byWidth = (width - 2 * margin - gap) / 2
        let byHeight = (height - 2 * margin - (rows - 1) * gap) / rows * 16 / 9
        let tileWidth = max(0, min(byWidth, byHeight).rounded(.down))
        let tileHeight = (tileWidth * 9 / 16).rounded(.down)
        let gridWidth = tileWidth * 2 + gap
        let gridHeight = tileHeight * rows + (rows - 1) * gap
        let left = ((width - gridWidth) / 2).rounded(.down)
        let top = ((height - gridHeight) / 2).rounded(.down)
        return (0..<tiles).map { index in
            let row = Double(index / 2)
            let column = Double(index % 2)
            var x = left + column * (tileWidth + gap)
            if tiles == 3, index == 2 { x = ((width - tileWidth) / 2).rounded(.down) }
            return Frame(x: x, y: top + row * (tileHeight + gap), width: tileWidth, height: tileHeight)
        }
    }
}
