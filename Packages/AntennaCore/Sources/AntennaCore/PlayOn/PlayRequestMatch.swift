import Foundation

/// Finds what a request names among what the Apple TV has loaded, and says
/// why it cannot play when it finds nothing
/// (play-on-apple-tv/the-phone-says-why-the-tv-cannot-play).
public enum PlayRequestMatch {
    /// The request's source as the TV sees it.
    public enum Source: Sendable, Hashable {
        /// No source with that id has reached the TV.
        case missing
        /// The source is there with no login on the TV.
        case noLogin
        /// Its channels or titles are still loading.
        case loading
        case loaded
    }

    /// What the TV plays.
    public enum Target: Sendable, Hashable {
        case channel(Channel)
        /// An ended programme's recording, from its start.
        case catchup(Channel, start: Date, end: Date)
        case movie(ShelfTitle)
        /// The series and the key of the episode to find in its list.
        case episode(ShelfTitle, episodeKey: String)
    }

    public enum Outcome: Sendable, Hashable {
        case play(Target)
        case refuse(PlayAnswer.Result)
        /// Nothing yet, but the source is still loading; ask again when it changes.
        case wait
    }

    /// Resolves `request` against the source's `channels` and, once Movies
    /// or Series have loaded, its `titles` (nil before then). `key` turns a
    /// provider's id into the key a request carries. A programme that ended
    /// plays its catch-up when the channel has catch-up; one that is still on
    /// plays the channel live.
    public static func resolve(
        _ request: PlayRequest, source: Source, channels: [Channel], titles: [ShelfTitle]?, now: Date, key: (String) -> String
    ) -> Outcome {
        switch source {
        case .missing: return .refuse(.noSource(source: request.source))
        case .noLogin: return .refuse(.noLogin(source: request.source))
        case .loading, .loaded: break
        }
        let ownChannels = channels.lazy.filter { $0.sourceID == request.source }
        let ownTitles = titles.map { $0.filter { $0.sourceID == request.source } }
        let found: Target?
        switch request.item {
        case .channel(let channelKey):
            found = ownChannels.first { key($0.id) == channelKey }.map(Target.channel)
        case .programme(let channelKey, let start, let end):
            guard let channel = ownChannels.first(where: { key($0.id) == channelKey }) else {
                found = nil
                break
            }
            if end > now {
                found = .channel(channel)
            } else if channel.hasCatchup {
                found = .catchup(channel, start: start, end: end)
            } else {
                return .refuse(.notFound)
            }
        case .movie(let titleKey):
            guard let ownTitles else { return .wait }
            found = ownTitles.first { $0.kind == .movie && key($0.id) == titleKey }.map(Target.movie)
        case .episode(let seriesKey, let episodeKey):
            guard let ownTitles else { return .wait }
            found = ownTitles.first { $0.kind == .series && key($0.id) == seriesKey }.map { .episode($0, episodeKey: episodeKey) }
        }
        if let found { return .play(found) }
        return source == .loading ? .wait : .refuse(.notFound)
    }
}
