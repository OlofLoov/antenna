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
    enum UITestingShelf {
        static let argument = "-ui-testing-shelf"
        static let reduceMotionArgument = "-ui-testing-reduce-motion"

        enum Scenario: String {
            /// Cabin: six movies in Action and Drama, three series. Office:
            /// three movies in Drama and Kids, one series.
            case titles
            /// Only Home, an M3U playlist: no Movies or Series anywhere.
            case noXtream
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
        }

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1") ?? UUID()
        static let cabinID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E2") ?? UUID()
        static let officeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E3") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes titles, noXtream, loading, failing, offline, error or empty")
            }
            return scenario
        }

        static var reduceMotion: Bool {
            ProcessInfo.processInfo.arguments.contains(reduceMotionArgument)
        }

        /// True when any UI testing launch argument is present.
        private static var testing: Bool {
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
                if scenario != .noXtream {
                    for (order, (id, name)) in zip(1..., [(cabinID, "Cabin"), (officeID, "Office")]) {
                        let descriptor = SourceDescriptor(
                            id: id, name: name, kind: .xtream, url: URL(fileURLWithPath: "/fixture/\(name.lowercased())"),
                            credentialKey: "fixture")
                        context.insert(SourceRecord(descriptor: descriptor, sortOrder: order))
                    }
                }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the shelf UI testing store: \(error)")
            }
        }

        /// The scripted library for any UI testing launch, or nil.
        @MainActor
        static func library() -> ShelfLibrary? {
            guard testing else { return nil }
            let script = Script(scenario: scenario() ?? .titles)
            let dependencies = ShelfModel.Dependencies(
                load: { try await script.load($0, kind: $1) },
                hasLogin: { script.hasLogin($0) },
                details: { _, title in script.details(title) })
            return ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        }

        /// Live's sources for the shelf tests: Home's channels, nothing else.
        @MainActor
        static func liveDependencies() -> LiveModel.Dependencies? {
            guard scenario() != nil else { return nil }
            return LiveModel.Dependencies(
                engine: UITestingLive.Engine(log: nil),
                load: { $0.id == homeID ? Playlist(channels: UITestingLive.home) : Playlist(channels: []) },
                hasLogin: { _ in true },
                guide: nil,
                programmes: UITestingLive.guide)
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
                return scenario != .error && scenario != .empty
            }

            func load(_ source: SourceDescriptor, kind: ShelfTitle.Kind) async throws -> ShelfCatalogue {
                let isCabin = source.id == cabinID
                if !isCabin { officeLoads += 1 }
                switch scenario {
                case .titles, .noXtream:
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

            func details(_ title: ShelfTitle) -> ShelfDetails {
                let number = Int(title.id.split(separator: "#").last ?? "") ?? 0
                return title.kind == .movie
                    ? ShelfDetails(
                        year: 2000 + number, duration: Double(90 + number) * 60, plot: "The story of \(title.name).", ageRating: "15")
                    : ShelfDetails(year: 2010 + number, seasons: number % 3 + 1, plot: "A series about \(title.name).")
            }

            private func catalogue(_ source: UUID, kind: ShelfTitle.Kind) -> ShelfCatalogue {
                let isCabin = source == cabinID
                let host = isCabin ? "cabin" : "office"
                func title(_ number: Int, _ name: String, daysAgo: Double?, _ category: String?) -> ShelfTitle {
                    ShelfTitle(
                        id: "xtream#\(host)#\(kind == .movie ? "vod" : "series")#\(number)", kind: kind, sourceID: source, name: name,
                        added: daysAgo.map { launched.addingTimeInterval(-$0 * 86_400) }, category: category,
                        containerExtension: "mp4")
                }
                switch (kind, isCabin) {
                case (.movie, true):
                    return ShelfCatalogue(
                        titles: [
                            title(1, "The Long Harbor", daysAgo: 1, "Action"), title(2, "Second Act", daysAgo: 3, "Drama"),
                            title(3, "Salt Road", daysAgo: 40, "Action"), title(4, "Paper Cities", daysAgo: nil, "Drama"),
                            title(5, "Quiet Engines", daysAgo: 12, "Action"), title(6, "Glass Orchard", daysAgo: nil, nil),
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
                            title(3, "Small Rooms", daysAgo: 30, "Drama"),
                        ],
                        categories: ["Drama", "Crime"])
                case (.series, false):
                    return ShelfCatalogue(titles: [title(1, "Long Winter", daysAgo: 2, "Drama")], categories: ["Drama"])
                }
            }
        }
    }
#endif
