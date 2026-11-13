import AntennaCore
import Foundation
import Testing

/// The release flow, the version the apps report, their privacy manifests and
/// the App Review source, read from the files at the repository root.
@Suite struct ReleaseTests {
    static let root = WebsiteTests.root
    static let playlistPath = "Web/review/antenna-review.m3u"
    static let bundles = ["Apps/Mobile", "Apps/TV", "Apps/TopShelf"]

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appending(path: path), encoding: .utf8)
    }

    private func json(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appending(path: path))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appending(path: path))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func package() throws -> [String: Any] {
        let packages = try #require(try json("release-please-config.json")["packages"] as? [String: Any])
        return try #require(packages["."] as? [String: Any])
    }

    private var playlist: Playlist {
        get throws { M3UParser().parse(try read(Self.playlistPath)) }
    }

    @Test("app-release/a-release-waits-for-the-owner: one release PR from main, minor for features before 1.0")
    func releasePullRequest() throws {
        let workflow = try read(".github/workflows/release.yml")
        #expect(workflow.contains("on:\n  push:\n    branches: [main]\n\n"))
        #expect(!workflow.contains("pull_request"))
        let package = try package()
        #expect(package["release-type"] as? String == "simple")
        #expect(package["bump-minor-pre-major"] as? Bool == true)
        #expect(package["include-component-in-tag"] as? Bool == false)
        let manifest = try json(".release-please-manifest.json")
        #expect(manifest.keys.sorted() == ["."])
    }

    #if os(macOS)
        private func run(_ executable: String, _ arguments: [String], input: String? = nil) throws -> (status: Int32, output: Data) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = Self.root
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            let stdin = Pipe()
            process.standardInput = stdin
            try process.run()
            if let input { stdin.fileHandleForWriting.write(Data(input.utf8)) }
            try stdin.fileHandleForWriting.close()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, data)
        }

        @Test("app-release/a-release-waits-for-the-owner: the release PR title passes the commit lint")
        func releaseTitle() throws {
            let pattern = try #require(try json("release-please-config.json")["pull-request-title-pattern"] as? String)
            #expect(pattern.contains("${version}"))
            let title = pattern.replacingOccurrences(of: "${version}", with: "0.12.3")
            let lint = try run("/bin/bash", ["scripts/lint-commit.sh", "-"], input: title + "\n")
            #expect(lint.status == 0, "\(title)")
            let scope = try #require(title.firstMatch(of: /^[a-z]+\(([a-z]+)\)/)?.1)
            #expect(["core", "app", "tv", "mobile", "spec", "ci", "build", "docs"].contains(String(scope)))
        }

        @Test("app-release/the-reviewer-guide-covers-the-coming-weeks: every channel, back to back, for four weeks")
        func reviewGuide() throws {
            let generated = try run("/usr/bin/env", ["python3", "scripts/make-review-guide.py", Self.playlistPath, "2026-03-28", "36"])
            #expect(generated.status == 0)
            let guide = try XMLTVParser().parse(generated.output)
            let start = try #require(ISO8601DateFormatter().date(from: "2026-03-28T00:00:00Z"))
            let end = start.addingTimeInterval(36 * 86_400)
            let ids = try playlist.channels.compactMap(\.epgID)
            #expect(ids.count == 4)
            #expect(Set(guide.channelNames.keys) == Set(ids))
            for id in ids {
                let programmes = guide.programmes.filter { $0.channelID == id }.sorted { $0.start < $1.start }
                #expect(programmes.first?.start == start, "\(id)")
                #expect(programmes.last?.stop == end, "\(id)")
                #expect(zip(programmes, programmes.dropFirst()).allSatisfy { $0.stop == $1.start }, "\(id) has a gap")
            }
        }

        @Test("app-release/the-reviewer-guide-covers-the-coming-weeks: publishing writes the guide next to the playlist")
        func reviewGuidePublished() throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: "web-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: folder) }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [Self.root.appending(path: "scripts/publish-web.sh").path, folder.path]
            var environment = ProcessInfo.processInfo.environment
            environment["APPLE_TEAM_ID"] = "ABCDE12345"
            environment["REVIEW_GUIDE_START"] = "2026-03-28"
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            let guide = try XMLTVParser().parse(Data(contentsOf: folder.appending(path: "review/guide.xml")))
            #expect(guide.programmes.count > 4 * 28 * 24)
            #expect(FileManager.default.fileExists(atPath: folder.appending(path: "review/antenna-review.m3u").path))
        }
    #endif

    @Test("app-release/the-reviewer-guide-covers-the-coming-weeks: the site publishes again after a release")
    func republishAfterRelease() throws {
        let workflow = try read(".github/workflows/release.yml")
        #expect(workflow.contains("if: needs.release.outputs.release_created == 'true'"))
        #expect(workflow.contains("gh workflow run pages.yml"))
        let pages = try read(".github/workflows/pages.yml")
        #expect(pages.contains("workflow_dispatch:"))
        #expect(pages.contains("scripts/make-review-guide.py"))
    }

    @Test("app-release/merging-the-release-pull-request-publishes-the-release: a pinned action, outputs for later, no upload")
    func publishOnMerge() throws {
        let workflow = try read(".github/workflows/release.yml")
        #expect(workflow.firstMatch(of: /uses: googleapis\/release-please-action@[0-9a-f]{40}\n/) != nil)
        for output in ["release_created", "tag_name", "version"] {
            #expect(workflow.contains("\(output): ${{ steps.release.outputs.\(output) }}"), "\(output)")
        }
        for upload in ["xcodebuild", "altool", "notarytool", "upload-testflight", "app-store-connect", "fastlane"] {
            #expect(!workflow.lowercased().contains(upload), "\(upload)")
        }
        #expect(try package()["skip-github-release"] == nil)
    }

    @Test("app-release/every-bundle-reports-the-release-version: one version file the release updates, read by every bundle")
    func versionFlows() throws {
        let extras = try #require(try package()["extra-files"] as? [[String: String]])
        #expect(extras == [["type": "yaml", "path": "Config/version.yml", "jsonpath": "$.settings.base.MARKETING_VERSION"]])
        let version = try read("Config/version.yml")
        #expect(version.firstMatch(of: /^settings:\n  base:\n    MARKETING_VERSION: \d+\.\d+\.\d+\n$/) != nil, "\(version)")
        #expect(try read("project.yml").contains("include:\n  - Config/version.yml\n"))
        #expect(try !read("Config/Shared.xcconfig").contains("MARKETING_VERSION"))
        for bundle in Self.bundles {
            let info = try plist("\(bundle)/Info.plist")
            #expect(info["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)", "\(bundle)")
            #expect(info["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)", "\(bundle)")
        }
    }

    @Test("app-release/each-bundle-declares-its-privacy: no tracking, nothing collected, a reason for each API")
    func privacyManifests() throws {
        let app = [
            "NSPrivacyAccessedAPICategoryDiskSpace": ["E174.1"],
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
        ]
        let expected = [
            "Apps/Mobile": app, "Apps/TV": app, "Apps/TopShelf": ["NSPrivacyAccessedAPICategoryDiskSpace": ["E174.1"]],
        ]
        for bundle in Self.bundles {
            let manifest = try plist("\(bundle)/PrivacyInfo.xcprivacy")
            #expect(manifest["NSPrivacyTracking"] as? Bool == false, "\(bundle)")
            #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true, "\(bundle)")
            #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true, "\(bundle)")
            let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]], "\(bundle)")
            var declared: [String: [String]] = [:]
            for api in apis {
                let type = try #require(api["NSPrivacyAccessedAPIType"] as? String)
                declared[type] = api["NSPrivacyAccessedAPITypeReasons"] as? [String]
            }
            #expect(declared == expected[bundle], "\(bundle)")
        }
    }

    @Test("app-release/app-review-gets-a-test-source-outside-the-app: Apple's sample streams, the guide in the header")
    func reviewPlaylist() throws {
        let playlist = try playlist
        #expect(playlist.channels.count == 4)
        #expect(playlist.movies.isEmpty && playlist.episodes.isEmpty)
        for channel in playlist.channels {
            #expect(channel.streamURL.scheme == "https", "\(channel.name)")
            #expect(channel.streamURL.host() == "devstreaming-cdn.apple.com", "\(channel.name)")
            #expect(channel.streamURL.path().hasPrefix("/videos/streaming/examples/"), "\(channel.name)")
            #expect(channel.streamURL.pathExtension == "m3u8", "\(channel.name)")
        }
        #expect(playlist.epgURLs == [URL(string: "https://\(SetupLink.host)/review/guide.xml")])
    }

    @Test("app-release/app-review-gets-a-test-source-outside-the-app: the app never names the review files")
    func reviewSourceNotInApp() throws {
        let apps = Self.root.appending(path: "Apps")
        let files = try #require(FileManager.default.enumerator(at: apps, includingPropertiesForKeys: nil))
        for case let file as URL in files where ["swift", "plist", "strings", "xcstrings", "json"].contains(file.pathExtension) {
            let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            #expect(!text.contains("antenna-review"), "\(file.path)")
            #expect(!text.contains("\(SetupLink.host)/review"), "\(file.path)")
        }
    }
}
