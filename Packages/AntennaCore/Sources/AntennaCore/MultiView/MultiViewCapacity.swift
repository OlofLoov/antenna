import Foundation

/// How many tiles multi-view allows on a device
/// (multi-view/add-more-tiles-up-to-the-limit). Four on every Apple TV 4K
/// and Apple silicon Mac, two on Apple TV HD and Intel Macs. The four-tile
/// values hold until the hardware run passes on each generation.
public enum MultiViewCapacity {
    /// The device multi-view runs on.
    public enum Device: Sendable, Equatable {
        /// An Apple TV by its model identifier, such as "AppleTV5,3" (Apple TV HD).
        case appleTV(model: String)
        case mac(appleSilicon: Bool)
    }

    /// The most tiles `device` plays at once.
    public static func tiles(on device: Device) -> Int {
        switch device {
        case .appleTV(let model): model == "AppleTV5,3" ? 2 : 4
        case .mac(let appleSilicon): appleSilicon ? 4 : 2
        }
    }
}

/// The tile limit of one multi-view session. It starts at the device's
/// capacity and drops when the device cannot decode another stream, to the
/// larger of 2 and the tiles still decoding. It never rises again in the
/// same session.
public struct MultiViewCap: Sendable, Equatable {
    public private(set) var limit: Int

    public init(device: MultiViewCapacity.Device) {
        limit = MultiViewCapacity.tiles(on: device)
    }

    public init(limit: Int) {
        self.limit = limit
    }

    /// A tile failed because no decoder was free while `stillDecoding`
    /// tiles kept playing.
    public mutating func decoderRefused(stillDecoding: Int) {
        limit = min(limit, max(2, stillDecoding))
    }

    /// The toolbar count, "3 of 4". With more tiles than the limit after a
    /// drop, it reads "3 of 3".
    public func count(tiles: Int) -> String {
        "\(tiles) of \(max(limit, tiles))"
    }
}
