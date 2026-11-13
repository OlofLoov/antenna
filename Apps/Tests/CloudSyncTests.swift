import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// A build that cannot use CloudKit keeps working on the device and never creates a CloudKit container.
@MainActor
@Suite struct CloudSyncTests {
    @Test("source-management/sources-stay-on-the-device-without-icloud: no container without the entitlement or the Info.plist value")
    func containerNeedsBoth() {
        #expect(CloudSync.container(info: "iCloud.se.codecrave.antenna", entitled: true) == "iCloud.se.codecrave.antenna")
        #expect(CloudSync.container(info: "iCloud.se.codecrave.antenna", entitled: false) == nil)
        #expect(CloudSync.container(info: nil, entitled: true) == nil)
        #expect(CloudSync.container(info: "", entitled: true) == nil)
        #expect(CloudSync.container(info: "$(ANTENNA_CLOUDKIT_CONTAINER)", entitled: true) == nil)
    }

    @Test("source-management/sources-stay-on-the-device-without-icloud: without a container the device counts as not signed in")
    func identityWithoutContainer() async {
        #expect(await CloudKitIdentity(container: nil).isSignedIn() == false)
    }

    @Test("source-management/sources-stay-on-the-device-without-icloud: without a container the login drop says not signed in")
    func dropsWithoutContainer() async {
        let drops = CloudKitLoginDrops(container: nil)
        let token = PairingToken()
        let sealed = SealedLogin(enc: Data(), box: Data(), version: 1)
        await #expect(throws: LoginDropError.notSignedIn) { try await drops.save(sealed, token: token) }
        await #expect(throws: LoginDropError.notSignedIn) { try await drops.fetch(token: token) }
        await #expect(throws: LoginDropError.notSignedIn) { try await drops.pickUp(token: token) }
        await #expect(throws: LoginDropError.notSignedIn) { try await drops.delete(token: token) }
        await #expect(throws: LoginDropError.notSignedIn) { try await drops.sweep(olderThan: .now) }
    }
}
