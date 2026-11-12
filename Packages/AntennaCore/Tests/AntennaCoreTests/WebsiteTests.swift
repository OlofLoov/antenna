import AntennaCore
import Foundation
import Testing

/// The site under `Web/` at the repository root, published to `SetupLink.host`
/// by `.github/workflows/pages.yml`.
@Suite struct WebsiteTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let web = root.appending(path: "Web")
    static let associationPath = ".well-known/apple-app-site-association"
    static let legalPages = ["terms/index.html", "privacy/index.html"]

    private func read(_ path: String, in folder: URL = WebsiteTests.web) throws -> String {
        try String(contentsOf: folder.appending(path: path), encoding: .utf8)
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range(at: $0.numberOfRanges - 1), in: text).map { String(text[$0]) }
        }
    }

    private func headings(_ html: String) -> [String] {
        matches("<h2>(.*?)</h2>", in: html)
    }

    /// The page's text with tags removed and whitespace collapsed.
    private func text(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func appIDs(_ data: Data) throws -> [String] {
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let applinks = try #require(json["applinks"] as? [String: Any])
        let details = try #require(applinks["details"] as? [[String: Any]])
        return details.flatMap { $0["appIDs"] as? [String] ?? [] }
    }

    @Test("antenna-website/the-site-answers-every-address-the-app-uses: a file for each address, under the app's domain")
    func everyAddress() throws {
        for path in ["setup/index.html", "terms/index.html", "privacy/index.html", Self.associationPath, ".nojekyll"] {
            #expect(FileManager.default.fileExists(atPath: Self.web.appending(path: path).path), "\(path) missing")
        }
        #expect(try read("CNAME").trimmingCharacters(in: .whitespacesAndNewlines) == SetupLink.host)
        for plist in ["Apps/Mobile/Info.plist", "Apps/TV/Info.plist"] {
            let data = try Data(contentsOf: Self.root.appending(path: plist))
            let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            for (key, path) in [("AntennaTermsURL", "/terms"), ("AntennaPrivacyURL", "/privacy")] {
                let url = try #require((info[key] as? String).flatMap(URL.init(string:)), "\(key) in \(plist)")
                #expect(url.scheme == "https")
                #expect(url.host() == SetupLink.host)
                #expect(url.path() == path)
            }
        }
    }

    @Test("antenna-website/setup-links-open-antenna: one app id, only setup addresses")
    func association() throws {
        let data = try Data(contentsOf: Self.web.appending(path: Self.associationPath))
        let ids = try appIDs(data)
        #expect(ids.count == 1)
        let pattern = #"^(TEAMID_PLACEHOLDER|[A-Z0-9]{10})\.se\.codecrave\.antenna$"#
        #expect(ids.allSatisfy { $0.range(of: pattern, options: .regularExpression) != nil }, "\(ids)")
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["applinks"])
        let details = try #require((json["applinks"] as? [String: Any])?["details"] as? [[String: Any]])
        #expect(details.count == 1)
        let components = try #require(details.first?["components"] as? [[String: String]])
        #expect(components == [["/": "/setup"]])
    }

    #if os(macOS)
        private func publish(teamID: String?) throws -> (status: Int32, folder: URL) {
            let folder = FileManager.default.temporaryDirectory.appending(path: "web-\(UUID().uuidString)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [Self.root.appending(path: "scripts/publish-web.sh").path, folder.path]
            var environment = ProcessInfo.processInfo.environment
            environment["APPLE_TEAM_ID"] = teamID
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            return (process.terminationStatus, folder)
        }

        @Test("antenna-website/the-team-id-placeholder-never-reaches-the-site: publishing fills a valid id and refuses the rest")
        func teamID() throws {
            let committed = try appIDs(Data(contentsOf: Self.web.appending(path: Self.associationPath)))
            let placeholder = committed == ["TEAMID_PLACEHOLDER.se.codecrave.antenna"]
            if placeholder {
                #expect(try publish(teamID: nil).status != 0)
                #expect(try publish(teamID: "").status != 0)
                #expect(try publish(teamID: "abcde12345").status != 0)
                #expect(try publish(teamID: "ABCDE1234").status != 0)
            }

            let published = try publish(teamID: "ABCDE12345")
            #expect(published.status == 0)
            defer { try? FileManager.default.removeItem(at: published.folder) }
            let data = try Data(contentsOf: published.folder.appending(path: Self.associationPath))
            #expect(try appIDs(data) == (placeholder ? ["ABCDE12345.se.codecrave.antenna"] : committed))
            for path in ["setup/index.html", "terms/index.html", "privacy/index.html", "CNAME", ".nojekyll"] {
                #expect(FileManager.default.fileExists(atPath: published.folder.appending(path: path).path), "\(path) not published")
            }
        }
    #endif

    @Test("antenna-website/the-terms-of-use-put-the-streams-on-the-user: the sections and who answers for a stream")
    func termsSections() throws {
        let html = try read("terms/index.html")
        #expect(
            headings(html) == [
                "What Antenna is", "Your sources", "Purchases", "Apple's license agreement", "No warranty", "Limits on liability",
                "Changes to these terms", "Contact",
            ])
        let body = text(html)
        for phrase in [
            "published by Code Crave", "comes with no channels, playlists, provider addresses or other content",
            "You are responsible for having the right to watch everything you add", "provided as is",
            "Licensed Application End User License Agreement", "These terms add to it", "support@code-crave.se",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-terms-of-use-explain-the-purchases: renewal, canceling, lifetime, Family Sharing and refunds")
    func termsPurchases() throws {
        let body = text(try read("terms/index.html"))
        for phrase in [
            "Yearly subscription", "until you cancel", "at least 24 hours before the current year ends", "Lifetime unlock",
            "It does not renew", "Family Sharing", "Apple takes the payment", "Refunds are requested from Apple",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-privacy-policy-says-where-data-is-kept: iCloud, the Keychain and the ten-minute exception")
    func privacyStorage() throws {
        let html = try read("privacy/index.html")
        #expect(
            headings(html) == [
                "What Antenna stores", "Logins", "Network connections", "Analytics and tracking", "Purchases", "Deleting your data",
                "Children", "Changes to this policy", "Contact",
            ])
        let body = text(html)
        for phrase in [
            "published by Code Crave", "private iCloud database", "Code Crave cannot read it", "favorites", "preferences",
            "programme reminders", "channel groups", "watch progress", "iCloud Keychain", "at most ten minutes", "Removing a source",
            "support@code-crave.se",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-privacy-policy-rules-out-tracking: no analytics, no SDK, connections only to sources and Apple")
    func privacyTracking() throws {
        let body = text(try read("privacy/index.html"))
        for phrase in [
            "Antenna collects nothing about you", "Code Crave runs no server that receives it",
            "no analytics, crash reporting, advertising or tracking", "no third-party SDK", "Antenna connects only to",
            "the sources and guide sources you add, and the addresses they list", "Apple handles every purchase",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-legal-pages-are-dated-and-link-to-each-other: a date under the title and a link across")
    func datedAndLinked() throws {
        for (page, other) in [("terms/index.html", "/privacy/"), ("privacy/index.html", "/terms/")] {
            let html = try read(page)
            let afterTitle = try #require(matches("</h1>\\s*(<p[^>]*>[^<]*</p>)", in: html).first, "\(page)")
            #expect(afterTitle.range(of: #"Last updated: [A-Z][a-z]+ \d{1,2}, \d{4}"#, options: .regularExpression) != nil, "\(page)")
            #expect(matches("<a\\s[^>]*href=\"([^\"]+)\"", in: html).contains(other), "\(page) links to \(other)")
        }
    }

    @Test("antenna-website/the-pages-read-on-a-phone-and-in-dark-mode: viewport, both appearances, nothing loaded")
    func phoneAndDarkMode() throws {
        for page in ["setup/index.html"] + Self.legalPages {
            let html = try read(page).lowercased()
            #expect(html.contains("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"), "\(page)")
            for tag in ["<script", "<iframe", "<img", "<link", "<object", "<embed", "@import", "url("] {
                #expect(!html.contains(tag), "\(tag) on \(page)")
            }
        }
        for page in Self.legalPages {
            let html = try read(page)
            #expect(html.contains("@media (prefers-color-scheme: light)"), "\(page)")
            #expect(html.contains("background: var(--bg)"), "\(page)")
            #expect(html.contains("max-width: 40em"), "\(page)")
        }
    }

    @Test("antenna-website/the-site-publishes-from-main: pushes to main that touch the site, and nothing else")
    func publishesFromMain() throws {
        let workflow = try read(".github/workflows/pages.yml", in: Self.root)
        let trigger = try #require(matches("\\non:\\n(.*?)\\n\\S", in: workflow).first)
        #expect(trigger.contains("branches: [main]"))
        #expect(trigger.contains("\"Web/**\""))
        #expect(!trigger.contains("pull_request"))
        #expect(workflow.contains("bash scripts/publish-web.sh"))
        #expect(workflow.contains("include-hidden-files: true"))
    }
}
