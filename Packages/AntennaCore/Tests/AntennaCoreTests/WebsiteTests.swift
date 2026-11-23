import AntennaCore
import Foundation
import Testing

/// The site under `Web/` at the repository root, uploaded to CloudFront at
/// `SetupLink.host` by the site job in `.github/workflows/infra.yml`: the
/// plain files in `Web/` and the SvelteKit app in `Web/site/`, whose built
/// pages `Web/site/tests` checks.
@Suite struct WebsiteTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let web = root.appending(path: "Web")
    static let associationPath = ".well-known/apple-app-site-association"
    static let terms = "site/src/routes/terms/+page.svelte"
    static let privacy = "site/src/routes/privacy/+page.svelte"
    static let legalPages = [terms, privacy]

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
        for path in ["setup/index.html", Self.terms, Self.privacy, Self.associationPath] {
            #expect(FileManager.default.fileExists(atPath: Self.web.appending(path: path).path), "\(path) missing")
        }
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
        private func publish(teamID: String?, site: URL? = nil) throws -> (status: Int32, folder: URL) {
            let folder = FileManager.default.temporaryDirectory.appending(path: "web-\(UUID().uuidString)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [Self.root.appending(path: "scripts/publish-web.sh").path, folder.path] + (site.map { [$0.path] } ?? [])
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
            for path in ["setup/index.html", "review/antenna-review.m3u", "review/guide.xml"] {
                #expect(FileManager.default.fileExists(atPath: published.folder.appending(path: path).path), "\(path) not published")
            }
            #expect(!FileManager.default.fileExists(atPath: published.folder.appending(path: "site").path), "the app's source is published")
        }

        @Test("antenna-website/the-site-answers-every-address-the-app-uses: the built app joins the plain files, a shared path fails")
        func publishWithSite() throws {
            let site = FileManager.default.temporaryDirectory.appending(path: "site-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: site) }
            func write(_ path: String) throws {
                let file = site.appending(path: path)
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("<h1>\(path)</h1>".utf8).write(to: file)
            }
            for path in ["index.html", "terms/index.html", "privacy/index.html", "404.html"] {
                try write(path)
            }
            let published = try publish(teamID: "ABCDE12345", site: site)
            defer { try? FileManager.default.removeItem(at: published.folder) }
            #expect(published.status == 0)
            for path in ["index.html", "terms/index.html", "privacy/index.html", "404.html", "setup/index.html", Self.associationPath] {
                #expect(FileManager.default.fileExists(atPath: published.folder.appending(path: path).path), "\(path) not published")
            }

            try write("setup/index.html")
            let refused = try publish(teamID: "ABCDE12345", site: site)
            defer { try? FileManager.default.removeItem(at: refused.folder) }
            #expect(refused.status != 0)
        }
    #endif

    @Test("antenna-website/the-terms-of-use-put-the-streams-on-the-user: the sections and who answers for a stream")
    func termsSections() throws {
        let html = try read(Self.terms)
        #expect(
            headings(html) == [
                "What Antenna is", "Your sources", "Purchases", "Apple's license agreement", "No warranty", "Limits on liability",
                "Changes to these terms", "Contact",
            ])
        let body = text(html)
        for phrase in [
            "published by Code Crave", "comes with no channels, playlists, provider addresses or other content",
            "You are responsible for having the right to watch everything you add", "provided as is",
            "Licensed Application End User License Agreement", "These terms add to it", "see the Support page",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-terms-of-use-explain-the-purchases: renewal, canceling, lifetime, Family Sharing and refunds")
    func termsPurchases() throws {
        let body = text(try read(Self.terms))
        for phrase in [
            "Yearly subscription", "until you cancel", "at least 24 hours before the current year ends", "Lifetime unlock",
            "It does not renew", "Family Sharing", "Apple takes the payment", "Refunds are requested from Apple",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-privacy-policy-says-where-data-is-kept: iCloud, the Keychain and the ten-minute exception")
    func privacyStorage() throws {
        let html = try read(Self.privacy)
        #expect(
            headings(html) == [
                "What Antenna stores", "Logins", "Network connections", "Analytics and tracking", "Purchases", "Deleting your data",
                "Children", "Changes to this policy", "Contact",
            ])
        let body = text(html)
        for phrase in [
            "published by Code Crave", "private iCloud database", "Code Crave cannot read it", "favorites", "preferences",
            "programme reminders", "channel groups", "watch progress", "iCloud Keychain", "at most ten minutes", "Removing a source",
            "see the Support page",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
    }

    @Test("antenna-website/the-privacy-policy-rules-out-tracking: no analytics, no SDK, connections only to sources and Apple")
    func privacyTracking() throws {
        let body = text(try read(Self.privacy))
        for phrase in [
            "Antenna collects nothing about you", "Code Crave runs no server that receives it",
            "no analytics, crash reporting, advertising or tracking", "no third-party SDK", "Antenna connects only to",
            "the sources and guide sources you add, and the addresses they list", "Apple handles every purchase",
            "served by Amazon CloudFront", "no record is kept of who opened which page",
        ] {
            #expect(body.contains(phrase), "\(phrase)")
        }
        #expect(!body.contains("GitHub"))
    }

    @Test("antenna-website/the-legal-pages-are-dated-and-link-to-each-other: a date under the title and a link across")
    func datedAndLinked() throws {
        for (page, other) in [(Self.terms, "/privacy/"), (Self.privacy, "/terms/")] {
            let html = try read(page)
            let afterTitle = try #require(matches("</h1>\\s*(<p[^>]*>[^<]*</p>)", in: html).first, "\(page)")
            #expect(afterTitle.range(of: #"Last updated: [A-Z][a-z]+ \d{1,2}, \d{4}"#, options: .regularExpression) != nil, "\(page)")
            #expect(matches("<a\\s[^>]*href=\"([^\"]+)\"", in: html).contains(other), "\(page) links to \(other)")
        }
    }

    /// The tag check on the built pages is in `Web/site/tests`, which reads the
    /// HTML the app writes. This one reads the sources every page is built from.
    @Test("antenna-website/the-pages-read-on-a-phone-and-in-dark-mode: viewport, both appearances, a reading width")
    func phoneAndDarkMode() throws {
        let setup = try read("setup/index.html").lowercased()
        #expect(setup.contains("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"))
        let template = try read("site/src/app.html")
        #expect(template.contains("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"))
        #expect(template.contains("<meta name=\"color-scheme\" content=\"dark light\" />"))
        let css = try read("site/src/lib/site.css")
        #expect(css.contains("@media (prefers-color-scheme: light)"))
        #expect(css.contains("background: var(--bg)"))
        #expect(css.contains("--measure: 760px"))
        for page in Self.legalPages {
            let html = try read(page)
            #expect(html.contains("<article class=\"prose\">"), "\(page)")
            for tag in ["<script src", "<iframe", "<img", "<link", "<style", "style=\"", "@import", "url("] {
                #expect(!html.contains(tag), "\(tag) on \(page)")
            }
        }
    }

    @Test("antenna-website/the-site-publishes-from-main: the CloudFront upload runs from main and removes deleted pages")
    func uploadsFromMain() throws {
        let workflow = try read(".github/workflows/infra.yml", in: Self.root)
        let push = try #require(matches("\\n  push:\\n(.*?)\\n  [a-z_]+:", in: workflow).first)
        #expect(push.contains("branches: [main]"))
        for path in ["\"Web/**\"", "scripts/publish-web.sh", "scripts/make-review-guide.py"] {
            #expect(push.contains(path), "\(path)")
        }
        #expect(!FileManager.default.fileExists(atPath: Self.root.appending(path: ".github/workflows/pages.yml").path))
        let site = try #require(workflow.components(separatedBy: "\n  site:\n").last)
        #expect(site.contains("github.event_name != 'pull_request' && github.ref == 'refs/heads/main'"))
        #expect(site.contains("bash scripts/publish-web.sh"))
        #expect(site.contains("--delete"))
        #expect(site.contains("--cache-control \"public, max-age=31536000, immutable\""))
        #expect(site.contains("create-invalidation"))
    }

    @Test("antenna-website/the-site-answers-every-address-the-app-uses: the association file is uploaded as JSON")
    func associationFileIsJSON() throws {
        let workflow = try read(".github/workflows/infra.yml", in: Self.root)
        #expect(workflow.contains("aasa=\(Self.associationPath)"))
        #expect(workflow.contains("--exclude \"$aasa\""))
        #expect(workflow.contains("aws s3 cp \"$SITE/$aasa\" \"s3://$BUCKET/$aasa\" \\\n            --content-type application/json"))
    }
}
