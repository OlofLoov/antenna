import Foundation

/// A channel as the on-device recents, the restored session and the Apple
/// TV's last channel store it: its source and its id, never a stream link.
///
/// The JSON form is `{"sourceID": "<uuid>", "channelID": "<id>"}`, the value
/// the Apple TV shell has stored since before recents existed.
public struct LastChannelKey: Codable, Hashable, Sendable {
    public var sourceID: UUID
    public var channelID: String

    /// Nil when the channel has no source, or when its id still contains a
    /// stream link (session-restore-and-recently-watched/links-with-passwords-are-never-stored).
    /// No current source puts a link in an id; ids from earlier versions did.
    public init?(_ channel: Channel) {
        guard let sourceID = channel.sourceID, Self.canStore(channel.id) else { return nil }
        self.sourceID = sourceID
        self.channelID = channel.id
    }

    public init(sourceID: UUID, channelID: String) {
        self.sourceID = sourceID
        self.channelID = channelID
    }

    /// True when `channel` came from this source and has this id.
    public func matches(_ channel: Channel) -> Bool {
        channel.sourceID == sourceID && channel.id == channelID
    }

    /// The key with the new id `ids` names when it belongs to `source`, else
    /// unchanged. A new id holding a stream link is not taken.
    public func renamingChannel(_ ids: [String: String], source: UUID) -> LastChannelKey {
        guard sourceID == source, let id = ids[channelID], Self.canStore(id) else { return self }
        return LastChannelKey(sourceID: sourceID, channelID: id)
    }

    /// False for an id that holds a stream link, recognized by `://`.
    public static func canStore(_ channelID: String) -> Bool {
        !channelID.contains("://")
    }
}
