import Foundation

/// Everyone the loaded titles name, from the list rows and from the info
/// answers the app already received
/// (browse-by-person/a-person-s-page-never-asks-the-provider). Built once
/// each time the titles or the learned names change.
public struct PeopleIndex: Sendable {
    /// One title that names a person, and as what.
    public struct Credit: Sendable, Hashable {
        public var title: ShelfTitle
        public var role: CastChip.Role
        /// The info answer's year; nil leaves the page to read the name's.
        public var year: Int?
    }

    /// A person and every loaded title that names them, in source order.
    public struct Person: Sendable, Hashable, Identifiable {
        public var key: String
        /// The spelling of the first title in source order that names them.
        public var name: String
        public var credits: [Credit]
        public var id: String { key }

        /// Titles naming them in any role, each counted once.
        public var titleCount: Int {
            Set(credits.map(\.title.activityKey)).count
        }

        /// Their page, for Search's count line.
        public var page: PersonPage {
            PersonPage(name: name, credits: credits, showsNote: false)
        }
    }

    private let people: [String: Person]
    /// True when a loaded title has no names known yet: its row had none
    /// and no info answer has arrived for it.
    public let hasUnknownTitles: Bool

    public static let empty = PeopleIndex(titles: [], learned: LearnedCredits())

    /// `titles` in source order, movies and series together.
    public init(titles: [ShelfTitle], learned: LearnedCredits) {
        var people: [String: Person] = [:]
        var unknown = false
        for title in titles {
            let entry = learned.entry(title.activityKey)
            let row = TitleCredits(cast: title.cast, director: title.director)
            let learnedCredits = entry?.credits ?? TitleCredits()
            let credits = TitleCredits(
                cast: learnedCredits.cast.isEmpty ? row.cast : learnedCredits.cast,
                directors: learnedCredits.directors.isEmpty ? row.directors : learnedCredits.directors)
            if entry == nil, row.isEmpty { unknown = true }
            guard !credits.isEmpty else { continue }
            let year = entry?.year
            func add(_ name: PersonName, _ role: CastChip.Role) {
                let credit = Credit(title: title, role: role, year: year)
                if people[name.key] == nil {
                    people[name.key] = Person(key: name.key, name: name.display, credits: [credit])
                } else {
                    people[name.key]?.credits.append(credit)
                }
            }
            for name in credits.cast { add(name, .cast) }
            for name in credits.directors { add(name, .director) }
        }
        self.people = people
        hasUnknownTitles = unknown
    }

    /// Builds the index away from the caller's actor.
    @concurrent
    public static func build(titles: [ShelfTitle], learned: LearnedCredits) async -> PeopleIndex {
        PeopleIndex(titles: titles, learned: learned)
    }

    public var count: Int { people.count }

    /// The person with this key, nil when no loaded title names them.
    public func person(_ key: String) -> Person? {
        people[key]
    }

    /// The page for `name`; with no loaded title naming them, the empty page.
    public func page(_ name: PersonName) -> PersonPage {
        guard let person = people[name.key] else { return PersonPage(name: name.display, credits: [], showsNote: false) }
        return PersonPage(name: person.name, credits: person.credits, showsNote: hasUnknownTitles)
    }

    /// How many people Search's People section lists.
    public static let searchLimit = 3

    /// Up to `searchLimit` people for whom every typed word starts a word
    /// of their name, most titles first, then by name
    /// (browse-by-person/find-a-person-in-search).
    public func search(_ query: SearchQuery) -> [Person] {
        let typed = query.text.split(separator: " ").map { PersonName.key(String($0)) }.filter { !$0.isEmpty }
        guard query.isSearchable, !typed.isEmpty else { return [] }
        let found = people.values.filter { person in
            let words = person.key.split(separator: " ")
            return typed.allSatisfy { part in words.contains { $0.hasPrefix(part) } }
        }
        let counted = found.map { ($0, $0.titleCount) }
        return
            counted
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.key < $1.0.key }
            .prefix(Self.searchLimit)
            .map(\.0)
    }
}
