import Foundation
import Testing

@testable import AntennaCore

/// Core's own catalog: the sentences, plural forms, isolates and built-in
/// names every text helper builds through `Words`.
@Suite struct LocalizationTests {
    let english = Locale(identifier: "en_US")

    @Test("localization/counts-use-the-language-s-plural-forms one channel and two channels")
    func englishPlurals() {
        let text = SetupText(locale: english)
        #expect(text.liveChannels(1) == "1 live channel")
        #expect(text.liveChannels(2) == "2 live channels")
        #expect(text.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 live channel in 1 group")
        #expect(SourceStatusText(locale: english).count(1) == "1 channel")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a count groups in the locale's way")
    func grouping() {
        #expect(SetupText(locale: Locale(identifier: "de_DE")).liveChannels(12_500) == "12.500 Live-Sender")
        #expect(SetupText(locale: english).liveChannels(12_500) == "12,500 live channels")
    }

    @Test("localization/no-screen-shows-a-key-or-a-blank-label a language without a table falls back to English")
    func fallback() {
        let japanese = Locale(identifier: "ja_JP")
        #expect(Words(japanese)("Guide unavailable") == "Guide unavailable")
        #expect(ZapBarText.guideUnavailable(japanese) == "Guide unavailable")
    }

    @Test("localization/built-in-names-follow-the-language built-in groups take their name from the catalog")
    func builtInNames() {
        #expect(CatalogueGroup.favorites.label(english) == "Favorites")
        #expect(CatalogueGroup.all.label(english) == "All channels")
        #expect(CatalogueGroup.ungrouped(UUID()).label(english) == "Ungrouped")
        #expect(CatalogueGroup.named(UUID(), "Nyheter").label(english) == "Nyheter")
    }

    @Test("localization/mixed-scripts-keep-their-own-direction source text is isolated where directions mix")
    func isolates() {
        let arabic = Words(Locale(identifier: "ar_SA"))
        #expect(arabic.source("Champions League Live") == "\u{2068}Champions League Live\u{2069}")
        #expect(Words(english).source("الجزيرة") == "\u{2068}الجزيرة\u{2069}")
        #expect(Words(english).source("Sport One") == "Sport One")
        #expect("\u{2068}Sport\u{2069}".withoutIsolates == "Sport")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a channel number never groups and uses the region's digits")
    func channelNumbers() {
        #expect(ChannelNumber(major: 1001).text(english) == "1001")
        #expect(ChannelNumber(major: 6, minor: 1).text(english) == "6.1")
        #expect(ChannelNumber(major: 105).text(Locale(identifier: "ar_SA")) == "١٠٥")
        #expect(ChannelNumber.digit("٥") == "5")
        #expect(ChannelNumber.digit("x") == nil)
        #expect(ChannelNumber.digits("007", locale: Locale(identifier: "ar_SA")) == "٠٠٧")
    }

    @Test("localization/times-and-dates-follow-the-user-s-region a 24-hour region and a forced 12-hour clock")
    func clock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let nine = Date(timeIntervalSince1970: 1_799_971_200 + 21 * 3_600)
        #expect(SearchText(calendar: calendar, locale: Locale(identifier: "sv_SE")).time(nine) == "21:00")
        let german12 = SearchText(calendar: calendar, locale: Locale(identifier: "de_DE@hours=h12")).time(nine)
        #expect(german12.hasPrefix("9:00"), "\(german12)")
        #expect(ReminderText(calendar: calendar, locale: Locale(identifier: "sv_SE")).time(nine) == "21:00")
        #expect(SearchText(calendar: calendar, locale: english).time(nine) == "9:00\u{202F}PM")
    }

    @Test("localization/source-text-is-shown-as-it-arrives a channel and a group keep the source's words in Swedish")
    func sourceText() {
        let swedish = Locale(identifier: "sv_SE")
        #expect(Words(swedish).source("Sky Sports News") == "Sky Sports News")
        #expect(CatalogueGroup.named(UUID(), "Sky Sports News").label(swedish) == "Sky Sports News")
        #expect(CatalogueGroup.named(UUID(), "أخبار").label(english) == "أخبار")
    }

    @Test("localization/system-prompts-and-siri-speak-the-language the Top Shelf titles are in Swedish")
    func topShelfInSwedish() {
        let swedish = Locale(identifier: "sv_SE")
        #expect(TopShelfContent.Section(kind: .continueWatching, items: []).title(swedish) == "Fortsätt titta")
        #expect(TopShelfContent.emptyTitle(swedish) == "Lägg till favoriter i Antenna för att se dem här")
    }
}

/// The app's catalogs, the translation check and the release phase that
/// drops languages no one has reviewed, run on the repo and on copies.
@Suite struct LocalizationReleaseTests {
    static let root = WebsiteTests.root

