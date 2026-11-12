import Foundation

/// The result of loading one source: channels plus whatever EPG hint it carried.
public struct Playlist: Sendable, Equatable {
    public var channels: [Channel]
    /// `url-tvg` / `x-tvg-url` from the `#EXTM3U` header, if present.
    public var epgURLs: [URL]
    /// An Xtream panel's time zone name from its account information, nil
    /// for playlists and when the panel named none. Kept in memory only.
    public var serverTimeZone: String?

    public init(channels: [Channel], epgURLs: [URL] = [], serverTimeZone: String? = nil) {
        self.channels = channels
        self.epgURLs = epgURLs
        self.serverTimeZone = serverTimeZone
    }

    public var groups: [String] {
        var seen = Set<String>()
        return channels.compactMap { channel in
            guard let group = channel.group, seen.insert(group).inserted else { return nil }
            return group
        }
    }
}
