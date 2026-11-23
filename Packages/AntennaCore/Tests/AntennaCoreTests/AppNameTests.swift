import Foundation
import Testing

/// The name people see and the identifiers an installed build reads, from the
/// project, the catalogs, the listing and the site at the repository root.
@Suite struct AppNameTests {
    static let root = WebsiteTests.root

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appending(path: path), encoding: .utf8)
    }

    @Test("app-release/the-app-is-called-antuna-wherever-a-person-sees-it: the icon, Finder and the menu bar say Antuna")
    func displayNames() throws {
        let project = try read("project.yml")
        #expect(project.components(separatedBy: "CFBundleDisplayName: Antuna\n").count == 4)
        #expect(!project.contains("CFBundleDisplayName: Antenna"))
        #expect(project.contains("  Antenna:\n    type: application\n    productName: Antuna\n"))
        #expect(project.contains("PRODUCT_NAME: Antuna\n        PRODUCT_MODULE_NAME: Antenna\n"))

        let data = try Data(contentsOf: Self.root.appending(path: "Apps/Shared/InfoPlist.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        for key in ["CFBundleName", "CFBundleDisplayName"] {
            let localizations = try #require(strings[key]?["localizations"] as? [String: [String: [String: String]]])
            #expect(!localizations.isEmpty)
            for (language, unit) in localizations {
                #expect(unit["stringUnit"]?["value"] == "Antuna", "\(key) \(language)")
            }
        }
    }

    @Test("app-release/the-app-is-called-antuna-wherever-a-person-sees-it: every listing and the site are named Antuna")
    func listingAndSite() throws {
        let metadata = Self.root.appending(path: "fastlane/metadata")
        let locales = try FileManager.default.contentsOfDirectory(atPath: metadata.path).filter { !$0.contains(".") }
        #expect(locales.count == 9)
        for locale in locales {
            #expect(try read("fastlane/metadata/\(locale)/name.txt") == "Antuna\n", "\(locale)")
            for field in ["support_url", "privacy_url"] {
                #expect(try read("fastlane/metadata/\(locale)/\(field).txt").hasPrefix("https://antuna.app/"), "\(locale) \(field)")
            }
        }
        #expect(try read("Web/site/src/lib/strings/en.json").contains("\"name\": \"Antuna\""))
        #expect(try read("Web/setup/index.html").contains("<title>Antuna</title>"))
    }

    @Test("app-release/the-app-is-called-antuna-wherever-a-person-sees-it: an update keeps the ids the old build stored its data under")
    func keptIdentifiers() throws {
        let project = try read("project.yml")
        for id in ["se.codecrave.antenna\n", "se.codecrave.antenna.tv\n", "se.codecrave.antenna.tv.topshelf\n"] {
            #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: \(id)"), "\(id)")
        }
        #expect(project.contains("NSUserActivityTypes: [se.codecrave.antenna.setup]"))
        let config = try read("Config/Shared.xcconfig")
        #expect(config.contains("= iCloud.se.codecrave.antenna\n"))
        #expect(config.contains("= $(AppIdentifierPrefix)se.codecrave.antenna.shared\n"))
        for file in ["Antenna", "AntennaMac", "AntennaTV"] {
            #expect(try read("Config/\(file).entitlements").contains("<string>iCloud.se.codecrave.antenna</string>"), "\(file)")
        }
        #expect(try read("Config/AntennaTopShelf.entitlements").contains("<string>group.se.codecrave.antenna</string>"))
        #expect(try read("Apps/Shared/Persistence/CredentialStore.swift").contains("\"se.codecrave.antenna.sources\""))
        let storeKit = try read("Config/Antenna.storekit")
        #expect(storeKit.contains("\"se.codecrave.antenna.lifetime\"") && storeKit.contains("\"se.codecrave.antenna.yearly\""))
    }
}