    private static func languages() throws -> [String] {
        try String(contentsOf: root.appending(path: "Config/languages"), encoding: .utf8)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != "en" }
    }

    private static func localizations(_ catalog: String, _ key: String) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appending(path: catalog))
        let strings = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["strings"] as? [String: Any]
        return (strings?[key] as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
    }

    @Test("localization/system-prompts-and-siri-speak-the-language the local network reason is in every language")
    func localNetworkReason() throws {
        let found = try Self.localizations("Apps/Shared/InfoPlist.xcstrings", "NSLocalNetworkUsageDescription")
        for language in try Self.languages() {
            let unit = (found[language] as? [String: Any])?["stringUnit"] as? [String: Any]
            #expect(unit?["state"] as? String == "translated", "\(language)")
        }
    }

    @Test("localization/system-prompts-and-siri-speak-the-language every Siri phrase is in every language")
    func siriPhrases() throws {
        let data = try Data(contentsOf: Self.root.appending(path: "Apps/Shared/Intents/AppShortcuts.xcstrings"))
        let strings = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["strings"] as? [String: Any])
        #expect(!strings.isEmpty)
        for key in strings.keys {
            let found = try Self.localizations("Apps/Shared/Intents/AppShortcuts.xcstrings", key)
            for language in try Self.languages() {
                let set = (found[language] as? [String: Any])?["stringSet"] as? [String: Any]
                #expect(set?["state"] as? String == "translated", "\(key) in \(language)")
            }
        }
    }

    #if os(macOS)
        private func run(_ arguments: [String], environment: [String: String] = [:]) throws -> (status: Int32, output: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
            process.currentDirectoryURL = Self.root
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }

        private func temporaryFolder(_ name: String) throws -> URL {
            let folder = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        @Test("localization/every-language-is-complete-before-release the repo's catalogs pass the check")
        func repoCatalogsPass() throws {
            let result = try run(["python3", "scripts/translations.py", "check"])
            #expect(result.status == 0, "\(result.output)")
        }

        @Test("localization/every-language-is-complete-before-release a label in English only fails and is named")
        func englishOnlyLabelFails() throws {
            // The check names catalogs by their path in the repo, so the copy sits there.
            let folder = Self.root.appending(path: ".build/catalog-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let catalog = folder.appending(path: "Localizable.xcstrings")
            let text = """
                {"sourceLanguage": "en", "version": "1.0", "strings": {"Record": {"localizations": {
                "en": {"stringUnit": {"state": "translated", "value": "Record"}}}}}}
                """
            try text.write(to: catalog, atomically: true, encoding: .utf8)
            let result = try run(["python3", "scripts/translations.py", "check", catalog.path], environment: ["LANGUAGES": "en ar"])
            #expect(result.status != 0)
            #expect(result.output.contains("'Record' [ar]: no translation"), "\(result.output)")
        }

        @Test("localization/every-language-is-complete-before-release a release drops a language no one has reviewed")
        func releaseDropsUnreviewed() throws {
            let product = try temporaryFolder("Antenna.app")
            defer { try? FileManager.default.removeItem(at: product) }
            for code in ["en", "Base", "ar", "xx"] {
                try FileManager.default.createDirectory(at: product.appending(path: "\(code).lproj"), withIntermediateDirectories: true)
            }
            let result = try run(["bash", "scripts/strip-unreviewed-languages.sh", product.path])
            #expect(result.status == 0, "\(result.output)")
            let left = try FileManager.default.contentsOfDirectory(atPath: product.path).sorted()
            #expect(left == ["Base.lproj", "ar.lproj", "en.lproj"])
        }
    #endif
}
