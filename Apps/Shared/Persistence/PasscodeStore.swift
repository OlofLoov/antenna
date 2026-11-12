import AntennaCore
import CryptoKit
import Foundation
import SwiftData

/// The group passcode's check value, synced so a passcode set on a phone
/// locks the Apple TV too (group-management/lock-a-group-with-a-passcode).
/// It holds a random salt and an HMAC of the four digits under it, never
/// the digits. Four digits are 10 000 values, so anyone who can read the
/// store can find them; the check value only keeps them off the record.
/// Duplicates keep the earliest `createdAt`; the rest are deleted.
@Model
final class PasscodeRecord {
    var id: UUID = UUID()
    var salt: Data?
    var verifier: Data?
    var createdAt: Date = Date.now
    /// When the passcode was last set or changed, on any device.
    var changedAt: Date = Date.now

    init(salt: Data, verifier: Data, now: Date) {
        self.salt = salt
        self.verifier = verifier
        createdAt = now
        changedAt = now
    }

    var isValid: Bool { salt?.isEmpty == false && verifier?.isEmpty == false }

    /// What this device remembers about the passcode it last set or
    /// entered, to tell when another device changed it.
    var token: String { "\(id.uuidString).\(changedAt.timeIntervalSinceReferenceDate)" }
}

/// Sets, changes and checks the passcode. The digits never leave memory:
/// they are not stored, synced or logged.
@MainActor
enum PasscodeStore {
    /// Four ASCII digits, the only passcodes accepted.
    nonisolated static func isWellFormed(_ digits: String) -> Bool {
        digits.count == 4 && digits.unicodeScalars.allSatisfy { ("0"..."9").contains($0) }
    }

    /// The passcode in effect: the earliest valid record.
    static func current(_ records: [PasscodeRecord]) -> PasscodeRecord? {
        records.filter(\.isValid).min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// True when `digits` match the passcode in effect.
    static func matches(_ digits: String, _ records: [PasscodeRecord]) -> Bool {
        guard let record = current(records), let salt = record.salt, let verifier = record.verifier else { return false }
        return check(digits, salt: salt) == verifier
    }

    /// Stores `digits` as the passcode, in the record in effect or a new
    /// one, and deletes duplicates. Returns the record, or nil for digits
    /// that are not four digits.
    @discardableResult
    static func set(_ digits: String, in context: ModelContext, now: Date = .now) -> PasscodeRecord? {
        guard isWellFormed(digits) else { return nil }
        let records = (try? context.fetch(FetchDescriptor<PasscodeRecord>())) ?? []
        guard let fresh = record(for: digits, now: now) else { return nil }
        let record: PasscodeRecord
        if let existing = current(records) {
            existing.salt = fresh.salt
            existing.verifier = fresh.verifier
            existing.changedAt = now
            record = existing
        } else {
            record = fresh
            context.insert(record)
        }
        records.filter { $0.persistentModelID != record.persistentModelID }.forEach(context.delete)
        try? context.save()
        return record
    }

    /// A new, unsaved record for `digits` with a fresh salt; nil for digits
    /// that are not four digits.
    nonisolated static func record(for digits: String, now: Date) -> PasscodeRecord? {
        guard isWellFormed(digits) else { return nil }
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        return PasscodeRecord(salt: salt, verifier: check(digits, salt: salt), now: now)
    }

    /// Deletes every record but the one in effect, as when two offline
    /// devices each set a first passcode.
    static func resolve(in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<PasscodeRecord>())) ?? []
        guard let winner = current(records) else { return }
        let losers = records.filter { $0.persistentModelID != winner.persistentModelID }
        guard !losers.isEmpty else { return }
        losers.forEach(context.delete)
        try? context.save()
    }

    private nonisolated static func check(_ digits: String, salt: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(digits.utf8), using: SymmetricKey(data: salt)))
    }
}
