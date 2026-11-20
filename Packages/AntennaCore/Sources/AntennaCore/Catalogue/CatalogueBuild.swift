import Foundation

/// What a channel list's catalogue is built from. Indexing 50 000 channels
/// and folding their names holds a main-actor caller long enough to drop
/// frames, so both builds run away from the caller's actor.
public struct CatalogueInputs<Token: Hashable & Sendable>: Sendable {
    public var channels: [Channel]
    public var favorites: [FavoriteSnapshot<Token>]
    public var recents: [LastChannelKey]
    public var rules: GroupRules
    public var seen: [UUID: SeenChannels]
    public var now: Date

    public init(
        channels: [Channel], favorites: [FavoriteSnapshot<Token>], recents: [LastChannelKey], rules: GroupRules,
        seen: [UUID: SeenChannels], now: Date
    ) {
        self.channels = channels
        self.favorites = favorites
        self.recents = recents
        self.rules = rules
        self.seen = seen
        self.now = now
    }

    /// `NewChannels.group(_:seen:now:)` on `Catalogue(channels:groupOrder:favorites:recents:rules:)`.
    @concurrent
    public func catalogue() async -> Catalogue<Token> {
        grouped()
    }

    /// The same catalogue with the name index its lists filter through.
    @concurrent
    public func indexed() async -> BuiltCatalogue<Token> {
        let catalogue = grouped()
        return BuiltCatalogue(catalogue: catalogue, names: ChannelNameIndex(catalogue))
    }

    private func grouped() -> Catalogue<Token> {
        let built = Catalogue(channels: channels, groupOrder: [:], favorites: favorites, recents: recents, rules: rules)
        return NewChannels.group(built, seen: seen, now: now)
    }
}

/// A catalogue with its New group and the name index its lists filter through.
public struct BuiltCatalogue<Token: Hashable & Sendable>: Sendable {
    public let catalogue: Catalogue<Token>
    public let names: ChannelNameIndex

    public init(catalogue: Catalogue<Token>, names: ChannelNameIndex) {
        self.catalogue = catalogue
        self.names = names
    }
}
