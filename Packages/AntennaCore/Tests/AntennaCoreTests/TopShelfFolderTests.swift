import Foundation
import Testing

@testable import AntennaCore

@Suite struct TopShelfFolderTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "topshelf-\(UUID().uuidString)")
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(_ names: [String]) throws -> TopShelfSnapshot {
        let channels = names.map {
            Channel(id: $0, name: $0, streamURL: URL(fileURLWithPath: "/\($0)"), sourceID: sourceA)
        }
        return TopShelfSnapshot(
            favorites: channels.map { .init(channel: $0, programmes: []) }, titles: [], unresolvedFavorites: 0, now: now)
    }

    private func tiles(_ snapshot: TopShelfSnapshot) -> [String: Data] {
        var files = Dictionary(uniqueKeysWithValues: snapshot.favorites.map { ($0.tileFile, Data($0.name.utf8)) })
        files[TopShelfSnapshot.emptyTileFile] = Data("empty".utf8)
        return files
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app a write replaces the snapshot and deletes tiles no longer listed")
    func writeAndRead() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = TopShelfFolder(directory: directory)
        #expect(folder.read() == nil, "nothing written gives a blank shelf")
        let first = try snapshot(["a", "b"])
        try folder.write(snapshot: try first.encoded(), tiles: tiles(first))
        #expect(folder.read() == first)
        let gone = try #require(first.favorites.last).tileFile
        #expect(folder.tileURL(gone) != nil)
        let second = try snapshot(["a"])
        try folder.write(snapshot: try second.encoded(), tiles: tiles(second))
        #expect(folder.read() == second)
        #expect(folder.tileURL(gone) == nil)
        #expect(folder.tileURL(try #require(second.favorites.first).tileFile) != nil)
        #expect(folder.tileURL(TopShelfSnapshot.emptyTileFile) != nil)
        #expect(folder.tileURL("../snapshot.json") == nil)
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app a folder that cannot be created fails and leaves nothing half written")
    func unavailable() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory)
        let folder = TopShelfFolder(directory: directory.appending(path: "inside"))
        let value = try snapshot(["a"])
        #expect(throws: TopShelfFolder.Failure.unavailable) {
            try folder.write(snapshot: try value.encoded(), tiles: tiles(value))
        }
        #expect(folder.read() == nil)
    }
}
