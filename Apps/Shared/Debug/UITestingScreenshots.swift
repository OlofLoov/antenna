#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// Seed data for the screenshot walk-throughs, compiled into Debug builds only.
    ///
    /// `-ui-screenshots full` starts the app on an in-memory store with an M3U
    /// source "Home" (12 channels in News, Sport and Movies, read from a file
    /// the app writes at launch), an Xtream source "Provider" with no login on
    /// this device, and 4 favorites. `-ui-screenshots empty` starts it with no
    /// sources. The channels load through the real `SourceLoader` and parser;
    /// nothing touches the network.
    enum UITestingScreenshots {
        static let argument = "-ui-screenshots"

        enum Scenario: String {
            case full
            case empty
        }

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes full or empty")
            }
            return scenario
        }

        /// The seeded store, or nil when the app was not launched for screenshots.
        static func container(arguments: [String] = ProcessInfo.processInfo.arguments) -> ModelContainer? {
            guard let scenario = scenario(arguments: arguments) else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                guard scenario == .full else { return container }
                let context = ModelContext(container)
                for (order, source) in try sources().enumerated() {
                    context.insert(SourceRecord(descriptor: source, sortOrder: order))
                }
                for (order, id) in favoriteIDs.enumerated() {
                    context.insert(FavoriteRecord(channelID: id, sourceID: homeID, sortOrder: order))
                }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the screenshot store: \(error)")
            }
        }

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()
        static let providerID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2") ?? UUID()
        static let favoriteIDs = ["news-one", "sport-one", "sport-two", "movies-one"]

        /// The two sources, after writing Home's playlist to a temporary file.
        static func sources() throws -> [SourceDescriptor] {
            let file = FileManager.default.temporaryDirectory.appending(path: "ui-screenshots-home.m3u")
            try Data(playlist.utf8).write(to: file)
            return [
                SourceDescriptor(id: homeID, name: "Home", kind: .m3u, url: file),
                SourceDescriptor(
                    id: providerID, name: "Provider", kind: .xtream,
                    url: URL(string: "http://provider.invalid") ?? file, credentialKey: "ui-screenshots"),
            ]
        }

        struct SeedChannel {
            let id: String
            let name: String
            let group: String
        }

        static let channels: [SeedChannel] = [
            SeedChannel(id: "news-one", name: "News One", group: "News"),
            SeedChannel(id: "world-report", name: "World Report", group: "News"),
            SeedChannel(id: "city-24", name: "City 24", group: "News"),
            SeedChannel(id: "business-now", name: "Business Now", group: "News"),
            SeedChannel(id: "sport-one", name: "Sport One", group: "Sport"),
            SeedChannel(id: "sport-two", name: "Sport Two", group: "Sport"),
            SeedChannel(id: "football-live", name: "Football Live", group: "Sport"),
            SeedChannel(id: "tennis-tv", name: "Tennis TV", group: "Sport"),
            SeedChannel(id: "movies-one", name: "Movies One", group: "Movies"),
            SeedChannel(id: "classic-cinema", name: "Classic Cinema", group: "Movies"),
            SeedChannel(id: "family-films", name: "Family Films", group: "Movies"),
            SeedChannel(id: "action-max", name: "Action Max", group: "Movies"),
        ]

        static var playlist: String {
            let entries = channels.enumerated().map { number, channel in
                let tags = "tvg-id=\"\(channel.id)\" tvg-chno=\"\(number + 1)\" group-title=\"\(channel.group)\""
                return "#EXTINF:-1 \(tags),\(channel.name)\nhttp://stream.invalid/\(channel.id).ts"
            }
            return (["#EXTM3U"] + entries).joined(separator: "\n") + "\n"
        }
    }

    #if os(tvOS)
        extension UITestingScreenshots {
            /// The shell's dependencies for a screenshot launch, or nil. Sources
            /// load through the real loader; the player is the shell tests'
            /// recording engine, since nothing here can play.
            @MainActor
            static func dependencies() -> ShellModel.Dependencies? {
                guard scenario() != nil else { return nil }
                let loader = SourceLoader()
                let defaults = UserDefaults(suiteName: "ui-screenshots") ?? .standard
                defaults.removePersistentDomain(forName: "ui-screenshots")
                return ShellModel.Dependencies(
                    engine: UITestingShell.Engine(failing: false),
                    load: { try await loader.load($0) },
                    hasLogin: { loader.hasLogin($0) },
                    recents: RecentsStore(defaults: defaults),
                    sleep: { try await Task.sleep(for: $0) },
                    guide: nil)
            }
        }
    #endif
#endif
