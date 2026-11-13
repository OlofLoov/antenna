import AntennaCore
import CloudKit
import Foundation

/// Sealed logins in the zone `LoginDrops` of the user's private CloudKit
/// database, outside SwiftData's zone
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login).
/// One `LoginDrop` record per code, named `drop-<code>`, with every field
/// in `encryptedValues`, so CloudKit encrypts the sealed box again with
/// the account's keys. The container is reached only when a method runs,
/// so making the store touches nothing. Without a container every method
/// fails with `notSignedIn` and CloudKit is never called
/// (source-management/sources-stay-on-the-device-without-icloud).
struct CloudKitLoginDrops: LoginDropping {
    static let zoneID = CKRecordZone.ID(zoneName: "LoginDrops", ownerName: CKCurrentUserDefaultName)
    static let recordType = "LoginDrop"

    /// The CloudKit container, or nil when this build cannot use CloudKit.
    var container: String? = CloudSync.container

    private func database() throws(LoginDropError) -> CKDatabase {
        guard let container else { throw .notSignedIn }
        return CKContainer(identifier: container).privateCloudDatabase
    }

    private func recordID(_ token: PairingToken) -> CKRecord.ID {
        CKRecord.ID(recordName: LoginDrops.recordName(token), zoneID: Self.zoneID)
    }

    func save(_ sealed: SealedLogin, token: PairingToken) async throws(LoginDropError) {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(token))
        record.encryptedValues["enc"] = sealed.enc
        record.encryptedValues["box"] = sealed.box
        record.encryptedValues["v"] = Int64(sealed.version)
        let database = try database()
        do {
            do {
                try await saveNew(record, in: database)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
                try await saveNew(record, in: database)
            }
        } catch {
            throw Self.map(error, for: record.recordID)
        }
    }

    /// Saves a record that must not exist yet: the server refuses a second
    /// one for the same code with `serverRecordChanged`.
    private func saveNew(_ record: CKRecord, in database: CKDatabase) async throws {
        let (saved, _) = try await database.modifyRecords(
            saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        if case .failure(let error) = saved[record.recordID] { throw error }
    }

    func fetch(token: PairingToken) async throws(LoginDropError) -> LoginDrop? {
        let database = try database()
        do {
            let record = try await database.record(for: recordID(token))
            guard let box = record.encryptedValues["box"] as? Data else { return .pickedUp }
            return .waiting(
                SealedLogin(
                    enc: record.encryptedValues["enc"] as? Data ?? Data(), box: box,
                    version: (record.encryptedValues["v"] as? Int64).map(Int.init) ?? 0))
        } catch let error as CKError where Self.isGone(error) {
            return nil
        } catch {
            throw Self.map(error, for: recordID(token))
        }
    }

    /// Removes the key and the box from the record and keeps the empty
    /// record, so a second save for the code still fails.
    func pickUp(token: PairingToken) async throws(LoginDropError) {
        let database = try database()
        do {
            let record = try await database.record(for: recordID(token))
            record.encryptedValues["enc"] = nil
            record.encryptedValues["box"] = nil
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true)
        } catch let error as CKError where Self.isGone(error) {
            return
        } catch {
            throw Self.map(error, for: recordID(token))
        }
    }

    func delete(token: PairingToken) async throws(LoginDropError) {
        let database = try database()
        do {
            _ = try await database.deleteRecord(withID: recordID(token))
        } catch let error as CKError where Self.isGone(error) {
            return
        } catch {
            throw Self.map(error, for: recordID(token))
        }
    }

    @discardableResult func sweep(olderThan cutoff: Date) async throws(LoginDropError) -> Int {
        let database = try database()
        var old: [CKRecord.ID] = []
        var token: CKServerChangeToken?
        do {
            var more = true
            while more {
                let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
                for case (let id, .success(let modification)) in changes.modificationResultsByID
                where modification.record.recordType == Self.recordType && (modification.record.creationDate ?? .distantPast) < cutoff {
                    old.append(id)
                }
                token = changes.changeToken
                more = changes.moreComing
            }
            guard !old.isEmpty else { return 0 }
            _ = try await database.modifyRecords(saving: [], deleting: old, atomically: false)
            return old.count
        } catch let error as CKError where Self.isGone(error) {
            return 0
        } catch {
            throw Self.map(error, for: nil)
        }
    }

    private static func isGone(_ error: CKError) -> Bool {
        error.code == .unknownItem || error.code == .zoneNotFound || error.code == .userDeletedZone
    }

    /// The drop error for a CloudKit error, looking inside a partial failure for `id`.
    static func map(_ error: any Error, for id: CKRecord.ID?) -> LoginDropError {
        guard let error = error as? CKError else { return .failed }
        if error.code == .partialFailure, let id, let inner = error.partialErrorsByItemID?[id] {
            return map(inner, for: nil)
        }
        switch error.code {
        case .serverRecordChanged: return .alreadyUsed
        case .networkUnavailable, .networkFailure, .serviceUnavailable: return .offline
        case .notAuthenticated, .accountTemporarilyUnavailable: return .notSignedIn
        case .quotaExceeded: return .quotaExceeded
        case .requestRateLimited, .zoneBusy: return .busy(retryAfter: error.retryAfterSeconds)
        default: return .failed
        }
    }
}

extension LoginDrops {
    /// The app's drop store: CloudKit, or the in-memory store a Debug
    /// build launched for UI tests scripts.
    @MainActor static var app: any LoginDropping {
        #if DEBUG
            if let scripted = UITestingLoginDrops.store { return scripted }
        #endif
        return CloudKitLoginDrops()
    }
}
