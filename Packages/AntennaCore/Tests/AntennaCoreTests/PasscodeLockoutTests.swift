import Foundation
import Testing

@testable import AntennaCore

@Suite struct PasscodeLockoutTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("group-management/guessing-the-passcode-is-slow five wrong entries wait 30 seconds, each run doubles up to five minutes")
    func waits() {
        var lockout = PasscodeLockout()
        var now = start
        var waits: [TimeInterval] = []
        for _ in 0..<6 {
            for _ in 0..<4 { lockout.wrong(at: now) }
            #expect(lockout.remaining(at: now) == 0)
            lockout.wrong(at: now)
            let wait = lockout.remaining(at: now)
            waits.append(wait)
            lockout.wrong(at: now.addingTimeInterval(1))
            #expect(lockout.remaining(at: now.addingTimeInterval(1)) == wait - 1)
            now = now.addingTimeInterval(wait)
        }
        #expect(waits == [30, 60, 120, 240, 300, 300])
    }

    @Test("group-management/guessing-the-passcode-is-slow the wait survives a relaunch and the right passcode clears it")
    func survives() {
        var lockout = PasscodeLockout()
        for _ in 0..<5 { lockout.wrong(at: start) }
        var reopened = PasscodeLockout(data: lockout.data)
        #expect(reopened.remaining(at: start.addingTimeInterval(10)) == 20)
        reopened.right()
        #expect(reopened == PasscodeLockout())
        #expect(PasscodeLockout(data: Data("junk".utf8)) == PasscodeLockout())
    }
}
