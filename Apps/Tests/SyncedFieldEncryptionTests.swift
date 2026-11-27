import AntennaCore
import CloudKit
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Three synced models as they were before their fields were encrypted, to
/// write a store the current schema then opens.
enum UnencryptedSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [SourceRecord.self, ProgressRecord.self, RecentSearchRecord.self] }

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
        @Attribute(.externalStorage) var playlistData: Data?
        var fileName: String?
        var importedAt: Date?
        var playlistToken: String?
        var userAgent: String?

        init(id: UUID, name: String, url: URL) {
            self.id = id
            self.name = name
            self.url = url
        }
    }

    @Model
    final class ProgressRecord {
        var id: UUID = UUID()
        var titleID: String = ""
        var seriesID: String?
        var sourceID: UUID?
        var position: Double = 0
        var duration: Double?
        var updatedAt: Date = Date.now
        var profileID: UUID?

        init(titleID: String, sourceID: UUID, position: Double) {
            self.titleID = titleID
            self.sourceID = sourceID
            self.position = position
        }
    }

    @Model
    final class RecentSearchRecord {
        var id: UUID = UUID()
        var query: String = ""
        var updatedAt: Date = Date.now
        var profileID: UUID?

        init(query: String) {
            self.query = query
        }
    }
}

@MainActor
@Suite struct SyncedFieldEncryptionTests {
    @Test("source-management/the-synced-library-is-in-encrypted-fields: every synced field is marked for CloudKit encryption")
    func everyFieldEncrypted() {
        let schema = Schema(AntennaSchema.models)
        #expect(schema.entities.count == AntennaSchema.models.count)
        for entity in schema.entities {
            #expect(!entity.attributes.isEmpty, "\(entity.name)")
            #expect(entity.relationships.isEmpty, "\(entity.name)")
            for attribute in entity.attributes {
                #expect(attribute.options.contains(.allowsCloudEncryption), "\(entity.name).\(attribute.name)")
            }
        }
        let source = schema.entitiesByName["SourceRecord"]?.attributesByName["playlistData"]
        #expect(source?.options.contains(.externalStorage) == true)
    }

    @Test("source-management/the-synced-library-is-in-encrypted-fields: a store from before the encrypted fields opens with its records")
    func storeFromEarlierVersionOpens() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "encryption-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "store.sqlite")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: UnencryptedSchema.self)
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
            let link = try #require(URL(string: "http://example.com/list.m3u"))
            old.mainContext.insert(UnencryptedSchema.SourceRecord(id: id, name: "Home", url: link))
            old.mainContext.insert(UnencryptedSchema.ProgressRecord(titleID: "example.com/movie/7", sourceID: id, position: 640))
            old.mainContext.insert(UnencryptedSchema.RecentSearchRecord(query: "news"))
            try old.mainContext.save()
        }
        let schema = Schema(AntennaSchema.models)
        let current = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none))
        let context = current.mainContext
        let source = try #require(try context.fetch(FetchDescriptor<Antenna.SourceRecord>()).first)
        #expect(source.id == id)
        #expect(source.name == "Home")
        #expect(source.descriptor?.url.host() == "example.com")
        let sourceID: UUID? = id
        let progress = try context.fetch(FetchDescriptor<Antenna.ProgressRecord>(predicate: #Predicate { $0.sourceID == sourceID }))
        #expect(progress.map(\.position) == [640])
        #expect(try context.fetch(FetchDescriptor<Antenna.RecentSearchRecord>()).map(\.query) == ["news"])
    }

    @Test("source-management/the-synced-library-is-in-encrypted-fields: an Apple TV's name and key are in encrypted values")
    func playDeviceRecord() throws {
        let device = PlayDeviceInfo(
            id: UUID(), kind: .tv, name: "Living Room", publicKey: Data([4, 1, 2, 3]),
            keyDate: Date(timeIntervalSince1970: 1_000), lastSeen: Date(timeIntervalSince1970: 2_000))
        let record = CloudKitPlayDevices.record(device)
        #expect(Set(record.allKeys()).isDisjoint(with: ["name", "publicKey", "keyDate"]))
        #expect(record.encryptedValues[CloudKitPlayDevices.Key.name] as? String == "Living Room")
        #expect(record.encryptedValues[CloudKitPlayDevices.Key.publicKey] as? Data == device.publicKey)
        #expect(record.encryptedValues[CloudKitPlayDevices.Key.keyDate] as? Date == device.keyDate)
        let read = try #require(CloudKitPlayDevices.device(record))
        #expect(read.name == "Living Room")
        #expect(read.publicKey == device.publicKey)
        #expect(read.keyDate == device.keyDate)
        #expect(read.kind == .tv)
    }
}
