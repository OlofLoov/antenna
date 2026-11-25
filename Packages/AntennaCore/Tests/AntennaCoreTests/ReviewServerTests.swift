import Foundation
import Testing

@testable import AntennaCore

/// The App Review demo Xtream Codes server: the answers `scripts/publish-web.sh`
/// writes under `review/xtream`, read with the app's own Xtream decoders, and
/// the function in `Infra/modules/site/review.js` that routes to them. The
/// function's routing is tested in `Infra/modules/site/tests/review.test.mjs`.
@Suite struct ReviewServerTests {
    static let root = WebsiteTests.root
    static let server = "https://\(SetupLink.host)/review"
    static let samples = "https://devstreaming-cdn.apple.com/videos/streaming/examples/"
    static let function = "Infra/modules/site/review.js"
    static let notes = "docs/release/app-review-notes.md"

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appending(path: path), encoding: .utf8)
    }

    private func addresses(in text: String) -> [String] {
        text.matches(of: /https?:\/\/[^\s"'`<>)]+/).map { String($0.output) }
    }

    /// The demo login as `review.js` checks it.
    private func login() throws -> (username: String, password: String) {
        let code = try read(Self.function)
        let username = try #require(code.firstMatch(of: /var USERNAME = '([^']+)';/)?.output.1)
        let password = try #require(code.firstMatch(of: /var PASSWORD = '([^']+)';/)?.output.1)
        return (String(username), String(password))
    }

    @Test("app-release/app-review-can-open-movies-and-series: the function leads only to Apple's sample streams")
    func functionAddresses() throws {
        #expect(addresses(in: try read(Self.function)) == [Self.samples])
    }

    @Test("app-release/the-review-server-answers-only-the-demo-login: the notes give the login the function checks")
    func notesMatchFunction() throws {
        let notes = try read(Self.notes)
        let login = try login()
        #expect(notes.contains("Server: \(Self.server)\n"))
        #expect(notes.contains("Username: \(login.username)\n"))
        #expect(notes.contains("Password: \(login.password)\n"))
    }

    @Test("app-release/the-review-server-answers-only-the-demo-login: CI runs the function's test")
    func functionTestRuns() throws {
        let workflow = try read(".github/workflows/infra.yml")
        #expect(workflow.contains("node --test Infra/modules/site/tests/review.test.mjs"))
        let pullRequest = try #require(workflow.firstMatch(of: /\n  pull_request:\n((?:    .*\n)+)/)?.output.1)
        for path in ["\"Web/review/**\"", "scripts/make-review-xtream.py"] {
            #expect(pullRequest.contains(path), "\(path)")
        }
    }

    #if os(macOS)
        /// The plain site files, published once for the suite.
        private static let published: URL? = {
            let folder = FileManager.default.temporaryDirectory.appending(path: "review-\(UUID().uuidString)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [root.appending(path: "scripts/publish-web.sh").path, folder.path]
            var environment = ProcessInfo.processInfo.environment
            environment["APPLE_TEAM_ID"] = "ABCDE12345"
            environment["REVIEW_GUIDE_START"] = "2026-03-28"
            environment["REVIEW_BASE_URL"] = nil
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            process.waitUntilExit()
            return process.terminationStatus == 0 ? folder : nil
        }()

        private func answer(_ name: String) throws -> Data {
            let folder = try #require(Self.published, "publish-web.sh failed")
            return try Data(contentsOf: folder.appending(path: "review/xtream/\(name)"))
        }

        private var client: XtreamClient {
            get throws {
                let login = try login()
                let server = try #require(URL(string: Self.server))
                return XtreamClient(credentials: XtreamCredentials(server: server, username: login.username, password: login.password))
            }
        }

        @Test("app-release/app-review-can-open-movies-and-series: the account signs in")
        func account() throws {
            let data = try answer("account.json")
            try XtreamClient.probeAuth(data)
            let account = try JSONDecoder().decode(XtreamAccountInfo.self, from: data)
            #expect(account.userInfo.auth == 1)
            #expect(ConnectFailure.accountStatus(account.userInfo.status) == nil)
            #expect(account.serverInfo?.timezone == "UTC")
        }

        @Test("app-release/app-review-can-open-movies-and-series: Live lists the playlist's channels with its guide ids")
        func live() throws {
            let playlist = M3UParser().parse(try read(ReleaseTests.playlistPath))
            let categories: [XtreamCategory] = try XtreamClient.decodeLossyList(try answer("get_live_categories.json"))
            let streams: [XtreamLiveStream] = try XtreamClient.decodeLossyList(try answer("get_live_streams.json"))
            #expect(categories.count == 1)
            #expect(streams.map(\.name) == playlist.channels.map(\.name))
            #expect(streams.map(\.epgChannelID) == playlist.channels.map(\.epgID))
            #expect(streams.allSatisfy { $0.categoryID == categories.first?.categoryID && ($0.tvArchive ?? 0) == 0 })
            let client = try client
            for stream in streams {
                let url = client.channel(from: stream, categoryName: nil).streamURL
                #expect(url.absoluteString.hasPrefix("\(Self.server)/live/"), "\(url.path())")
                #expect(EngineRouter.route(for: url) == .demuxer)
            }
            #expect(client.xmltvURL().absoluteString.hasPrefix("\(Self.server)/xmltv.php?"))
        }

        @Test("app-release/app-review-can-open-movies-and-series: Movies lists five movies with details that play on AVPlayer")
        func movies() throws {
            let host = SetupLink.host
            let categories: [XtreamCategory] = try XtreamClient.decodeLossyList(try answer("get_vod_categories.json"))
            let movies = try XtreamClient.decodeVODList(try answer("get_vod_streams.json"), host: host)
            #expect(categories.count == 2)
            #expect(movies.items.count == 5 && movies.skipped == 0)
            for category in categories {
                let filtered = try XtreamClient.decodeVODList(try answer("get_vod_streams/\(category.categoryID).json"), host: host)
                #expect(filtered.items == movies.items.filter { $0.categoryID == category.categoryID })
            }
            let client = try client
            for movie in movies.items {
                #expect(movie.posterURL != nil, "\(movie.name)")
                let info = try XtreamClient.decodeVODInfo(try answer("get_vod_info/\(movie.streamID).json"), host: host)
                #expect(info.plot?.isEmpty == false && info.year != nil && info.duration != nil && info.genre != nil, "\(movie.name)")
                #expect(info.backdropURLs.count == 1, "\(movie.name)")
                let url = client.movieURL(streamID: movie.streamID, extension: info.containerExtension ?? movie.containerExtension)
                #expect(url.absoluteString.hasPrefix("\(Self.server)/movie/"), "\(url.path())")
                #expect(url.pathExtension == "m3u8" && EngineRouter.route(for: url) == .system, "\(movie.name)")
            }
        }

        @Test("app-release/app-review-can-open-movies-and-series: Series lists one series with a season of episodes")
        func series() throws {
            let host = SetupLink.host
            let categories: [XtreamCategory] = try XtreamClient.decodeLossyList(try answer("get_series_categories.json"))
            let list = try XtreamClient.decodeSeriesList(try answer("get_series.json"), host: host)
            #expect(categories.count == 1)
            #expect(list.items.count == 1 && list.skipped == 0)
            let series = try #require(list.items.first)
            #expect(series.posterURL != nil)
            let info = try XtreamClient.decodeSeriesInfo(try answer("get_series_info/\(series.seriesID).json"), host: host)
            #expect(info.seasonCount == 1 && info.skippedEpisodes == 0)
            #expect(info.episodes.map(\.number) == [1, 2, 3])
            #expect(info.plot?.isEmpty == false && info.backdropURLs.count == 1)
            let client = try client
            for episode in info.episodes {
                #expect(episode.plot?.isEmpty == false && episode.duration != nil, "\(episode.title)")
                let url = client.episodeURL(episodeID: episode.episodeID, extension: episode.containerExtension)
                #expect(url.absoluteString.hasPrefix("\(Self.server)/series/"), "\(url.path())")
                #expect(EngineRouter.route(for: url) == .system, "\(episode.title)")
            }
        }

        @Test("app-release/app-review-can-open-movies-and-series: every address in the answers is art on the site")
        func answersNameOnlyTheSite() throws {
            let folder = try #require(Self.published, "publish-web.sh failed")
            let answers = folder.appending(path: "review/xtream")
            let files = try #require(FileManager.default.enumerator(at: answers, includingPropertiesForKeys: nil))
            var found = Set<String>()
            for case let file as URL in files where file.pathExtension == "json" {
                found.formUnion(addresses(in: try String(contentsOf: file, encoding: .utf8)))
            }
            #expect(found.count == 12)
            for address in found {
                #expect(address.hasPrefix("\(Self.server)/art/") && address.hasSuffix(".jpg"), "\(address)")
                let path = String(address.dropFirst(Self.server.count))
                #expect(FileManager.default.fileExists(atPath: folder.appending(path: "review\(path)").path), "\(path) not published")
            }
        }

        @Test("app-release/the-review-server-answers-only-the-demo-login: another login is refused as a wrong password")
        func denied() throws {
            #expect(throws: XtreamClient.XtreamError.unauthorized) { try XtreamClient.probeAuth(try answer("denied.json")) }
        }
    #endif
}
