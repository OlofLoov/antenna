import Foundation

/// The show, season, episode number and title read from a playlist entry
/// name such as "The Show - S01E02 - The Visit"
/// (m3u-playlists/playlist-episodes-group-into-series).
public struct EpisodeName: Sendable, Hashable {
    /// The text before the marker, empty when the name starts with it.
    public var show: String
    public var season: Int
    public var number: Int
    /// The text after the marker, nil when there is none.
    public var title: String?

    static let separators = CharacterSet(charactersIn: " -–|:._(").union(.whitespaces)

    /// Nil for a name without a season and episode marker like "S01E02" or
    /// "s1 e12", the marker `PlaylistEntryKind` sorts episodes by.
    public init?(_ name: String) {
        let pattern = #"(?i)(?<![A-Za-z0-9])S(\d{1,2})\s?E(\d{1,3})(?![0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
            let whole = Range(match.range, in: name), let seasonRange = Range(match.range(at: 1), in: name),
            let numberRange = Range(match.range(at: 2), in: name), let season = Int(name[seasonRange]),
            let number = Int(name[numberRange])
        else { return nil }
        var show = String(name[..<whole.lowerBound]).trimmingCharacters(in: Self.separators)
        if !show.contains(" ") { show = show.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ") }
        let rest = name[whole.upperBound...].drop { $0 != "(" && $0.unicodeScalars.allSatisfy(Self.separators.contains) }
        let title = rest.trimmingCharacters(in: .whitespaces)
        self.show = show
        self.season = season
        self.number = number
        self.title = title.isEmpty ? nil : title
    }

    /// The show lowercased with every run of characters other than letters
    /// and digits as one space, so "The.Show" and "the show" give the same key.
    static func key(_ show: String) -> String {
        show.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }
}

/// A playlist's episodes grouped into series, for the Series section and
/// the title page (m3u-playlists/playlist-episodes-group-into-series).
/// Ids hold no link: a series id is built from its show and source, an
/// episode keeps its entry's id.
public struct PlaylistSeries: Sendable, Hashable {
    /// One title per show in first-seen order, with the groups as categories.
    public private(set) var catalogue: ShelfCatalogue
    private var infos: [String: SeriesInfo]

    /// Groups `episodes` by show. A name that starts with its marker takes
    /// its group as the show. An entry whose name has no marker forms a
    /// series named after the entry, with no season or number.
    public init(episodes: [Channel], sourceID: UUID) {
        var titles: [ShelfTitle] = []
        var indexByKey: [String: Int] = [:]
        var lists: [[Episode]] = []
        var categories: [String] = []
        var seenGroups = Set<String>()
        for entry in episodes {
            let parsed = EpisodeName(entry.name)
            let show = parsed.map { $0.show.isEmpty ? entry.group ?? entry.name : $0.show } ?? entry.name
            let key = EpisodeName.key(show).isEmpty ? show : EpisodeName.key(show)
            let index: Int
            if let known = indexByKey[key] {
                index = known
            } else {
                index = titles.count
                indexByKey[key] = index
                if let group = entry.group, seenGroups.insert(group).inserted { categories.append(group) }
                titles.append(
                    ShelfTitle(
                        id: Self.id(key: key, sourceID: sourceID), kind: .series, sourceID: sourceID, name: show, posterURL: entry.logoURL,
                        category: entry.group))
                lists.append([])
            }
            let fileExtension = entry.streamURL.pathExtension
            lists[index].append(
                Episode(
                    id: entry.id, episodeID: 0, season: parsed?.season, number: parsed?.number,
                    title: parsed?.title ?? parsed.map { "Episode \($0.number)" } ?? entry.name,
                    containerExtension: fileExtension.isEmpty ? nil : fileExtension, thumbnailURL: entry.logoURL))
        }
        catalogue = ShelfCatalogue(titles: titles, categories: categories)
        infos = Dictionary(uniqueKeysWithValues: zip(titles.map(\.id), lists.map { SeriesInfo(episodes: Self.ordered($0)) }))
    }

    /// The seasons and episodes of the series with this id, nil for an id it does not know.
    public func info(for seriesID: String) -> SeriesInfo? {
        infos[seriesID]
    }

    /// By season, then number, nil first, ties in playlist order.
    static func ordered(_ episodes: [Episode]) -> [Episode] {
        episodes.enumerated().sorted { lhs, rhs in
            let left = (lhs.element.season ?? -1, lhs.element.number ?? -1, lhs.offset)
            let right = (rhs.element.season ?? -1, rhs.element.number ?? -1, rhs.offset)
            return left < right
        }.map(\.element)
    }

    /// `m3u.series.` and 64-bit FNV-1a over the key and the source id as 16 lowercase hex digits.
    static func id(key: String, sourceID: UUID) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(key.utf8) + [0x1F] + Array(sourceID.uuidString.utf8) {
            value ^= UInt64(byte)
            value &*= 0x0000_0100_0000_01b3
        }
        let hex = String(value, radix: 16)
        return "m3u.series." + String(repeating: "0", count: 16 - hex.count) + hex
    }
}
