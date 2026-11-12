import Foundation

/// One loaded channel as Search sees it.
public struct SearchChannel: Sendable, Hashable {
    public var key: RowKey
    public var name: String
    public var group: String?
    /// The number the catalogue shows for it.
    public var number: Int?
    /// The part after the dot of the provider's number, such as the 1 of 6.1.
    public var minorNumber: Int?
    /// Its source's place in the source list, the last tie-break.
    public var sourceOrder: Int
    /// Where its programmes are, nil without a guide id.
    public var guideKey: GuideKey?
    /// The provider offers catch-up on it.
    public var hasCatchup: Bool

    public init(
        key: RowKey, name: String, group: String? = nil, number: Int? = nil, sourceOrder: Int = 0, guideKey: GuideKey? = nil,
        hasCatchup: Bool = false
    ) {
        self.key = key
        self.name = name
        self.group = group
        self.number = number
        self.sourceOrder = sourceOrder
        self.guideKey = guideKey
        self.hasCatchup = hasCatchup
    }

    /// Every channel of `catalogue` in All channels order, numbered as the
    /// catalogue numbers them. `sourceOrder` gives each source's place;
    /// a source missing from it sorts last. Channels of hidden groups are
    /// included only with `includingHidden`, and locked channels never while
    /// the locks are closed (group-management/hide-groups-you-never-watch).
    /// `guideKeyOf` gives each channel's guide key, `GuideIndex.key(for:)`
    /// in the app.
    public static func all<Token>(
        in catalogue: Catalogue<Token>, sourceOrder: [UUID: Int] = [:], includingHidden: Bool = false,
        guideKeyOf: (Channel) -> GuideKey? = { GuideKey(channel: $0) }
    ) -> [SearchChannel] {
        catalogue.searchRows(includingHidden: includingHidden).compactMap { key -> SearchChannel? in
            guard let channel = catalogue.channel(for: key) else { return nil }
            var found = SearchChannel(
                key: key, name: channel.name, group: channel.group, number: catalogue.number(for: key),
                sourceOrder: sourceOrder[key.sourceID] ?? .max, guideKey: guideKeyOf(channel), hasCatchup: channel.hasCatchup)
            found.minorNumber = catalogue.channelNumber(for: key)?.minor
            return found
        }
    }
}

/// The kinds of result, in section order, and the chips that narrow to one
/// (search/narrow-to-one-kind).
public enum SearchScope: Sendable, Hashable, CaseIterable {
    case all, channels, guide, movies, series
}

/// What a search found, every match of each kind, best first
/// (search/results-grouped-best-first).
public struct SearchResults: Sendable, Equatable {
    /// How many channels a section lists before "Showing n of total"
    /// (search/very-long-result-lists).
    public static let channelCap = 500
    /// How many programmes In the guide lists in the All view before "See all".
    public static let guidePreview = 4

    public struct ChannelHit: Sendable, Hashable, Identifiable {
        /// What made the channel a result.
        public enum Match: Sendable, Hashable {
            case name
            case number
            /// Only its group matched; the row says "Matches <group>".
            case group
        }

        public var channel: SearchChannel
        public var match: Match
        public var id: RowKey { channel.key }
    }

    public struct ProgrammeHit: Sendable, Hashable, Identifiable {
        /// The programme's guide key and start, never a stream link.
        public struct Identity: Sendable, Hashable {
            public var guideKey: GuideKey
            public var start: Date

            public init(guideKey: GuideKey, start: Date) {
                self.guideKey = guideKey
                self.start = start
            }
        }

        public var programme: Programme
        /// The channel it is on: of the channels sharing its guide, the
        /// lowest number.
        public var channel: SearchChannel
        /// On at the time of the search.
        public var isOnNow: Bool
        /// The provider offers catch-up on its channel.
        public var hasCatchup: Bool { channel.hasCatchup }
        public var id: Identity
    }

    /// The programmes a search found, in order. Each is built when read,
    /// so a query that finds a hundred thousand builds only those shown.
    public struct Programmes: RandomAccessCollection, Sendable, Equatable {
        let store: ProgrammeStore
        let offsets: [Int32]
        let now: Date

        public var startIndex: Int { 0 }
        public var endIndex: Int { offsets.count }

        public subscript(position: Int) -> ProgrammeHit {
            store.hit(offsets[position], now: now)
        }

        public static func == (lhs: Programmes, rhs: Programmes) -> Bool {
            lhs.store === rhs.store && lhs.offsets == rhs.offsets && lhs.now == rhs.now
        }

        static let empty = Programmes(store: .empty, offsets: [], now: .distantPast)
    }

    public struct TitleHit: Sendable, Hashable, Identifiable {
        public var title: ShelfTitle
        public var id: String { title.id }
    }

    public var query: SearchQuery
    public var channels: [ChannelHit]
    public var programmes: Programmes
    public var titles: [TitleHit]

    init(query: SearchQuery, channels: [ChannelHit] = [], programmes: Programmes = .empty, titles: [TitleHit] = []) {
        self.query = query
        self.channels = channels
        self.programmes = programmes
        self.titles = titles
    }

    /// The results of `query` before anything is searched.
    public static func none(_ query: SearchQuery) -> SearchResults {
        SearchResults(query: query)
    }

    public var isEmpty: Bool { channels.isEmpty && programmes.isEmpty && titles.isEmpty }

    /// The count on a chip: every match of that kind; All is the total.
    public func count(_ scope: SearchScope) -> Int {
        switch scope {
        case .all: channels.count + programmes.count + titles.count
        case .channels: channels.count
        case .guide: programmes.count
        case .movies: titles.count { $0.title.kind == .movie }
        case .series: titles.count { $0.title.kind == .series }
        }
    }

    /// The channel rows a section lists, at most `channelCap`.
    public var shownChannels: ArraySlice<ChannelHit> {
        channels.prefix(Self.channelCap)
    }

    /// True when the Channels section ends with "Showing n of total".
    public var isChannelListCapped: Bool { channels.count > Self.channelCap }

    /// The programmes In the guide lists: the first `guidePreview` in the
    /// All view until the user asks for all of them, every one otherwise.
    public func shownProgrammes(_ scope: SearchScope, expanded: Bool) -> Range<Int> {
        scope == .all && !expanded ? 0..<min(programmes.count, Self.guidePreview) : programmes.indices
    }

    /// The movies and series a scope lists.
    public func shownTitles(_ scope: SearchScope) -> [TitleHit] {
        switch scope {
        case .movies: titles.filter { $0.title.kind == .movie }
        case .series: titles.filter { $0.title.kind == .series }
        case .all, .channels, .guide: titles
        }
    }
}
