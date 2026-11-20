import Foundation
import Testing

@testable import AntennaCore

/// The byte search behind the Live filter and Search answers as the string
/// comparison it replaced: same folding, same matches, for ASCII and for
/// scripts where a byte match is not enough.
@Suite struct FoldedTextTests {
    static let names = [
        "Sport HD", "BBC One", "Música Viva", "Café de Paris", "ÉCOLE", "Straße", "İstanbul TV", "ıstanbul", "Ölüdeniz",
        "قناة الجزيرة", "الجزيرة الإخبارية", "Первый канал", "РОССИЯ 1", "日本テレビ", "한국 방송", "한국방송", "한",
        "e\u{301}cole", "école", "Ελληνική Τηλεόραση", "🇸🇪 SVT1", "👨‍👩‍👧 Family", "fi ﬁlm", "Ｗｉｄｅ", "a\r\nb", "",
        "Kelvin \u{212A}", "ช่อง 3 HD", "हिन्दी समाचार", "Ꭰ", "A\u{308}\u{301}", "\u{301}lone mark",
    ]
    static let typed = [
        "s", "sp", "SPORT", "hd", "musica", "MÚSICA", "cafe", "ecole", "École", "strasse", "straße", "istanbul", "ı", "i",
        "الجزيرة", "جزي", "канал", "россия", "テレビ", "한국", "국", "ᄒ", "e", "\u{301}", "ελληνικη", "🇸🇪", "🇸", "👨", "fi", "ﬁ",
        "wide", "ｗｉｄｅ", "k", "\u{212A}", "ช่อง", "ช", "हिन्दी", "ि", "a", "ä", "lone", "\r",
    ]

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list
    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list ASCII folds as Foundation folds")
    func asciiFold() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<2_000 {
            let length = Int.random(in: 0...24, using: &generator)
            let text = String(decoding: (0..<length).map { _ in UInt8.random(in: 0...127, using: &generator) }, as: UTF8.self)
            let expected = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            #expect(Array(FoldedText.fold(text).utf8) == Array(expected.utf8), "\(Array(text.utf8))")
        }
    }

    // search/find-things-the-way-you-type-them
    @Test("search/find-things-the-way-you-type-them the byte search matches as the string comparison does")
    func sameMatches() {
        let folded = Self.names.map(ChannelFilter.fold)
        let texts = FoldedTexts(folded)
        for typed in Self.typed {
            let token = ChannelFilter.fold(typed)
            for (index, name) in folded.enumerated() {
                let expected = name.contains(token)
                #expect(texts.contains(index, all: [FoldedNeedle(token)]) == expected, "\(name) / \(typed)")
            }
        }
    }

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list
    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list the name index keeps the rows a name-by-name check keeps")
    func indexMatchesCheck() {
        let first = UUID()
        let second = UUID()
        let channels =
            Channel.tagged(
                Self.names.enumerated().map { index, name in
                    Channel(id: "a\(index)", name: name, streamURL: URL(filePath: "/a\(index)"), group: "G\(index % 3)", number: index * 7)
                }, sourceID: first)
            + Channel.tagged(
                Self.names.reversed().enumerated().map { index, name in
                    Channel(id: "b\(index)", name: name, streamURL: URL(filePath: "/b\(index)"), group: "H")
                }, sourceID: second)
        let catalogue = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: [])
        let index = ChannelNameIndex(catalogue)
        for group in catalogue.groups {
            let rows = catalogue.rows(in: group)
            for typed in Self.typed + ["sport hd", "7", "14", "007", "0", "1 a", "e 7"] {
                let filter = ChannelFilter(typed)
                let expected = rows.filter { key in
                    filter.matches(name: catalogue.channel(for: key)?.name ?? "", number: catalogue.number(for: key))
                }
                #expect(index.filter(rows, by: filter) == expected, "\(group) / \(typed)")
            }
        }
    }

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list
    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list typing on, deleting and switching groups keep the rows a fresh index gives")
    func keystrokes() {
        let words = ["Sport", "News", "Kids", "Film", "Música", "Arena", "قناة", "한국"]
        let channels = Channel.tagged(
            (0..<600).map { index in
                Channel(
                    id: "\(index)", name: "\(words[index % 8]) \(words[(index / 8) % 8]) \(index)", streamURL: URL(filePath: "/\(index)"),
                    group: "G\(index % 5)", number: index.isMultiple(of: 7) ? nil : index)
            }, sourceID: UUID())
        let catalogue = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: [])
        let index = ChannelNameIndex(catalogue)
        let typing = [
            "s", "sp", "spo", "sport", "sport ", "sport n", "sport ne", "sport n", "sport", "spor", "a", "ar", "are", "arena 1", "arena 12",
            "1", "12", "123", "12", "1", "0", "00", "001", "0012", "13 a", "مو", "قن", "قناة", "한", "한국", "musica", "música k",
        ]
        for group in catalogue.groups.prefix(4) + catalogue.groups.suffix(2) {
            let rows = catalogue.rows(in: group)
            for typed in typing {
                let expected = ChannelNameIndex(catalogue).filter(rows, by: ChannelFilter(typed))
                #expect(index.filter(rows, by: ChannelFilter(typed)) == expected, "\(group) / \(typed)")
            }
        }
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list a narrower filter is one whose matches the last one also had")
    func narrowing() {
        #expect(ChannelFilter("spor").narrows(ChannelFilter("spo")))
        #expect(ChannelFilter("sport news").narrows(ChannelFilter("sport n")))
        #expect(ChannelFilter("news sport").narrows(ChannelFilter("sport")))
        #expect(!ChannelFilter("spo").narrows(ChannelFilter("spor")))
        #expect(!ChannelFilter("sport").narrows(ChannelFilter("sport n")))
        #expect(ChannelFilter("123").narrows(ChannelFilter("12")))
        #expect(!ChannelFilter("001").narrows(ChannelFilter("00")), "00 has no digits to match a number by")
        #expect(ChannelFilter("12a").narrows(ChannelFilter("12")))
        #expect(!ChannelFilter("12").narrows(ChannelFilter("1a")))
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list rows from another catalogue are left out")
    func foreignRows() {
        let source = UUID()
        let one = Catalogue<Int>(
            channels: Channel.tagged([Channel(id: "a", name: "Arena", streamURL: URL(filePath: "/a"))], sourceID: source),
            groupOrder: [:], favorites: [])
        let other = Catalogue<Int>(
            channels: Channel.tagged(
                [
                    Channel(id: "b", name: "Arena", streamURL: URL(filePath: "/b")),
                    Channel(id: "c", name: "Arena", streamURL: URL(filePath: "/c")),
                ],
                sourceID: UUID()),
            groupOrder: [:], favorites: [])
        let index = ChannelNameIndex(one)
        let foreign = index.filter(other.rows(in: .all), by: ChannelFilter("arena"))
        #expect(foreign.isEmpty)
        #expect(index.filter(one.rows(in: .all), by: ChannelFilter("arena")) == one.rows(in: .all))
    }
}
