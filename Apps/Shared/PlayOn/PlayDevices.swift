import AntennaCore
import CloudKit
import Foundation

/// The account's devices running Antuna, one record each
/// (play-on-apple-tv/apple-tvs-on-the-same-icloud-account). Only devices
/// signed in to the account can write the private database, so this list is
/// also who may send over the network. `CloudKitPlayDevices` is the app's
/// store; `InMemoryPlayDevices` stands in for it in tests and UI tests.
protocol PlayDeviceStoring: Sendable {
    /// Writes this device's record, replacing the one it wrote before.
    func save(_ device: PlayDeviceInfo) async throws(PlayOnStoreError)
    /// Every device record in the zone.
    func all() async throws(PlayOnStoreError) -> [PlayDeviceInfo]
    /// Deletes records not seen since `cutoff` and returns how many.
    @discardableResult func sweep(notSeenSince cutoff: Date) async throws(PlayOnStoreError) -> Int
}

/// Why a Play on store did not do what was asked.
enum PlayOnStoreError: Error, Equatable, Sendable {
    /// No connection to iCloud.
    case offline
    /// This device is not signed in to iCloud, or the build has no CloudKit.
    case notSignedIn
    /// The user's iCloud storage is full.
    case quotaExceeded
    /// iCloud asked to wait.
    case busy
    /// Anything else.
    case failed

    /// The store error for a CloudKit error, looking inside a partial failure.
    static func map(_ error: any Error) -> PlayOnStoreError {
        guard let error = error as? CKError else { return .failed }
        if error.code == .partialFailure, let inner = error.partialErrorsByItemID?.values.first {
            return map(inner)
        }
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable: return .offline
        case .notAuthenticated, .accountTemporarilyUnavailable: return .notSignedIn
        case .quotaExceeded: return .quotaExceeded
        case .requestRateLimited, .zoneBusy: return .busy
        default: return .failed
        }
    }
}

/// Device records kept in memory.
actor InMemoryPlayDevices: PlayDeviceStoring {
    private var devices: [UUID: PlayDeviceInfo] = [:]
    private var failure: PlayOnStoreError?
    private let now: @Sendable () -> Date
    /// How many times `all()` ran; tests read it to see a refetch.
    private(set) var fetches = 0

    init(_ devices: [PlayDeviceInfo] = [], now: @escaping @Sendable () -> Date = { .now }) {
        self.now = now
        for device in devices { self.devices[device.id] = device }
    }

    /// Every later call throws `error`, or works again for nil.
    func fail(with error: PlayOnStoreError?) {
        failure = error
    }

    func save(_ device: PlayDeviceInfo) throws(PlayOnStoreError) {
        if let failure { throw failure }
        var saved = device
        saved.created = devices[device.id]?.created ?? device.created ?? now()
        devices[device.id] = saved
    }

    func all() throws(PlayOnStoreError) -> [PlayDeviceInfo] {
        fetches += 1
        if let failure { throw failure }
        return Array(devices.values)
    }

    @discardableResult func sweep(notSeenSince cutoff: Date) throws(PlayOnStoreError) -> Int {
        if let failure { throw failure }
        let old = devices.values.filter { $0.lastSeen < cutoff }.map(\.id)
        old.forEach { devices[$0] = nil }
        return old.count
    }
}

/// Device records in the zone `PlayDevices` of the user's private CloudKit
/// database, outside SwiftData's zone. One `PlayDevice` record per device,
/// named `device-<id>`, holding only public data. The name, public key and
/// key date are in encrypted values
/// (source-management/the-synced-library-is-in-encrypted-fields). Without a
/// container every method fails with `notSignedIn` and CloudKit is never called.
struct CloudKitPlayDevices: PlayDeviceStoring {
    static let zoneID = CKRecordZone.ID(zoneName: "PlayDevices", ownerName: CKCurrentUserDefaultName)
    static let recordType = "PlayDevice"

    /// The fields kept in `encryptedValues`.
    enum Key {
        static let name = "deviceName"
        static let publicKey = "devicePublicKey"
        static let keyDate = "deviceKeyDate"
    }

    var container: String? = CloudSync.container

    private func database() throws(PlayOnStoreError) -> CKDatabase {
        guard let container else { throw .notSignedIn }
        return CKContainer(identifier: container).privateCloudDatabase
    }

    static func recordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "device-\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    /// The record `save` writes for `device`.
    static func record(_ device: PlayDeviceInfo) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID(device.id))
        record["kind"] = device.kind.rawValue
        record.encryptedValues[Key.name] = device.name
        record.encryptedValues[Key.publicKey] = device.publicKey
        record.encryptedValues[Key.keyDate] = device.keyDate
        record["lastSeen"] = device.lastSeen
        record["version"] = Int64(device.version)
        return record
    }

    func save(_ device: PlayDeviceInfo) async throws(PlayOnStoreError) {
        let record = Self.record(device)
        let database = try database()
        do {
            do {
                try await save(record, in: database)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
                try await save(record, in: database)
            }
        } catch {
            throw .map(error)
        }
    }

    /// Only this device writes its record, so the changed keys win.
    private func save(_ record: CKRecord, in database: CKDatabase) async throws {
        let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true)
        if case .failure(let error) = saved[record.recordID] { throw error }
    }

    func all() async throws(PlayOnStoreError) -> [PlayDeviceInfo] {
        try await records().compactMap(Self.device)
    }

    @discardableResult func sweep(notSeenSince cutoff: Date) async throws(PlayOnStoreError) -> Int {
        let old = try await records().filter { ($0["lastSeen"] as? Date ?? .distantPast) < cutoff }.map(\.recordID)
        guard !old.isEmpty else { return 0 }
        do {
            _ = try await database().modifyRecords(saving: [], deleting: old, atomically: false)
        } catch let error as PlayOnStoreError {
            throw error
        } catch {
            throw .map(error)
        }
        return old.count
    }

    /// Every `PlayDevice` record, read as the login sweep reads its zone.
    private func records() async throws(PlayOnStoreError) -> [CKRecord] {
        let database = try database()
        var found: [CKRecord] = []
        var token: CKServerChangeToken?
        do {
            var more = true
            while more {
                let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
                for case (_, .success(let modification)) in changes.modificationResultsByID
                where modification.record.recordType == Self.recordType {
                    found.append(modification.record)
                }
                token = changes.changeToken
                more = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            return []
        } catch {
            throw .map(error)
        }
        return found
    }

    static func device(_ record: CKRecord) -> PlayDeviceInfo? {
        let name = record.recordID.recordName
        guard name.hasPrefix("device-"), let id = UUID(uuidString: String(name.dropFirst("device-".count))),
            let kind = (record["kind"] as? String).flatMap(PlayDeviceInfo.Kind.init(rawValue:)),
            let publicKey = record.encryptedValues[Key.publicKey] as? Data, let keyDate = record.encryptedValues[Key.keyDate] as? Date
        else { return nil }
        return PlayDeviceInfo(
            id: id, kind: kind, name: record.encryptedValues[Key.name] as? String ?? "", publicKey: publicKey, keyDate: keyDate,
            lastSeen: record["lastSeen"] as? Date ?? record.modificationDate ?? .distantPast, created: record.creationDate,
            version: (record["version"] as? Int64).map(Int.init) ?? 1)
    }
}
