import CloudKit
import Foundation
import Testing

@testable import Antenna

/// When Play on and the login-drop sweep may reach CloudKit: a container in
/// the build and CloudKit's account state, whatever iCloud Drive says.
@MainActor
@Suite struct CloudAccountTests {
    /// Answers the account check with `status` and counts the calls.
    actor Answers {
        var status: CKAccountStatus?
        private(set) var calls = 0

        init(_ status: CKAccountStatus?) {
            self.status = status
        }

        func answer() -> CKAccountStatus? {
            calls += 1
            return status
        }

        func set(_ status: CKAccountStatus?) {
            self.status = status
        }
    }

    static func account(_ answers: Answers, container: String? = "iCloud.se.codecrave.antenna") -> CloudAccount {
        CloudAccount(container: container) { _ in await answers.answer() }
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: only an available account with a container runs Play on")
    func decision() {
        let container = "iCloud.se.codecrave.antenna"
        #expect(CloudAccount.available(container: container, status: .available))
        #expect(!CloudAccount.available(container: container, status: .noAccount))
        #expect(!CloudAccount.available(container: container, status: .restricted))
        #expect(!CloudAccount.available(container: container, status: .temporarilyUnavailable))
        #expect(!CloudAccount.available(container: container, status: .couldNotDetermine))
        #expect(!CloudAccount.available(container: container, status: nil))
        #expect(!CloudAccount.available(container: nil, status: .available))
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: an available account is enough, with or without iCloud Drive")
    func availableAccount() async {
        let answers = Answers(.available)
        let account = Self.account(answers)
        #expect(await account.resolve())
        #expect(await PlayOnSetup.enabled(account))
        #expect(await LoginDropSweep.enabled(account))
        // Asked once; later calls use the answer until the account changes.
        #expect(await answers.calls == 1)
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: not signed in to iCloud, no Play on")
    func noAccount() async {
        let answers = Answers(.noAccount)
        let account = Self.account(answers)
        #expect(await !account.resolve())
        #expect(await !PlayOnSetup.enabled(account))
        #expect(await !LoginDropSweep.enabled(account))
    }

    @Test("source-management/sources-stay-on-the-device-without-icloud: a build without a container never asks CloudKit")
    func noContainer() async {
        let answers = Answers(.available)
        let account = Self.account(answers, container: nil)
        #expect(await !account.resolve())
        #expect(await answers.calls == 0)
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: signing in later turns Play on on")
    func signsInLater() async {
        let answers = Answers(.noAccount)
        let account = Self.account(answers)
        #expect(await !account.resolve())
        await answers.set(.available)
        await account.refresh()
        #expect(account.available)
    }
}
