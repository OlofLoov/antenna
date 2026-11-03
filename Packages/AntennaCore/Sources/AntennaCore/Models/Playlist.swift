import Foundation

/// The result of loading one source: channels plus whatever EPG hint it carried.
public struct Playlist: Sendable, Equatable {
    public var channels: [Channel]
    /// `url-tvg` / `x-tvg-url` from the `#EXTM3U` header, if present.
    public var epgURLs: [URL]

    public init(channels: [Channel], epgURLs: [URL] = []) {
        self.channels = channels
        self.epgURLs = epgURLs
    }

    public var groups: [String] {
        var seen = Set<String>()
        return channels.compactMap { channel in
            guard let group = channel.group, seen.insert(group).inserted else { return nil }
            return group
        }
    }
}
