import AntennaCore
import CloudKit
import Foundation

/// Sealed logins in the zone `LoginDrops` of the user's private CloudKit
/// database, outside SwiftData's zone
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login).
/// One `LoginDrop` record per code, named `drop-<code>`, with every field
/// in `encryptedValues`, so CloudKit encrypts the sealed box again with
/// the account's keys. The container is reached only when a method runs,
/// so making the store touches nothing.
struct CloudKitLoginDrops: LoginDropping {
    static let zoneID = CKRecordZone.ID(zoneName: "LoginDrops", ownerName: CKCurrentUserDefaultName)
    static let recordType = "LoginDrop"
    static let containerIdentifier = "iCloud.se.codecrave.antenna"

    private var database: CKDatabase {
        CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
    }

    private func recordID(_ token: PairingToken) -> CKRecord.ID {
        CKRecord.ID(recordName: LoginDrops.recordName(token), zoneID: Self.zoneID)
    }

    func save(_ sealed: SealedLogin, token: PairingToken) async throws(LoginDropError) {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(token))
        record.encryptedValues["enc"] = sealed.enc
        record.encryptedValues["box"] = sealed.box
        record.encryptedValues["v"] = Int64(sealed.version)
        do {
            do {
                try await saveNew(record)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
                try await saveNew(record)
            }
        } catch {
            throw Self.map(error, for: record.recordID)
        }
    }

    /// Saves a record that must not exist yet: the server refuses a second
    /// one for the same code with `serverRecordChanged`.
    private func saveNew(_ record: CKRecord) async throws {
        let (saved, _) = try await database.modifyRecords(
            saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        if case .failure(let error) = saved[record.recordID] { throw error }
    }

    func fetch(token: PairingToken) async throws(LoginDropError) -> SealedLogin? {
        do {
            let record = try await database.record(for: recordID(token))
            return SealedLogin(
                enc: record.encryptedValues["enc"] as? Data ?? Data(), box: record.encryptedValues["box"] as? Data ?? Data(),
                version: (record.encryptedValues["v"] as? Int64).map(Int.init) ?? 0)
        } catch let error as CKError where Self.isGone(error) {
            return nil
        } catch {
            throw Self.map(error, for: recordID(token))
        }
    }

    func delete(token: PairingToken) async throws(LoginDropError) {
        do {
            _ = try await database.deleteRecord(withID: recordID(token))
        } catch let error as CKError where Self.isGone(error) {
            return
        } catch {
            throw Self.map(error, for: recordID(token))
        }
    }

    @discardableResult func sweep(olderThan cutoff: Date) async throws(LoginDropError) -> Int {
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
