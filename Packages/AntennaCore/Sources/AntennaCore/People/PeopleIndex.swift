import Foundation

/// Everyone the loaded titles name, from the list rows and from the info
/// answers the app already received
/// (browse-by-person/a-person-s-page-never-asks-the-provider).
///
/// Built in two parts, so a new info answer does not walk every title: the
/// names in the list rows (`Rows`), built once each time the titles change,
/// and the learned names on top, built from at most `LearnedCredits.limit`
/// answers. Credits point at titles by position, so the index holds no
/// copies of them.
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

    /// The names the list rows of the loaded titles carry. Build it once
    /// each time the titles change, off the main actor with `build`.
    public struct Rows: Sendable {
        let libraries: [ShelfIndex]
        /// Where each library's titles start in the positions credits use.
        let offsets: [Int]
        let people: [String: Named]
        /// By position: true when the title's row names nobody.
        let unnamed: [Bool]
        let unnamedCount: Int

        public static let empty = Rows(libraries: [], isCancelled: { false }) ?? Rows()

        private init() {
            libraries = []
            offsets = []
            people = [:]
            unnamed = []
            unnamedCount = 0
        }

        /// The row names of every title in `libraries`, in order; nil when
        /// `isCancelled` turns true partway.
        init?(libraries: [ShelfIndex], isCancelled: () -> Bool) {
            var people: [String: Named] = [:]
            var unnamed: [Bool] = []
            var offsets: [Int] = []
            var unnamedCount = 0
            var parsed = PersonName.Cache()
            var position = 0
            for library in libraries {
                offsets.append(position)
                unnamed.reserveCapacity(unnamed.count + library.titles.count)
                for title in library.titles {
                    if position & 1023 == 0, isCancelled() { return nil }
                    let cast = PersonName.split(title.cast, cache: &parsed)
                    let directors = PersonName.split(title.director, cache: &parsed)
                    let none = cast.isEmpty && directors.isEmpty
                    unnamed.append(none)
                    if none { unnamedCount += 1 }
                    for name in cast { people.add(name, Ref(position: position, role: .cast)) }
                    for name in directors { people.add(name, Ref(position: position, role: .director)) }
                    position += 1
                }
            }
            self.libraries = libraries
            self.offsets = offsets
            self.people = people
            self.unnamed = unnamed
            self.unnamedCount = unnamedCount
        }

        /// The row names of `libraries`, Movies then Series, built away from
        /// the caller's actor. Nil when the calling task is cancelled first.
        @concurrent
        public static func build(_ libraries: [ShelfIndex]) async -> Rows? {
            Rows(libraries: libraries, isCancelled: { Task.isCancelled })
        }

        func title(at position: Int) -> ShelfTitle {
            var library = offsets.count - 1
            while offsets[library] > position { library -= 1 }
            return libraries[library].titles[position - offsets[library]]
        }

        func position(of key: ActivityKey) -> Int? {
            for (library, offset) in zip(libraries, offsets) {
                if let position = library.position(key) { return offset + position }
            }
            return nil
        }
    }

    /// A name and the titles that carry it, by position.
    struct Named: Sendable {
        var name: String
        var refs: [Ref]
    }

    /// A title's position and the role, in one number that sorts in source
    /// order with the cast before the directors.
    struct Ref: Sendable, Hashable, Comparable {
        let raw: UInt32

        init(position: Int, role: CastChip.Role) {
            raw = UInt32(truncatingIfNeeded: position) << 1 | (role == .director ? 1 : 0)
        }

        var position: Int { Int(raw >> 1) }
        var role: CastChip.Role { raw & 1 == 1 ? .director : .cast }

        static func < (lhs: Ref, rhs: Ref) -> Bool { lhs.raw < rhs.raw }
    }

    private let rows: Rows
    /// Names from info answers for loaded titles, refs in source order.
    private let learnedPeople: [String: Named]
    /// Positions whose cast, or whose directors, an info answer replaced.
    private let castReplaced: Set<Int>
    private let directorsReplaced: Set<Int>
    /// Info answers' years by position.
    private let years: [Int: Int]
    /// True when a loaded title has no names known yet: its row had none
    /// and no info answer has arrived for it.
    public let hasUnknownTitles: Bool

    public static let empty = PeopleIndex(rows: .empty, learned: LearnedCredits())

    /// The row names in `rows` with the names info answers sent on top. An
    /// answer's cast replaces the row's cast, and its directors the row's
    /// directors, when it has any.
    public init(rows: Rows, learned: LearnedCredits) {
        var people: [String: Named] = [:]
        var castReplaced: Set<Int> = []
        var directorsReplaced: Set<Int> = []
        var years: [Int: Int] = [:]
        var covered = 0
        for entry in learned.all {
            guard let position = rows.position(of: entry.key) else { continue }
            if rows.unnamed[position] { covered += 1 }
            if let year = entry.year { years[position] = year }
            if !entry.credits.cast.isEmpty {
                castReplaced.insert(position)
                for name in entry.credits.cast { people.add(name, Ref(position: position, role: .cast)) }
            }
            if !entry.credits.directors.isEmpty {
                directorsReplaced.insert(position)
                for name in entry.credits.directors { people.add(name, Ref(position: position, role: .director)) }
            }
        }
        for key in people.keys { people[key]?.refs.sort() }
        // The spelling of the earliest title, as the rows keep it.
        for (key, named) in people {
            guard let first = named.refs.first else { continue }
            let entry = learned.entry(rows.title(at: first.position).activityKey)
            let names = first.role == .cast ? entry?.credits.cast : entry?.credits.directors
            if let spelled = names?.first(where: { $0.key == key }) { people[key]?.name = spelled.display }
        }
        self.rows = rows
        learnedPeople = people
        self.castReplaced = castReplaced
        self.directorsReplaced = directorsReplaced
        self.years = years
        hasUnknownTitles = rows.unnamedCount > covered
    }

    /// `titles` in source order, movies and series together. For tests and
    /// small lists; the app builds `Rows` once and reuses them.
    public init(titles: [ShelfTitle], learned: LearnedCredits) {
        self.init(rows: Rows(libraries: [ShelfIndex(lookingUp: titles)], isCancelled: { false }) ?? .empty, learned: learned)
    }

    /// Puts the learned names on top of `rows` away from the caller's actor.
    @concurrent
    public static func build(rows: Rows, learned: LearnedCredits) async -> PeopleIndex {
        PeopleIndex(rows: rows, learned: learned)
    }

    /// The person with this key, nil when no loaded title names them.
    public func person(_ key: String) -> Person? {
        guard let (name, refs) = refs(of: key) else { return nil }
        return Person(key: key, name: name, credits: refs.map(credit))
    }

    /// The page for `name`; with no loaded title naming them, the empty page.
    public func page(_ name: PersonName) -> PersonPage {
        guard let person = person(name.key) else { return PersonPage(name: name.display, credits: [], showsNote: false) }
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
        func matches(_ key: String) -> Bool {
            let words = key.split(separator: " ")
            return typed.allSatisfy { part in words.contains { $0.hasPrefix(part) } }
        }
        var keys = rows.people.keys.filter(matches)
        keys += learnedPeople.keys.filter { rows.people[$0] == nil && matches($0) }
        let counted = keys.compactMap { key -> (String, Int)? in
            guard let (_, refs) = refs(of: key) else { return nil }
            return (key, Set(refs.map(\.position)).count)
        }
        return
            counted
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .prefix(Self.searchLimit)
            .compactMap { person($0.0) }
    }

    /// The person's spelling and titles in source order: the row's, less
    /// those an answer replaced, and the answers'.
    private func refs(of key: String) -> (String, [Ref])? {
        let row = rows.people[key]
        let kept =
            row?.refs.filter { ref in
                !(ref.role == .cast ? castReplaced : directorsReplaced).contains(ref.position)
            } ?? []
        guard let learned = learnedPeople[key], !learned.refs.isEmpty else {
            guard let row, !kept.isEmpty else { return nil }
            return (row.name, kept)
        }
        guard let row, let firstKept = kept.first else { return (learned.name, learned.refs) }
        let merged = (kept + learned.refs).sorted()
        return (firstKept < learned.refs[0] ? row.name : learned.name, merged)
    }

    private func credit(_ ref: Ref) -> Credit {
        Credit(title: rows.title(at: ref.position), role: ref.role, year: years[ref.position])
    }
}

extension [String: PeopleIndex.Named] {
    /// Adds a title to the name's list; the first spelling stays.
    fileprivate mutating func add(_ name: PersonName, _ ref: PeopleIndex.Ref) {
        self[name.key, default: PeopleIndex.Named(name: name.display, refs: [])].refs.append(ref)
    }
}
