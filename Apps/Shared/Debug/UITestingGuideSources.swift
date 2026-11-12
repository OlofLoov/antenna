#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// Seed data for the Guide sources UI tests, compiled into Debug builds
    /// only (guide-sources-and-channel-mapping capability).
    ///
    /// `-ui-testing-guide-sources` starts the app on an in-memory store with
    /// one M3U source, "Sport Pack", whose playlist and guide are files the
    /// app writes at launch, so they load through the real loader, parser
    /// and guide engine with nothing on the network. Its guide covers News
    /// Now and lists "Sport One", "Sport One HD" and "Nordic One"; the
    /// playlist gives Sport One the guide id "sport1", which the guide does
    /// not list, gives Arena HD no guide id, and gives Nordic One HD none
    /// either, so it is matched by name.
    enum UITestingGuideSources {
        static let argument = "-ui-testing-guide-sources"
        static let sourceID = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1") ?? UUID()

        static func container(arguments: [String] = ProcessInfo.processInfo.arguments) -> ModelContainer? {
            guard arguments.contains(argument) else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                let folder = FileManager.default.temporaryDirectory.appending(path: "ui-testing-guide-sources")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let guide = folder.appending(path: "guide.xml")
                try Data(guideXML(now: .now).utf8).write(to: guide)
                let playlist = folder.appending(path: "playlist.m3u")
                try Data(playlistText(guide: guide).utf8).write(to: playlist)
                context.insert(
                    SourceRecord(descriptor: SourceDescriptor(id: sourceID, name: "Sport Pack", kind: .m3u, url: playlist), sortOrder: 0))
                try context.save()
                return container
            } catch {
                fatalError("Could not create the guide sources store: \(error)")
            }
        }

        static func playlistText(guide: URL) -> String {
            """
            #EXTM3U url-tvg="\(guide.absoluteString)"
            #EXTINF:-1 tvg-id="news" tvg-chno="101" group-title="Sport",News Now
            http://stream.invalid/news.ts
            #EXTINF:-1 tvg-id="sport1" tvg-chno="104" group-title="Sport",Sport One
            http://stream.invalid/sport-one.ts
            #EXTINF:-1 tvg-chno="106" group-title="Sport",Arena HD
            http://stream.invalid/arena.ts
            #EXTINF:-1 tvg-chno="301" group-title="Sport",Nordic One HD
            http://stream.invalid/nordic.ts

            """
        }

        /// One programme per entry from an hour before `now` to five hours after.
        static func guideXML(now: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMddHHmmss"
            let start = formatter.string(from: now.addingTimeInterval(-3600))
            let stop = formatter.string(from: now.addingTimeInterval(5 * 3600))
            let entries = [("news", "News Now"), ("sportone", "Sport One"), ("sport1.se", "Sport One HD"), ("nordic", "Nordic One")]
            let channels = entries.map { "<channel id=\"\($0.0)\"><display-name>\($0.1)</display-name></channel>" }
            let programmes = entries.map { id, name in
                "<programme start=\"\(start) +0000\" stop=\"\(stop) +0000\" channel=\"\(id)\"><title>Live on \(name)</title></programme>"
            }
            return "<tv>" + (channels + programmes).joined() + "</tv>"
        }
    }
#endif
