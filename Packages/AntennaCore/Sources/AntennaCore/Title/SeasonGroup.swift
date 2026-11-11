import Foundation

/// One entry of a series' season picker and the episodes it shows
/// (title-detail-and-episode-picker/pick-a-season).
public struct SeasonGroup: Sendable, Hashable, Identifiable {
    /// What the group holds. Groups sort seasons first by number, then
    /// specials, then other.
    public enum Kind: Sendable, Hashable, Comparable {
        /// Season 1 and up.
        case season(Int)
        /// Season 0.
        case specials
        /// Episodes with no season, or a negative one.
        case other
    }

    public var kind: Kind
    /// In the order the Xtream client gives them.
    public var episodes: [Episode]

    public init(kind: Kind, episodes: [Episode]) {
        self.kind = kind
        self.episodes = episodes
    }

    /// Stable within a series: "season-3", "specials" or "other".
    public var id: String {
        switch kind {
        case .season(let number): "season-\(number)"
        case .specials: "specials"
        case .other: "other"
        }
    }

    /// "Season 3", "Specials" or "Other".
    public var title: String {
        switch kind {
        case .season(let number): "Season \(number)"
        case .specials: "Specials"
        case .other: "Other"
        }
    }

    /// "1 episode" or "8 episodes".
    public var countLabel: String {
        episodes.count == 1 ? "1 episode" : "\(episodes.count) episodes"
    }

    /// Groups episodes into Season 1 to n, Specials for season 0 and Other
    /// for none, in that order. Empty groups are left out, and each group
    /// keeps the episodes in the order given.
    public static func group(_ episodes: [Episode]) -> [SeasonGroup] {
        var seasons: [Int: [Episode]] = [:]
        var specials: [Episode] = []
        var other: [Episode] = []
        for episode in episodes {
            switch episode.season {
            case let season? where season > 0: seasons[season, default: []].append(episode)
            case 0: specials.append(episode)
            default: other.append(episode)
            }
        }
        var groups = seasons.keys.sorted().map { SeasonGroup(kind: .season($0), episodes: seasons[$0] ?? []) }
        if !specials.isEmpty { groups.append(SeasonGroup(kind: .specials, episodes: specials)) }
        if !other.isEmpty { groups.append(SeasonGroup(kind: .other, episodes: other)) }
        return groups
    }

    /// The number of numbered seasons, what the details line counts
    /// (title-detail-and-episode-picker/what-the-title-is-about).
    public static func seasonCount(_ groups: [SeasonGroup]) -> Int {
        groups.count { if case .season = $0.kind { true } else { false } }
    }
}
