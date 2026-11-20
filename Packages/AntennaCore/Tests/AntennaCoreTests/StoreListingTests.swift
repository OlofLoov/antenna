import Foundation
import Testing

/// The App Store listing in `fastlane/metadata` and the check that guards
/// it, run on the repo and on broken copies in a temporary folder.
@Suite struct StoreListingTests {
    static let root = WebsiteTests.root

    #if os(macOS)
        /// A copy of the listing and the language files, to break on purpose.
        private struct Copy {
            let folder: URL

            init() throws {
                folder = FileManager.default.temporaryDirectory.appending(path: "store-\(UUID().uuidString)")
                let manager = FileManager.default
                try manager.createDirectory(at: folder.appending(path: "Config"), withIntermediateDirectories: true)
                try manager.createDirectory(at: folder.appending(path: "fastlane"), withIntermediateDirectories: true)
                for file in ["Config/languages", "Config/reviewed-languages"] {
                    try manager.copyItem(at: StoreListingTests.root.appending(path: file), to: folder.appending(path: file))
                }
                try manager.copyItem(
                    at: StoreListingTests.root.appending(path: "fastlane/metadata"), to: folder.appending(path: "fastlane/metadata"))
            }

            func read(_ path: String) throws -> String {
                try String(contentsOf: folder.appending(path: path), encoding: .utf8)
            }

            func write(_ path: String, _ text: String) throws {
                try text.write(to: folder.appending(path: path), atomically: true, encoding: .utf8)
            }

            func remove() { try? FileManager.default.removeItem(at: folder) }
        }

        private func run(_ arguments: [String], root: URL? = nil) throws -> (status: Int32, output: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            var all = ["python3", Self.root.appending(path: "scripts/store_metadata.py").path] + arguments
            if let root { all += ["--root", root.path] }
            process.arguments = all
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }

        @Test("store-listing/every-app-language-has-a-listing: the repo's listings pass the check")
        func repoPasses() throws {
            let result = try run(["check"])
            #expect(result.status == 0, "\(result.output)")
        }

        @Test("store-listing/every-app-language-has-a-listing: Spanish and French have two store locales each")
        func storeLocales() throws {
            let result = try run(["locales", "--all"])
            #expect(result.status == 0)
            #expect(result.output.contains("en en_US en-US\n"))
            #expect(result.output.contains("es es_MX es-ES,es-MX\n"))
            #expect(result.output.contains("fr fr_FR fr-FR,fr-CA\n"))
            let languages = try String(contentsOf: Self.root.appending(path: "Config/languages"), encoding: .utf8)
            for language in languages.split(separator: "\n") {
                #expect(result.output.contains("\(language) "), "\(language)")
            }
        }

        @Test("store-listing/every-app-language-has-a-listing: a new app language without a listing fails")
        func missingLanguage() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("Config/languages", try copy.read("Config/languages") + "it\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("it: no App Store locale"))
        }

        @Test("store-listing/every-app-language-has-a-listing: an empty field fails and is named")
        func emptyField() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("fastlane/metadata/de-DE/subtitle.txt", "\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("de-DE: subtitle.txt is empty"))
        }

