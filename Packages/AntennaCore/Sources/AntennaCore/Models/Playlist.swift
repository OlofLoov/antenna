import Foundation

/// The result of loading one source: channels plus whatever EPG hint it carried.
public struct Playlist: Sendable, Equatable {
    public var channels: [Channel]
    /// `url-tvg` / `x-tvg-url` / `tvg-url` from the `#EXTM3U` header, if present.
    public var epgURLs: [URL]
    /// An Xtream panel's time zone name from its account information, nil
    /// for playlists and when the panel named none. Kept in memory only.
    public var serverTimeZone: String?
    /// For an M3U playlist, the id earlier versions gave each channel, mapped
    /// to its id now (m3u-playlists/earlier-ids-map-to-the-new-ones). Earlier
    /// ids can hold a stream link with its login, so the map stays in memory
    /// and is never logged.
    public var formerIDs: [String: String]
    /// A playlist's movie entries, which `separatingMovies()` moves out of
    /// `channels`. Their links can hold the login: never log or store them.
    public var movies: [Channel]

    public init(
        channels: [Channel], epgURLs: [URL] = [], serverTimeZone: String? = nil, formerIDs: [String: String] = [:], movies: [Channel] = []
    ) {
        self.channels = channels
        self.movies = movies
        self.epgURLs = epgURLs
        self.serverTimeZone = serverTimeZone
        self.formerIDs = formerIDs
    }

    public var groups: [String] {
        var seen = Set<String>()
        return channels.compactMap { channel in
            guard let group = channel.group, seen.insert(group).inserted else { return nil }
            return group
        }
    }
}
