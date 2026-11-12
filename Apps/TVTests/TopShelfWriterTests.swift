import AntennaCore
import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import AntennaTV

/// A store that keeps what is written in memory, and fails while told to.
final class FakeTopShelfStore: TopShelfStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshotData: Data?
    private var files: [String: Data] = [:]
    private var failing = false
    private var attempts = 0

    var attempted: Int { lock.withLock { attempts } }
    var tiles: [String: Data] { lock.withLock { files } }

    func fail(_ value: Bool) { lock.withLock { failing = value } }

    func read() -> TopShelfSnapshot? { TopShelfSnapshot(data: lock.withLock { snapshotData }) }

    func tileURL(_ file: String) -> URL? { lock.withLock { files[file] == nil ? nil : URL(fileURLWithPath: "/\(file)") } }

    func write(snapshot: Data, tiles: [String: Data]) throws(TopShelfFolder.Failure) {
        let failed = lock.withLock {
            attempts += 1
            guard !failing else { return true }
            snapshotData = snapshot
            files = tiles
            return false
        }
        if failed { throw .writeFailed }
    }
}

@MainActor
@Suite struct TopShelfWriterTests {
    let clock = ManualClock()
    let source = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func writer(
        _ store: any TopShelfStoring, programmes: [[Programme]] = [], changed: @escaping @MainActor () -> Void = {}
    ) -> TopShelfWriter {
        TopShelfWriter(
            .init(
                store: store, sleep: clock.sleep, now: { [now] in now },
                programmes: { channels, _ in channels.indices.map { $0 < programmes.count ? programmes[$0] : [] } },
                logo: { _ in nil }, poster: { _ in nil }, contentChanged: changed))
    }

    private func channel(_ id: String, _ name: String) -> Channel {
        Channel.tagged(
            [
                Channel(
                    id: id, name: name, streamURL: URL(fileURLWithPath: "/\(id)"),
                    logoURL: URL(string: "http://user:secret@logos.example/\(id).png"))
            ], sourceID: source)[0]
    }

    private func inputs(_ names: [String], loading: Bool = false) -> TopShelfInputs {
        TopShelfInputs(favorites: names.map { channel($0, $0.uppercased()) }, unresolvedFavorites: 0, titles: [], loading: loading)
    }

