import Foundation

/// Identifies one row of the catalogue. Two channels with the same `id`
/// still get distinct keys because `position` differs.
///
/// Holds `Channel.id`, which can embed a stream URL with credentials, so
/// a key is never logged or persisted.
public struct RowKey: Hashable, Sendable {
    /// The channel's `sourceID`.
    public let sourceID: UUID
    /// The channel's `id`.
    public let id: String
    /// The channel's 0-based `position` in its source.
    public let position: Int

    /// Nil when the channel has no `sourceID` or `position`, that is, when
    /// `Channel.tagged(_:sourceID:)` has not run on it.
    public init?(_ channel: Channel) {
        guard let sourceID = channel.sourceID, let position = channel.position else { return nil }
        self.sourceID = sourceID
        self.id = channel.id
        self.position = position
    }
}
