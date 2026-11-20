import Foundation

/// Tells adult groups and categories from the rest by name
/// (adult-content/adult-groups-are-found-by-name).
///
/// A name counts as adult when one of its words is an adult word, or it
/// holds an adult phrase such as "18+", and no harmless phrase such as
/// "Adult Swim" covers that word. Case and accents are ignored, so
/// "ADULTOS", "Erótico" and "erotico" all match. Only whole words count:
/// "Adulthood" and "XXL" do not.
public enum AdultContent {
    /// Words that mark a name as adult on their own.
    static let words: Set<String> = [
        "xxx", "porn", "porno", "pornos", "pornography", "hentai",
        "erotic", "erotica", "erotik", "erotique", "erotico", "eroticos", "eroticas", "erotiek",
        "adult", "adults", "adulte", "adultes", "adulto", "adultos", "adulta", "adultas",
        "vuxen", "vuxna", "vuxenfilm",
        "erwachsene", "erwachsenen",
        "voksen", "voksne",
        "18plus",
        "للبالغين", "بالغين", "للكبار",
    ]

    /// Phrases that mark a name as adult, as words.
    static let phrases: [[String]] = [["18", "+"], ["+", "18"]]

    /// Phrases whose adult word does not mean adult content: a channel
    /// brand, a book or music genre, a kind of course. A name made only of
    /// these is not adult; another adult word beside them still counts.
    static let harmless: [[String]] = [
        ["adult", "swim"], ["young", "adult"], ["young", "adults"], ["new", "adult"], ["adult", "contemporary"],
        ["adult", "education"], ["adult", "animation"], ["adult", "learning"], ["adult", "alternative"],
        ["junge", "erwachsene"], ["unga", "vuxna"], ["jovenes", "adultos"], ["jeunes", "adultes"], ["jovens", "adultos"],
    ]

    /// True when `name` names an adult group or category.
    public static func isAdultName(_ name: String) -> Bool {
        let tokens = tokens(of: name)
        guard !tokens.isEmpty else { return false }
        var covered = [Bool](repeating: false, count: tokens.count)
        for phrase in harmless {
            for start in occurrences(of: phrase, in: tokens) {
                for offset in phrase.indices { covered[start + offset] = true }
            }
        }
        for (place, token) in tokens.enumerated() where !covered[place] && words.contains(token) {
            return true
        }
        return phrases.contains { phrase in !occurrences(of: phrase, in: tokens).isEmpty }
    }

    /// True for a parental rating that means adult content only: XXX and
    /// AO (Adults Only). NC-17, R18 and FSK 18 also cover violent films
    /// that are not adult content, so they do not count.
    public static func isAdultRating(_ rating: String?) -> Bool {
        guard let rating else { return false }
        let folded = ChannelFilter.fold(rating).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ["xxx", "ao", "us-ao"].contains(folded)
    }

    /// The name folded and split into words. Runs of letters and digits
    /// are words and each "+" is a word of its own, so "(18+)" reads as
    /// "18", "+" and "XXX-Adult" as "xxx", "adult".
    static func tokens(of name: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in ChannelFilter.fold(name).lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
                continue
            }
            if !current.isEmpty { tokens.append(current) }
            current = ""
            if character == "+" { tokens.append("+") }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func occurrences(of phrase: [String], in tokens: [String]) -> [Int] {
        guard phrase.count <= tokens.count else { return [] }
        return (0...(tokens.count - phrase.count)).filter { start in
            phrase.indices.allSatisfy { tokens[start + $0] == phrase[$0] }
        }
    }
}