    /// Lets the writer's tasks run until `condition` holds or the attempts run out.
    private func until(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    @Test("top-shelf/no-passwords-or-links-leave-the-app the files written hold no link, identity, username or password")
    func noSecretsInFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "topshelf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let m3u = channel("http://user:secret@iptv.example/live/user/secret/7.ts", "Sport One")
        let movie = ShelfTitle(
            id: "xtream#iptv.example#vod#9", kind: .movie, sourceID: source, name: "Dune",
            posterURL: URL(string: "http://iptv.example/images/user/secret/9.jpg"))
        let progress = WatchProgress(id: "p", titleID: movie.id, sourceID: source, position: 30, duration: 100, updatedAt: now)
        let match = Programme(channelID: "sport", start: now.addingTimeInterval(-60), stop: now.addingTimeInterval(60), title: "Match")
        var changes = 0
        let writer = writer(TopShelfFolder(directory: directory), programmes: [[match]]) { changes += 1 }
        writer.update(
            TopShelfInputs(
                favorites: [m3u], unresolvedFavorites: 0,
                titles: [.init(item: .init(title: movie, progress: progress, isNextEpisode: false), detail: nil)], loading: false))
        await writer.flush()
        #expect(writer.written == 1)
        #expect(changes == 1, "the system is told the shelf changed")
        let files = try FileManager.default.subpathsOfDirectory(atPath: directory.path)
        #expect(files.contains("snapshot.json"))
        #expect(files.contains("empty.png"))
        #expect(files.filter { $0.hasPrefix("tiles/") && $0.hasSuffix(".png") }.count == 2)
        for file in files where !file.hasSuffix("tiles") {
            let text = String(decoding: try Data(contentsOf: directory.appending(path: file)), as: UTF8.self).lowercased()
            for secret in ["://", "secret", "user", "iptv.example", "logos.example", "xtream#", source.uuidString.lowercased()] {
                #expect(!text.contains(secret), "\(file) holds \(secret)")
            }
        }
        let shelf = try #require(TopShelfFolder(directory: directory).read())
        #expect(shelf.favorites.map(\.name) == ["Sport One"])
        #expect(shelf.favorites.first?.programmes.map(\.title) == ["Match"])
        #expect(shelf.titles.map(\.title) == ["Dune"])
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app changes batch into one write 30 seconds after the first")
    func batching() async {
        let store = FakeTopShelfStore()
        let writer = writer(store)
        writer.update(inputs(["a"]))
        await until { clock.pending == 1 }
        clock.advance(by: .seconds(20))
        writer.update(inputs(["a", "b"]))
        #expect(clock.pending == 1, "a later change does not start another window")
        clock.advance(by: .seconds(9))
        await until { false }
        #expect(store.attempted == 0)
        clock.advance(by: .seconds(1))
        await until { writer.written == 1 }
        #expect(writer.written == 1)
        #expect(store.read()?.favorites.map(\.name) == ["A", "B"], "the latest change is written")
        #expect(clock.requested == [.seconds(30)])
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app nothing is written while a source loads, and leaving the app writes at once")
    func loadingAndFlush() async {
        let store = FakeTopShelfStore()
        let writer = writer(store)
        writer.update(inputs(["a"], loading: true))
        await until { clock.pending == 1 }
        clock.advance(by: .seconds(30))
        await until { false }
        #expect(store.attempted == 0, "first launch: the shelf stays blank until sources load")
        await writer.flush()
        #expect(store.attempted == 0)
        writer.update(inputs(["a"]))
        await writer.flush()
        #expect(writer.written == 1, "a change made just before going to the background is written")
        #expect(store.read()?.favorites.count == 1)
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app the guide is written again every six hours while the app is open")
    func sixHours() async {
        let store = FakeTopShelfStore()
        let writer = writer(store)
        writer.update(inputs(["a"]))
        await until { clock.pending == 1 }
        clock.advance(by: .seconds(30))
        await until { writer.written == 1 }
        let refresh = Task { await writer.refreshPeriodically() }
        defer { refresh.cancel() }
        await until { clock.pending == 1 }
        clock.advance(by: .seconds(6 * 60 * 60))
        await until { clock.pending == 2 }
        #expect(clock.requested.sorted() == [.seconds(30), .seconds(30), .seconds(6 * 60 * 60), .seconds(6 * 60 * 60)])
        clock.advance(by: .seconds(30))
        await until { writer.written == 2 }
        #expect(writer.written == 2)
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app a failed write keeps the previous shelf and the next change tries again")
    func failedWrite() async {
        let store = FakeTopShelfStore()
        let writer = writer(store)
        writer.update(inputs(["a"]))
        await writer.flush()
        store.fail(true)
        writer.update(inputs(["a", "b"]))
        await writer.flush()
        #expect(store.attempted == 2)
        #expect(store.read()?.favorites.map(\.name) == ["A"], "the previous shelf stays")
        store.fail(false)
        writer.update(inputs(["a", "b", "c"]))
        await writer.flush()
        #expect(store.read()?.favorites.map(\.name) == ["A", "B", "C"])
    }

    @Test("top-shelf/an-empty-shelf-says-how-to-fill-it a lapsed unlock clears the summary to the add-favorites tile")
    func clearOnLapse() async throws {
        let store = FakeTopShelfStore()
        let writer = writer(store)
        writer.update(inputs(["a"]))
        await writer.flush()
        var changes = 0
        await TopShelfWriter.clear(store, now: now) { changes += 1 }
        #expect(changes == 1)
        let content = TopShelfContent.make(from: store.read(), now: now)
        guard case .empty(let item) = content else {
            Issue.record("expected the add-favorites tile, got \(String(describing: content))")
            return
        }
        #expect(item.link == .empty)
        #expect(store.tiles.keys.sorted() == ["empty.png"], "the favorites' tiles are gone")
    }

    @Test("top-shelf/the-shelf-shows-the-current-profile the snapshot holds the current profile's favorites only")
    func currentProfile() throws {
        let schema = Schema(AntennaSchema.models)
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let channels = [channel("dad", "Dad TV"), channel("kids", "Kids TV")]
        let kids = UUID()
        context.insert(FavoriteRecord(channelID: "dad", sourceID: source, sortOrder: 0, profileID: nil))
        context.insert(FavoriteRecord(channelID: "kids", sourceID: source, sortOrder: 0, profileID: kids))
        let records = try context.fetch(FetchDescriptor<FavoriteRecord>())
        let loaded = [ShellSource(id: source, name: "S", state: .loaded(channels: 2))]
        for (profile, expected) in [(kids, ["Kids TV"]), (Profile.mainID, ["Dad TV"])] {
            let gathered = TopShelfInputs.gather(
                catalogue: .shell(channels: channels, favorites: records, profile: profile), sources: loaded, continueWatching: [],
                episodes: [:])
            #expect(gathered.favorites.map(\.name) == expected)
            let snapshot = TopShelfSnapshot(
                favorites: gathered.favorites.map { .init(channel: $0, programmes: []) }, titles: [],
                unresolvedFavorites: gathered.unresolvedFavorites, now: now)
            #expect(snapshot.favorites.map(\.name) == expected)
        }
    }

    @Test("top-shelf/favorites-show-what-is-on-now favorites from a source waiting for its login are left off and counted")
    func waitingForLogin() {
        let waiting = UUID()
        let catalogue = Catalogue<PersistentIdentifier>(
            channels: [channel("a", "A")], groupOrder: [:],
            favorites: [
                FavoriteSnapshot(channelID: "a", sourceID: source, sortOrder: 0),
                FavoriteSnapshot(channelID: "b", sourceID: waiting, sortOrder: 1),
            ])
        let sources = [
            ShellSource(id: source, name: "S", state: .loaded(channels: 1)), ShellSource(id: waiting, name: "W", state: .waitingForLogin),
        ]
        let gathered = TopShelfInputs.gather(catalogue: catalogue, sources: sources, continueWatching: [], episodes: [:])
        #expect(gathered.favorites.map(\.name) == ["A"])
        #expect(gathered.unresolvedFavorites == 1)
        #expect(!gathered.loading)
    }
}
