import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The source record as it was before file sources, to write a store the
/// current schema then opens.
enum SourceSchemaBeforeFiles: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SourceRecord.self] }

    @Model
    final class SourceRecord {
        var id: UUID = UUID()
        var name: String = ""
        var kindRaw: String = "m3u"
        var url: URL?
        var epgURL: URL?
        var credentialKey: String?
        var sortOrder: Int = 0
        var createdAt: Date = Date.now
        var lastRefreshedAt: Date?

        init(id: UUID, name: String, url: URL) {
            self.id = id
            self.name = name
            self.url = url
        }
    }
}

@MainActor
@Suite struct SourceRecordMigrationTests {
    @Test("local-m3u-file-import/channels-reach-apple-tv: a store from before file sources opens with the new fields empty")
    func lightweightMigration() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "store.sqlite")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: SourceSchemaBeforeFiles.self)
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
            old.mainContext.insert(
                SourceSchemaBeforeFiles.SourceRecord(id: id, name: "Home", url: try #require(URL(string: "http://example.com/list.m3u"))))
            try old.mainContext.save()
        }
        let schema = Schema(AntennaSchema.models)
        let current = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
        let records = try current.mainContext.fetch(FetchDescriptor<Antenna.SourceRecord>())
        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.id == id)
        #expect(record.kind == .m3u)
        #expect(record.playlistData == nil)
        #expect(record.fileName == nil)
        #expect(record.importedAt == nil)
        #expect(record.descriptor?.url.host() == "example.com")
    }

    @Test("local-m3u-file-import/channels-reach-apple-tv: a file source record from a newer version still has a descriptor")
    func fileSourceDescriptor() throws {
        let descriptor = SourceDescriptor(name: "Home", kind: .m3uFile, url: URL(fileURLWithPath: "/"))
        let record = SourceRecord(descriptor: descriptor)
        record.url = nil
        record.importedAt = Date(timeIntervalSince1970: 10)
        let first = try #require(record.descriptor)
        #expect(first.url.scheme == "antenna-file")
        record.importedAt = Date(timeIntervalSince1970: 20)
        #expect(!first.loadsLike(try #require(record.descriptor)))
    }
}