        @Test("store-listing/the-listing-fits-app-store-connect: every field is within Apple's limit")
        func limits() throws {
            let limits = ["name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000, "release_notes": 4000]
            let metadata = Self.root.appending(path: "fastlane/metadata")
            let locales = try FileManager.default.contentsOfDirectory(atPath: metadata.path).filter { !$0.contains(".") }
            #expect(locales.count == 9)
            for locale in locales {
                for (field, limit) in limits {
                    let text = try String(contentsOf: metadata.appending(path: "\(locale)/\(field).txt"), encoding: .utf8)
                    let value = text.hasSuffix("\n") ? String(text.dropLast()) : text
                    #expect(!value.isEmpty && value.count <= limit, "\(locale) \(field) is \(value.count)")
                }
            }
        }

        @Test("store-listing/the-listing-fits-app-store-connect: a subtitle over 30 characters fails with its length")
        func longSubtitle() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("fastlane/metadata/fr-FR/subtitle.txt", String(repeating: "a", count: 31) + "\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("fr-FR: subtitle is 31 characters, the limit is 30"))
        }

        @Test("store-listing/the-listing-fits-app-store-connect: spaces after commas and subtitle words in keywords fail")
        func keywordRules() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("fastlane/metadata/sv/keywords.txt", "m3u, epg, live\n")
            try copy.write("fastlane/metadata/en-US/keywords.txt", "m3u,player,m3u\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("sv: keyword ' epg' has a space around it"))
            #expect(result.output.contains("en-US: keyword 'player' is already in the name or subtitle"))
            #expect(result.output.contains("en-US: keyword 'm3u' is listed twice"))
        }

        @Test("store-listing/the-listing-promises-no-content: a broadcaster, a link or free channels fail")
        func noContent() throws {
            let copy = try Copy()
            defer { copy.remove() }
            let spanish = try copy.read("fastlane/metadata/es-ES/description.txt")
            try copy.write("fastlane/metadata/es-ES/description.txt", spanish + "Mira la Champions League.\n")
            try copy.write("fastlane/metadata/en-US/promotional_text.txt", "Get playlists at playlists.example.com\n")
            try copy.write("fastlane/metadata/pt-BR/promotional_text.txt", "Mais de 10.000 canais grátis.\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("es-ES: description names 'champions league'"))
            #expect(result.output.contains("en-US: promotional_text carries an address"))
            #expect(result.output.contains("pt-BR: promotional_text promises free content"))
            #expect(result.output.contains("pt-BR: promotional_text promises an amount of content"))
        }

        @Test("store-listing/the-listing-promises-no-content: every description says no channels and a purchase")
        func saysNoChannelsAndPurchase() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("fastlane/metadata/de-DE/description.txt", "Antenna spielt TV ab.\n")
            let result = try run(["check"], root: copy.folder)
            #expect(result.status != 0)
            #expect(result.output.contains("de-DE: description must say 'keine Sender'"))
            #expect(result.output.contains("de-DE: description must say 'Kauf'"))
        }

        @Test("store-listing/a-language-s-listing-waits-for-its-review: Arabic is held until it is reviewed")
        func held() throws {
            let copy = try Copy()
            defer { copy.remove() }
            try copy.write("Config/reviewed-languages", "sv\nde\nes\nfr\npt-BR\n")
            let before = try run(["locales"], root: copy.folder)
            #expect(!before.output.contains("ar-SA"))
            #expect(before.output.hasPrefix("en en_US en-US\n"))
            #expect(try run(["held"], root: copy.folder).output == "ar\n")
            let checked = try run(["check"], root: copy.folder)
            #expect(checked.status == 0)
            #expect(checked.output.contains("held: ar"))
            try copy.write("Config/reviewed-languages", "sv\nde\nes\nfr\npt-BR\nar\n")
            let after = try run(["locales"], root: copy.folder)
            #expect(after.output.contains("ar ar_SA ar-SA\n"))
        }
    #endif

    @Test("store-listing/store-screenshots-in-every-ready-language: the workflow takes the store set per ready language")
    func screenshotWorkflow() throws {
        let workflow = try String(contentsOf: Self.root.appending(path: ".github/workflows/screenshots.yml"), encoding: .utf8)
        #expect(workflow.contains("python3 scripts/store_metadata.py locales"))
        #expect(workflow.contains("TEST_RUNNER_STORE_LANGUAGE=\"$code\" TEST_RUNNER_STORE_REGION=\"$region\""))
        #expect(workflow.contains("-only-testing:AntennaJourneys/AppJourneys/testStore"))
        #expect(workflow.contains("-only-testing:AntennaTVJourneys/TVJourneys/testStore"))
        #expect(workflow.contains("export-screenshots.sh --store \"$stores\" store-screenshots"))
        #expect(workflow.contains("name: store-screenshots"))
        #expect(workflow.contains("iPhone [0-9]+ Pro Max"))
        // store-listing/store-screenshots-in-every-ready-language, Mac pictures
        #expect(workflow.contains("-only-testing:AntennaMacJourneys/MacJourneys/testStore"))
        #expect(workflow.contains("store-mac-$code.xcresult"))
    }

    @Test("store-listing/store-screenshots-in-every-ready-language: the store clip and art stay out of Release builds")
    func storeFixturesLeaveRelease() throws {
        let config = try String(contentsOf: Self.root.appending(path: "Config/Shared.xcconfig"), encoding: .utf8)
        let line = try #require(config.split(separator: "\n").first { $0.hasPrefix("EXCLUDED_SOURCE_FILE_NAMES[config=Release]") })
        #expect(line.contains("StorePicture.mp4"))
        #expect(line.contains("StoreArt-*.jpg"))
    }
}
