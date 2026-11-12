import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// A clock the tests move by hand.
@MainActor
final class LockClock {
    var now = Date(timeIntervalSinceReferenceDate: 2_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

/// The passcode and the locks against an in-memory store, a scratch
/// `UserDefaults` suite and a hand-moved clock.
@MainActor
@Suite struct GroupLocksTests {
    let container: ModelContainer
    let defaults: UserDefaults
    let clock = LockClock()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        defaults = try #require(UserDefaults(suiteName: "GroupLocksTests-\(UUID().uuidString)"))
    }

    private var context: ModelContext { container.mainContext }
    private var records: [PasscodeRecord] { (try? context.fetch(FetchDescriptor<PasscodeRecord>())) ?? [] }

    private func locks() -> GroupLocks {
        let clock = clock
        return GroupLocks(defaults: defaults, now: { clock.now })
    }

    @Test("group-management/lock-a-group-with-a-passcode only a salted check value is stored, never the digits")
    func firstPasscode() throws {
        #expect(PasscodeStore.set("12a4", in: context) == nil)
        let record = try #require(PasscodeStore.set("2580", in: context))
        let salt = try #require(record.salt)
        let verifier = try #require(record.verifier)
        #expect(salt.count == 16 && verifier.count == 32)
        #expect(!salt.contains(Data("2580".utf8)) && !verifier.contains(Data("2580".utf8)))
        #expect(PasscodeStore.matches("2580", records))
        #expect(!PasscodeStore.matches("2581", records))

        let again = try #require(PasscodeStore.set("2580", in: context))
        #expect(again.salt != salt)
        #expect(records.count == 1)
    }

    @Test("group-management/lock-a-group-with-a-passcode two offline first passcodes: the earlier wins and the other device is told")
    func twoDevices() throws {
        let locks = locks()
        let mine = try #require(PasscodeStore.set("1111", in: context, now: clock.now))
        locks.remember(mine)
        #expect(!locks.changedElsewhere(records))
        let theirs = PasscodeRecord(salt: Data(repeating: 1, count: 16), verifier: Data(repeating: 2, count: 32), now: .distantPast)
        context.insert(theirs)
        try context.save()
        #expect(PasscodeStore.current(records)?.id == theirs.id)
        #expect(locks.changedElsewhere(records))
        PasscodeStore.resolve(in: context)
        #expect(records.map(\.id) == [theirs.id])
    }

    @Test("group-management/guessing-the-passcode-is-slow wrong entries wait, and the wait survives a relaunch")
    func lockout() throws {
        try #require(PasscodeStore.set("2580", in: context))
        let locks = locks()
        for _ in 0..<4 { #expect(locks.enter("0000", records: records) == .wrong) }
        #expect(locks.enter("0000", records: records) == .waiting(30))
        #expect(locks.enter("2580", records: records) == .waiting(30))
        #expect(!locks.isOpen)

        clock.advance(10)
        let relaunched = self.locks()
        #expect(relaunched.waitRemaining == 20)
        #expect(relaunched.enter("2580", records: records) == .waiting(20))
        clock.advance(20)
        #expect(relaunched.enter("2580", records: records) == .right)
        #expect(relaunched.isOpen && relaunched.waitRemaining == 0)
        #expect(self.locks().lockout == PasscodeLockout())
    }

    @Test("group-management/unlock-with-the-passcode with no passcode on this device yet the prompt waits for iCloud")
    func noPasscodeYet() {
        #expect(locks().enter("2580", records: records) == .noPasscode)
    }

    @Test("group-management/locks-close-again-on-their-own Lock now, a relaunch, the background and idle time close the locks")
    func closing() throws {
        try #require(PasscodeStore.set("2580", in: context))
        let locks = locks()
        #expect(locks.enter("2580", records: records) == .right)
        locks.close()
        #expect(!locks.isOpen)
        #expect(!self.locks().isOpen)

        locks.open()
        locks.wentToBackground()
        clock.advance(GroupLocks.idleLimit - 1)
        locks.becameActive()
        #expect(locks.isOpen)
        locks.wentToBackground()
        clock.advance(GroupLocks.idleLimit)
        locks.becameActive()
        #expect(!locks.isOpen)

        locks.open()
        clock.advance(GroupLocks.idleLimit - 1)
        locks.touched()
        clock.advance(GroupLocks.idleLimit - 1)
        locks.checkIdle()
        #expect(locks.isOpen)
        clock.advance(1)
        locks.checkIdle()
        #expect(!locks.isOpen)
    }

    @Test("group-management/locked-channels-stay-out-of-reach the catalogue shows locked channels only while the locks are open")
    func rulesFollowLocks() throws {
        let source = UUID()
        let channels = Channel.tagged(
            [Channel(id: "1", name: "Film", streamURL: URL(filePath: "/1"), group: "Movies", number: 1)], sourceID: source)
        GroupStore.setLocked(.named(source, "Movies"), true, in: context)
        func catalogue(open: Bool) throws -> Catalogue<PersistentIdentifier> {
            let rules = GroupStore.rules(
                groups: try context.fetch(FetchDescriptor<GroupRecord>()), members: [], hidden: [], profile: Profile.mainID,
                locksOpen: open)
            return .shell(channels: channels, favorites: [], rules: rules)
        }
        #expect(try catalogue(open: false).count(of: .all) == 0)
        #expect(try catalogue(open: true).count(of: .all) == 1)
    }
}
