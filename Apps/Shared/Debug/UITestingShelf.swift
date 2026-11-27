#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// Scripted movies and series for the Movies and Series UI tests
    /// (movies-and-series-browsing capability), compiled into Debug builds only.
    ///
    /// `-ui-testing-shelf <scenario>` starts the app on an in-memory store
    /// with Home (M3U) and the Xtream sources Cabin and Office. Nothing
    /// reaches the network, iCloud or the Keychain. The Live and shell UI
    /// tests get the `titles` script too, so their Movies tab is filled.
    /// `-ui-testing-reduce-motion` makes the banner act as with Reduce Motion on.
    /// Under any UI testing launch the banner holds its title, so a test
    /// that reads it on a slow simulator reads the title it expects;
    /// `-ui-testing-banner-rotates` lets it move on every 8 seconds again.
    enum UITestingShelf {
        static let argument = "-ui-testing-shelf"
        static let reduceMotionArgument = "-ui-testing-reduce-motion"
        /// `-ui-testing-many-seasons` gives Northern Lights fifteen seasons of
        /// two episodes (title-detail-and-episode-picker/pick-a-season).
        static let manySeasonsArgument = "-ui-testing-many-seasons"

        enum Scenario: String {
            /// Cabin: six movies in Action and Drama, three series. Office:
            /// three movies in Drama and Kids, one series. Mira Holt is in The
            /// Long Harbor's info answer, in Quiet Engines' and Small Rooms'
            /// list rows, and directs Paper Cities (browse-by-person).
            case titles
            /// Only Home, an M3U playlist: no Movies or Series anywhere.
            case noXtream
            /// Only Home, a playlist whose last load had two episodes and no
            /// movies: Series lists Pier Stories, and there is no Movies.
            case playlistSeries
            /// Cabin loads; Office never finishes.
            case loading
            /// Cabin loads; Office's first load fails and the next succeeds.
            case failing
            /// Both fail because the device is offline.
            case offline
            /// Cabin fails; Office has no login on this device.
            case error
            /// Cabin answers with nothing; Office has no login on this device.
            case empty
            /// As `titles`, with Second Act 40% in, Northern Lights' S2 E1
            /// finished last, its S1 E1 finished and S1 E2 barely started, Harbor Watch's first episode 30% in, Salt
            /// Road finished, and Paper Cities then Night Ferry added to
            /// My list, with an entry for a movie that is not loaded.
            case watching
            /// Cabin loads; Office's login arrives 6 seconds after launch.
            case waiting
            /// Thousands of titles from Cabin and Office (`UITestingShelfLarge`).
            case large
        }

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1") ?? UUID()
        static let cabinID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E2") ?? UUID()
        static let officeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E3") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError(
                    "\(argument) takes titles, watching, waiting, large, noXtream, playlistSeries, loading, failing, offline, "
                        + "error or empty"
                )
            }
            return scenario
        }

        static var reduceMotion: Bool {
            ProcessInfo.processInfo.arguments.contains(reduceMotionArgument)
        }

        /// True when any UI testing launch argument is present.
        static var testing: Bool {
            let arguments = ProcessInfo.processInfo.arguments
            return arguments.contains { $0.hasPrefix("-ui-testing-") }
        }

        /// The seeded store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard let scenario = scenario() else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                context.insert(
                    SourceRecord(
                        descriptor: SourceDescriptor(id: homeID, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/fixture/home.m3u")),
                        sortOrder: 0))
                if scenario != .noXtream, scenario != .playlistSeries {
                    for (order, (id, name)) in zip(1..., [(cabinID, "Cabin"), (officeID, "Office")]) {
                        let descriptor = SourceDescriptor(
                            id: id, name: name, kind: .xtream, url: URL(fileURLWithPath: "/fixture/\(name.lowercased())"),
                            credentialKey: "fixture")
                        context.insert(SourceRecord(descriptor: descriptor, sortOrder: order))
                    }
                }
                if scenario == .watching { seedActivity(context) }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the shelf UI testing store: \(error)")
            }
        }

        private static func seedActivity(_ context: ModelContext) {
            let now = Date.now
            func progress(_ id: String, series: String? = nil, at share: Double, ago: Double) {
                let length = series == nil ? 5400.0 : 2700.0
                let value = WatchProgress(
                    id: "", titleID: id, seriesID: series, sourceID: cabinID, position: share * length, duration: length,
                    updatedAt: now.addingTimeInterval(-ago))
                context.insert(ProgressRecord(value, profileID: nil))
            }
            progress("xtream#cabin#vod#2", at: 0.4, ago: 60)
            progress("xtream#cabin#episode#11", series: "xtream#cabin#series#1", at: 0.99, ago: 30)
            progress("xtream#cabin#episode#101", series: "xtream#cabin#series#1", at: 0.99, ago: 300)
            progress("xtream#cabin#episode#102", series: "xtream#cabin#series#1", at: 0.01, ago: 250)
            progress("xtream#cabin#episode#21", series: "xtream#cabin#series#2", at: 0.3, ago: 10)
            progress("xtream#cabin#vod#3", at: 0.99, ago: 5)
            let entries = [
                ("xtream#cabin#vod#4", cabinID, 100.0), ("xtream#office#vod#1", officeID, 50), ("xtream#cabin#vod#99", cabinID, 10),
            ]
            for (id, source, ago) in entries {
                context.insert(ListEntryRecord(titleID: id, sourceID: source, addedAt: now.addingTimeInterval(-ago), profileID: nil))
            }
        }

        /// What the refresher remembers of each source's last load, on a
        /// suite emptied at launch. Home remembers two episodes in
        /// `playlistSeries` (m3u-playlists/what-a-playlist-offered-is-remembered).
        static func lastLoads() -> LastLoadStore? {
            guard let scenario = scenario() else { return nil }
            let suite = "ui-testing-shelf"
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            defaults.removePersistentDomain(forName: suite)
            let store = LastLoadStore(defaults: defaults)
            if scenario == .playlistSeries { store.writeTitles(TitleCounts(movies: 0, episodes: 2), for: homeID) }
            return store
        }

        /// The scripted library for any UI testing launch, or nil.
        @MainActor
        static func library() -> ShelfLibrary? {
            guard testing else { return nil }
            let script = Script(scenario: scenario() ?? .titles)
            let dependencies = ShelfModel.Dependencies(
                load: { try await script.load($0, kind: $1) },
                hasLogin: { script.hasLogin($0) },
                info: { _, title in try await script.info(title) })
            return ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        }

        /// Live's sources for the shelf tests: Home's channels, nothing else.
        /// The recents, the session and what was watched last come from
        /// `UITestingRecents`, so `-ui-testing-keep-session` keeps them.
        @MainActor
        static func liveDependencies() -> LiveModel.Dependencies? {
            guard scenario() != nil else { return nil }
            return LiveModel.Dependencies(
                engine: UITestingLive.Engine(log: nil),
                load: { $0.id == homeID ? Playlist(channels: UITestingLive.home + UITestingLive.harbour) : Playlist(channels: []) },
                hasLogin: { _ in true },
                guide: nil,
                programmes: UITestingLive.guide,
                recents: UITestingRecents.store { _ in homeID },
                sleep: UITestingRecents.sleep)
        }

        /// When the app launched; the titles' dates count back from it.
        @MainActor static let launched = Date.now

        /// What each scenario's Xtream sources answer.
        @MainActor
        final class Script {
            let scenario: Scenario
            private var officeLoads = 0

            init(scenario: Scenario) {
                self.scenario = scenario
            }

            func hasLogin(_ source: SourceDescriptor) -> Bool {
                guard source.id == officeID else { return true }
                switch scenario {
                case .error, .empty: return false
                case .waiting: return Date.now.timeIntervalSince(launched) > 6
                case .titles, .watching, .large, .noXtream, .playlistSeries, .loading, .failing, .offline: return true
                }
            }

            func load(_ source: SourceDescriptor, kind: ShelfTitle.Kind) async throws -> ShelfCatalogue {
                // The scripted playlist has one series in `playlistSeries` and nothing otherwise.
                guard source.kind == .xtream else {
                    guard scenario == .playlistSeries, kind == .series else { return ShelfCatalogue(titles: [], categories: []) }
                    let series = ShelfTitle(
                        id: "m3u.series.00000000000000a1", kind: .series, sourceID: source.id, name: "Pier Stories", category: "Shows")
                    return ShelfCatalogue(titles: [series], categories: ["Shows"])
                }
                let isCabin = source.id == cabinID
                if !isCabin { officeLoads += 1 }
                switch scenario {
                case .large:
                    return try await UITestingShelfLarge.build(
                        source.id, host: isCabin ? "cabin" : "office", kind: kind, launched: launched)
                case .titles, .watching, .waiting, .noXtream, .playlistSeries:
                    return catalogue(source.id, kind: kind)
                case .loading:
                    if !isCabin { try await Task.sleep(for: .seconds(3600)) }
                    return catalogue(source.id, kind: kind)
                case .failing:
                    if !isCabin, officeLoads == 1 { throw URLError(.badServerResponse) }
                    return catalogue(source.id, kind: kind)
                case .offline:
                    throw URLError(.notConnectedToInternet)
                case .error:
                    throw URLError(.cannotFindHost)
                case .empty:
                    return ShelfCatalogue(titles: [], categories: [])
                }
            }

            private var officeEpisodeLoads = 0

            /// Northern Lights: two episodes of season 1, three of season 2
            /// (ids 11 to 13), one of season 3, a special and one with no
            /// season or number. Harbor Watch: two of season 1. Small Rooms:
            /// none. Long Winter (Office): the first two loads fail, then two
            /// episodes. The banner asks first, as the title after Harbor
            /// Watch, so its page still opens on the failure and Retry works.
            func episodes(_ series: ShelfTitle) async throws -> [Episode] {
                let parts = series.id.split(separator: "#")
                let host = parts.count > 1 ? String(parts[1]) : ""
                let number = Int(parts.last ?? "") ?? 0
                if host == "office" {
                    officeEpisodeLoads += 1
                    if officeEpisodeLoads <= 2 { throw URLError(.badServerResponse) }
                }
                if host == "cabin", number == 3 { return [] }
                if host == "cabin", number == 1 {
                    return ProcessInfo.processInfo.arguments.contains(UITestingShelf.manySeasonsArgument)
                        ? fifteenSeasons : northernLights
                }
                return (1...2).map { index in
                    Episode(
                        id: "xtream#\(host)#episode#\(number * 10 + index)", episodeID: number * 10 + index, season: 1,
                        number: index, title: "Episode \(index)", containerExtension: "mp4", duration: 2700)
                }
            }

            private var northernLights: [Episode] {
                func episode(_ id: Int, _ season: Int?, _ number: Int?, _ title: String, _ plot: String?) -> Episode {
                    Episode(
                        id: "xtream#cabin#episode#\(id)", episodeID: id, season: season, number: number, title: title,
                        containerExtension: "mp4", duration: 2700, plot: plot)
                }
                return [
                    episode(2, nil, nil, "Episode", nil),
                    episode(1, 0, 1, "Behind the Lights", "How the station was built for the screen."),
                    episode(101, 1, 1, "Arrival", "The relief crew lands the week the lights return."),
                    episode(102, 1, 2, "Static", "The radio picks up a voice from the last team."),
                    episode(11, 2, 1, "The Weir", "The generator fails on the first night."),
                    episode(12, 2, 2, "Low Water", "The tide drops further than the charts allow."),
                    episode(13, 2, 3, "Ice Road", nil),
                    episode(301, 3, 1, "Thaw", "Spring comes early to the station."),
                ]
            }

            private var infoLoads: [String: Int] = [:]

            /// The title page's info call. The Long Harbor has every field, a
            /// cast and a trailer; Night Ferry has a trailer too; Salt Road only a length; Copper Hills (Office) fails
            /// once, then answers. A series carries its episodes and answers
            /// after half a second.
            func info(_ title: ShelfTitle) async throws -> TitleInfo {
                infoLoads[title.id, default: 0] += 1
                InfoLoads.shared.add()
                switch title.kind {
                case .movie:
                    switch title.id {
                    case "xtream#cabin#vod#1":
                        return .movie(
                            VODInfo(
                                plot: "A harbour pilot uncovers a smuggling ring the night before the port is sold. One tide to decide "
                                    + "who gets out. With the buyers arriving at dawn and her own crew split down the middle, she has "
                                    + "until the water turns to choose a side, and every channel out of the harbour is watched. Her "
                                    + "brother runs the tug the buyers hired, the harbourmaster owes them money, and the one radio she "
                                    + "trusts is on a boat already past the breakwater.",
                                year: 2024, duration: 7_680, genre: "Thriller", ageRating: "15",
                                backdropURLs: [UITestingStoreShots.art(for: title.id, .backdrop)].compactMap(\.self),
                                containerExtension: "mkv",
                                cast: "Mira Holt, Jonas Reeve, Adaeze Okafor", director: "Sanna Weiss", rating: 7.4,
                                trailerURL: URL(string: "https://trailers.example/long-harbor")))
                    case "xtream#cabin#vod#3":
                        return .movie(VODInfo(duration: 5_520))
                    case "xtream#office#vod#3" where infoLoads[title.id] == 1:
                        throw URLError(.badServerResponse)
                    default:
                        // Night Ferry's rating and trailer are the banner's.
                        let details = details(title)
                        return .movie(
                            VODInfo(
                                plot: details.plot, year: details.year, duration: details.duration, genre: title.category,
                                backdropURLs: [details.backdropURL].compactMap(\.self), rating: details.rating,
                                trailerURL: details.trailerURL))
                    }
                case .series:
                    // A series answers after half a second, or three with `-ui-testing-slow-series`.
                    try await Task.sleep(for: UITestingShelf.seriesAnswerDelay)
                    let details = details(title)
                    return .series(
                        SeriesInfo(
                            plot: details.plot, year: details.year, genre: title.category, rating: 8.1,
                            episodes: try await episodes(title), skippedEpisodes: title.id == "xtream#cabin#series#1" ? 1 : 0))
                }
            }

            /// The banner's details. The Long Harbor is rated 7.4, and its trailer
            /// is a web page, which gets no button on Apple TV; Night Ferry is rated
            /// 6.8 and has an HLS trailer, which every platform offers.
            func details(_ title: ShelfTitle) -> ShelfDetails {
                let number = Int(title.id.split(separator: "#").last ?? "") ?? 0
                var details =
                    title.kind == .movie
                    ? ShelfDetails(
                        year: 2000 + number, duration: Double(90 + number) * 60, plot: "The story of \(title.name).", ageRating: "15")
                    : ShelfDetails(year: 2010 + number, seasons: number % 3 + 1, plot: "A series about \(title.name).")
                details.backdropURL = UITestingShelfLarge.backdrop(title.id, large: scenario == .large)
                switch title.id {
                case "xtream#cabin#vod#1":
                    details.rating = 7.4
                    details.trailerURL = URL(string: "https://trailers.example/long-harbor")
                case "xtream#office#vod#1":
                    details.rating = 6.8
                    details.trailerURL = URL(string: "https://trailers.example/night-ferry.m3u8")
                default: break
                }
                return details
            }

            private func catalogue(_ source: UUID, kind: ShelfTitle.Kind) -> ShelfCatalogue {
                let isCabin = source == cabinID
                let host = isCabin ? "cabin" : "office"
                func title(
                    _ number: Int, _ name: String, daysAgo: Double?, _ category: String?, cast: String? = nil, director: String? = nil
                ) -> ShelfTitle {
                    let id = "xtream#\(host)#\(kind == .movie ? "vod" : "series")#\(number)"
                    return ShelfTitle(
                        id: id, kind: kind, sourceID: source, name: name, posterURL: UITestingStoreShots.art(for: id, .poster),
                        added: daysAgo.map { launched.addingTimeInterval(-$0 * 86_400) }, category: category,
                        containerExtension: "mp4", cast: cast, director: director)
                }
                switch (kind, isCabin) {
                case (.movie, true):
                    return ShelfCatalogue(
                        titles: [
                            title(1, "The Long Harbor", daysAgo: 1, "Action"), title(2, "Second Act", daysAgo: 3, "Drama"),
                            title(3, "Salt Road", daysAgo: 40, "Action"),
                            title(4, "Paper Cities", daysAgo: nil, "Drama", director: "Mira Holt"),
                            title(5, "Quiet Engines", daysAgo: 12, "Action", cast: "MIRA HOLT / Teodor Lind"),
                            title(6, "Glass Orchard", daysAgo: nil, nil),
                        ],
                        categories: ["Action", "Drama"])
                case (.movie, false):
                    return ShelfCatalogue(
                        titles: [
                            title(1, "Night Ferry", daysAgo: 2, "Drama"), title(2, "Snow Day", daysAgo: 5, "Kids"),
                            title(3, "Copper Hills", daysAgo: 90, "Drama"),
                        ],
                        categories: ["Drama", "Kids"])
                case (.series, true):
                    return ShelfCatalogue(
                        titles: [
                            title(1, "Northern Lights", daysAgo: 4, "Drama"), title(2, "Harbor Watch", daysAgo: 1, "Crime"),
                            title(3, "Small Rooms", daysAgo: 30, "Drama", cast: "Mira Holt, N/A, Teodor Lind"),
                        ],
                        categories: ["Drama", "Crime"])
                case (.series, false):
                    return ShelfCatalogue(titles: [title(1, "Long Winter", daysAgo: 2, "Drama")], categories: ["Drama"])
                }
            }
        }
    }

    extension UITestingShelf {
        static let bannerRotatesArgument = "-ui-testing-banner-rotates"

        /// True when a UI test launched the app without asking for the
        /// banner to move on by itself.
        static var holdsBanner: Bool {
            testing && !ProcessInfo.processInfo.arguments.contains(bannerRotatesArgument)
        }
    }

    extension UITestingShelf.Script {
        /// Seasons 1 to 15, two episodes each, ids 1011 to 1152.
        fileprivate var fifteenSeasons: [Episode] {
            (1...15).flatMap { season in
                (1...2).map { number in
                    Episode(
                        id: "xtream#cabin#episode#\(1000 + season * 10 + number)", episodeID: 1000 + season * 10 + number,
                        season: season, number: number, title: "Episode \(number)", containerExtension: "mp4", duration: 2700)
                }
            }
        }
    }

    extension UITestingShelf {
        /// `-ui-testing-focus-scroll-wins` scrolls a row placed after a move
        /// up back under the preview a few frames later, as the focus
        /// engine's own scroll does when it lands after the screen's.
        static let focusScrollWinsArgument = "-ui-testing-focus-scroll-wins"

        static var focusScrollWins: Bool {
            ProcessInfo.processInfo.arguments.contains(focusScrollWinsArgument)
        }
    }

    extension UITestingShelf {
        /// `-ui-testing-section-focus-lands-last` asks for the banner's Play
        /// button 50 ms after a page opened from a poster closes, which moves
        /// the highlight off that poster as the focus engine does when its
        /// own pick lands after the poster asked for focus back.
        static let sectionFocusLandsLastArgument = "-ui-testing-section-focus-lands-last"

        static var sectionFocusLandsLast: Bool {
            ProcessInfo.processInfo.arguments.contains(sectionFocusLandsLastArgument)
        }
    }

    extension UITestingShelf {
        /// `-ui-testing-slow-series` makes a series answer after three
        /// seconds instead of half of one, long enough for a UI test to see
        /// the title page wait (title-detail-and-episode-picker/the-page-shows-in-one-go).
        static let slowSeriesArgument = "-ui-testing-slow-series"

        static var seriesAnswerDelay: Duration {
            ProcessInfo.processInfo.arguments.contains(slowSeriesArgument) ? .seconds(3) : .milliseconds(500)
        }
    }
#endif
