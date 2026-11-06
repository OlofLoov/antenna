import Foundation

/// A favorite as the catalogue sees it. The app layer maps `FavoriteRecord`
/// to and from this type, with `Token` as the record's persistent
/// identifier; the catalogue never reads or writes the store.
///
/// `channelID` can embed a stream URL with credentials, so a snapshot is
/// never logged.
public struct FavoriteSnapshot<Token: Hashable & Sendable>: Hashable, Sendable {
    /// The `Channel.id` of the favorited channel.
    public var channelID: String
    /// Nil matches the channel in any source.
    public var sourceID: UUID?
    /// Position in the Favorites group, lowest first.
    public var sortOrder: Int
    /// The record this snapshot was read from; nil for one not yet stored.
    public var recordToken: Token?

    public init(channelID: String, sourceID: UUID?, sortOrder: Int, recordToken: Token? = nil) {
        self.channelID = channelID
        self.sourceID = sourceID
        self.sortOrder = sortOrder
        self.recordToken = recordToken
    }
}
