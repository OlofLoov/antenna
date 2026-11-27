import AntennaCore
import CloudKit
import Foundation

/// Requests waiting in iCloud for a TV that was not reachable on the
/// network (play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable).
/// One per TV: a new request replaces the waiting one. `CloudKitPlayRequests`
/// is the app's store; `InMemoryPlayRequests` stands in for it in tests and
/// UI tests.
protocol PlayRequestQueueing: Sendable {
    /// Keeps `request` for its target TV, replacing any request waiting there.
    func save(_ request: PlayRequest) async throws(PlayOnStoreError)
    /// The request waiting for the TV with `target` as its id, or nil.
    func waiting(for target: UUID) async throws(PlayOnStoreError) -> PlayRequest?
    /// Deletes `request` if it is still the one waiting for its TV; a newer
    /// one stays. Deleting one that is gone is not an error.
    func delete(_ request: PlayRequest) async throws(PlayOnStoreError)
    /// Deletes every request past its expiry at `now` and returns how many
    /// (play-on-apple-tv/requests-expire-and-leave-no-trace).
    @discardableResult func sweep(now: Date) async throws(PlayOnStoreError) -> Int
}

/// Requests kept in memory, one per TV.
actor InMemoryPlayRequests: PlayRequestQueueing {
    private var requests: [UUID: PlayRequest] = [:]
    private var failure: PlayOnStoreError?

    init(_ requests: [PlayRequest] = [], failure: PlayOnStoreError? = nil) {
        for request in requests { self.requests[request.target] = request }
        self.failure = failure
    }

    /// Every later call throws `error`, or works again for nil.
    func fail(with error: PlayOnStoreError?) {
        failure = error
    }

    /// Every request kept, for tests.
    var all: [PlayRequest] { Array(requests.values) }

    func save(_ request: PlayRequest) throws(PlayOnStoreError) {
        if let failure { throw failure }
        requests[request.target] = request
    }

    func waiting(for target: UUID) throws(PlayOnStoreError) -> PlayRequest? {
        if let failure { throw failure }
        return requests[target]
    }

    func delete(_ request: PlayRequest) throws(PlayOnStoreError) {
        if let failure { throw failure }
        if requests[request.target]?.id == request.id { requests[request.target] = nil }
    }

    @discardableResult func sweep(now: Date) throws(PlayOnStoreError) -> Int {
        if let failure { throw failure }
        let old = requests.filter { $0.value.isExpired(at: now) }.map(\.key)
        old.forEach { requests[$0] = nil }
        return old.count
    }
}

/// Requests in the zone `PlayRequests` of the user's private CloudKit
/// database, outside SwiftData's zone. One `PlayRequest` record per TV,
/// named `request-<TV id>`, with the encoded request in `encryptedValues`
/// and its expiry beside it, so a new request replaces the waiting one.
/// Without a container every method fails with `notSignedIn` and CloudKit
/// is never called.
struct CloudKitPlayRequests: PlayRequestQueueing {
    static let zoneID = CKRecordZone.ID(zoneName: "PlayRequests", ownerName: CKCurrentUserDefaultName)
    static let recordType = "PlayRequest"
    static let subscriptionID = "play-requests"

    var container: String? = CloudSync.container

    private func database() throws(PlayOnStoreError) -> CKDatabase {
        guard let container else { throw .notSignedIn }
        return CKContainer(identifier: container).privateCloudDatabase
    }

    static func recordID(_ target: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "request-\(target.uuidString.lowercased())", zoneID: zoneID)
    }

    func save(_ request: PlayRequest) async throws(PlayOnStoreError) {
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(request.target))
        do {
            record.encryptedValues["payload"] = try request.encoded()
        } catch {
            throw .failed
        }
        record["expires"] = request.expires
        let database = try database()
        do {
            do {
                try await replace(record, in: database)
            } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
                _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
                try await replace(record, in: database)
            }
        } catch {
            throw .map(error)
        }
    }

    /// Writes every key, so the new request replaces the one waiting.
    private func replace(_ record: CKRecord, in database: CKDatabase) async throws {
        let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
        if case .failure(let error) = saved[record.recordID] { throw error }
    }

    func waiting(for target: UUID) async throws(PlayOnStoreError) -> PlayRequest? {
        let database = try database()
        do {
            return Self.request(try await database.record(for: Self.recordID(target)))
        } catch let error as CKError where Self.isGone(error) {
            return nil
        } catch {
            throw .map(error)
        }
    }

    func delete(_ request: PlayRequest) async throws(PlayOnStoreError) {
        let database = try database()
        let id = Self.recordID(request.target)
        do {
            let record = try await database.record(for: id)
            guard Self.request(record)?.id == request.id else { return }
            _ = try await database.deleteRecord(withID: id)
        } catch let error as CKError where Self.isGone(error) {
            return
        } catch {
            throw .map(error)
        }
    }

    @discardableResult func sweep(now: Date) async throws(PlayOnStoreError) -> Int {
        let database = try database()
        var old: [CKRecord.ID] = []
        var token: CKServerChangeToken?
        do {
            var more = true
            while more {
                let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
                for case (let id, .success(let modification)) in changes.modificationResultsByID
                where Self.isExpired(modification.record, at: now) {
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
            throw .map(error)
        }
    }

    /// Asks iCloud for a silent push when the zone changes. The zone is
    /// made first, since a subscription needs it.
    func subscribe() async throws(PlayOnStoreError) {
        let database = try database()
        let subscription = CKRecordZoneSubscription(zoneID: Self.zoneID, subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
            _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
        } catch {
            throw .map(error)
        }
    }

    /// True for a request record past its expiry at `now`.
    private static func isExpired(_ record: CKRecord, at now: Date) -> Bool {
        record.recordType == recordType && (record["expires"] as? Date ?? .distantPast) <= now
    }

    private static func isGone(_ error: CKError) -> Bool {
        error.code == .unknownItem || error.code == .zoneNotFound || error.code == .userDeletedZone
    }

    /// The request a record holds; nil for one this build cannot read.
    static func request(_ record: CKRecord) -> PlayRequest? {
        guard let payload = record.encryptedValues["payload"] as? Data else { return nil }
        return try? PlayRequest(decoding: payload)
    }
}
