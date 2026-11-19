import Foundation

/// What a person's page shows (browse-by-person/a-person-s-page): the
/// name, the count line, and the Movies, Series and Directed rows, newest
/// first, each row empty when the person has no such titles.
public struct PersonPage: Sendable, Hashable {
    public enum Department: Sendable, Hashable {
        case acting, directing
    }

    /// As the provider wrote it. Never translated.
    public var name: String
    public var department: Department
    /// Titles in any row, each counted once.
    public var count: Int
    /// Movies they act in.
    public var movies: [ShelfTitle]
    /// Series they act in.
    public var series: [ShelfTitle]
    /// Movies and series they direct.
    public var directed: [ShelfTitle]
    /// True when some loaded titles have no names known yet, so the page
    /// may be missing some of theirs.
    public var showsNote: Bool

    init(name: String, credits: [PeopleIndex.Credit], showsNote: Bool) {
        self.name = name
        let ordered = Self.newestFirst(credits)
        movies = Self.unique(ordered.filter { $0.role == .cast && $0.title.kind == .movie })
        series = Self.unique(ordered.filter { $0.role == .cast && $0.title.kind == .series })
        directed = Self.unique(ordered.filter { $0.role == .director })
        count = Set(credits.map(\.title.activityKey)).count
        let directing = credits.count { $0.role == .director }
        department = directing > credits.count - directing ? .directing : .acting
        self.showsNote = showsNote
    }

    public var isEmpty: Bool { movies.isEmpty && series.isEmpty && directed.isEmpty }

    /// The circle's letters: the first and last word's first letters, "MH"
    /// for Mira Holt, one letter for a one-word name, "?" with no letter.
    public var initials: String {
        Self.initials(of: name)
    }

    /// The circle's letters for any name, with the rule of `initials`.
    public static func initials(of name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).compactMap { $0.first { $0.isLetter } }
        guard let first = words.first else { return "?" }
        let letters = words.count > 1 ? [first, words[words.count - 1]] : [first]
        return String(letters).uppercased()
    }

    /// "Acting · 9 in your sources" or "Directing · 1 in your sources".
    public func countLine(locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        switch department {
        case .acting: return words("Acting · \(count) in your sources")
        case .directing: return words("Directing · \(count) in your sources")
        }
    }

    /// "Nothing with Mira Holt in your sources."
    public func emptyLine(locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Nothing with \(words.source(name)) in your sources.")
    }

    /// Under the rows while some titles have no names known yet.
    public static func note(locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Only titles whose cast your provider has sent are here. More appear as you browse.")
    }

    /// By year newest first, the info answer's or else the name's, then by added date, undated last in source order.
    private static func newestFirst(_ credits: [PeopleIndex.Credit]) -> [PeopleIndex.Credit] {
        let credits = credits.map { credit in
            var dated = credit
            dated.year = credit.year ?? TitleName.clean(credit.title.name).year
            return dated
        }
        return credits.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element
                let right = rhs.element
                switch (left.year, right.year) {
                case (let newer?, let older?) where newer != older: return newer > older
                case (.some, nil): return true
                case (nil, .some): return false
                default: break
                }
                switch (left.title.added, right.title.added) {
                case (let newer?, let older?) where newer != older: return newer > older
                case (.some, nil): return true
                case (nil, .some): return false
                default: return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    /// Each title once, by source and id.
    private static func unique(_ credits: [PeopleIndex.Credit]) -> [ShelfTitle] {
        var seen: Set<ActivityKey> = []
        return credits.compactMap { seen.insert($0.title.activityKey).inserted ? $0.title : nil }
    }
}
