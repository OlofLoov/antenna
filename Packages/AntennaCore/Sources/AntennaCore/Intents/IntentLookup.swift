import Foundation

/// A source as Siri and Shortcuts see it: its name and how far its load got.
public struct IntentSource: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        /// Not asked to load in this run yet, or loading now.
        case loading
        case loaded
        case offline
        case failed
        case waitingForLogin
    }

    public var id: UUID
    public var name: String
    public var state: State

    public init(id: UUID, name: String, state: State) {
        self.id = id
        self.name = name
        self.state = state
    }
}

/// Turns a saved reference into the channel or title it names, or the
/// reason it cannot play (app-intents/a-clear-reply-when-a-channel-or-title-cannot-play),
/// and lists what Shortcuts suggests (app-intents/shortcuts-suggests-what-you-watch).
public enum IntentLookup {
    /// The most channels Shortcuts suggests.
    public static let channelSuggestions = 200
    /// The most titles Shortcuts suggests.
    public static let titleSuggestions = 50
    /// The most channels one query offers.
    public static let matches = 20

    /// The channel `key` names. Fails when its source is gone, when the
    /// channel is locked, or, when it is not loaded, with the source's state:
    /// still loading, offline, failed, waiting for its login, or loaded
    /// without it.
    public static func channel<Token>(
        _ key: LastChannelKey, in catalogue: Catalogue<Token>, sources: [IntentSource]
    ) -> Result<Channel, IntentFailure> {
        guard let source = sources.first(where: { $0.id == key.sourceID }) else { return .failure(.channelSourceGone) }
        if let row = catalogue.row(for: key), let channel = catalogue.channel(for: row) {
            return catalogue.isLocked(row) ? .failure(.locked(channel: channel.name)) : .success(channel)
        }
        return .failure(missing(source) ?? .channelGone(channel: nil, source: source.name))
    }

    /// The title `reference` names among `titles`, failing as `channel` does.
    public static func title(_ reference: TitleReference, in titles: [ShelfTitle], sources: [IntentSource]) -> Result<
        ShelfTitle, IntentFailure
    > {
        guard let source = sources.first(where: { $0.id == reference.sourceID }) else { return .failure(.titleSourceGone) }
        if let title = titles.first(where: reference.matches) { return .success(title) }
        return .failure(missing(source) ?? .titleGone(title: nil, source: source.name))
    }

    /// Why a source that does not hold the item may yet: nil once it loaded.
    private static func missing(_ source: IntentSource) -> IntentFailure? {
        switch source.state {
        case .loaded: nil
        case .loading: .stillLoading
        case .offline: .offline
        case .failed: .sourceFailed(source: source.name)
        case .waitingForLogin: .loginMissing(source: source.name)
        }
    }

    /// Favorites in their order, then All channels, each once, at most
    /// `limit`. Locked channels and channels of hidden groups are left out.
    public static func suggestedChannels<Token>(in catalogue: Catalogue<Token>, limit: Int = channelSuggestions) -> [RowKey] {
        let all = catalogue.rows(in: .all)
        let listed = Set(all)
        var seen: Set<RowKey> = []
        var rows: [RowKey] = []
        for row in catalogue.rows(in: .favorites) + all where listed.contains(row) && !catalogue.isLocked(row) {
            guard rows.count < limit else { break }
            if seen.insert(row).inserted { rows.append(row) }
        }
        return rows
    }

    /// Titles in progress, most recent first, then My list in its order,
    /// each once and only when loaded, at most `limit`.
    public static func suggestedTitles(
        progress: [WatchProgress], myList: [ActivityKey], titles: [ShelfTitle], limit: Int = titleSuggestions
    ) -> [ShelfTitle] {
        let loaded = Dictionary(titles.map { ($0.activityKey, $0) }, uniquingKeysWith: { first, _ in first })
        var seen: Set<ActivityKey> = []
        var result: [ShelfTitle] = []
        let inProgress = ContinueWatching.items(progress: progress, titles: titles).map(\.title.activityKey)
        for key in inProgress + myList {
            guard result.count < limit else { break }
            if let title = loaded[key], seen.insert(key).inserted { result.append(title) }
        }
        return result
    }
}
