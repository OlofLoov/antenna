import AntennaCore
import Foundation

/// Each source's tagged channels, and the flat list in source order worked
/// out again only after a source's channels or the order changed. A refresh
/// that brought the same channels is not stored again, so it costs no
/// list of 100 000 channels compared or copied on the main actor
/// (live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive).
struct SourceChannels {
    private var bySource: [UUID: [Channel]] = [:]
    private var version = 0
    /// What the last flat list was worked out from; no sources at first.
    private var flattened: (order: [UUID], version: Int) = ([], 0)

    /// A source's channels. Setting nil or an empty list over nil or an
    /// empty list changes nothing.
    subscript(id: UUID) -> [Channel]? {
        get { bySource[id] }
        set {
            let wasEmpty = bySource[id]?.isEmpty ?? true
            bySource[id] = newValue
            if !wasEmpty || !(newValue?.isEmpty ?? true) { version += 1 }
        }
    }

    /// Every source's channels in `order`, or nil when neither the channels
    /// nor the order of the sources holding them changed since the last call.
    mutating func changed(order: [UUID]) -> [Channel]? {
        let holding = order.filter { !(bySource[$0]?.isEmpty ?? true) }
        if flattened.order == holding, flattened.version == version { return nil }
        flattened = (holding, version)
        return holding.flatMap { bySource[$0] ?? [] }
    }
}
