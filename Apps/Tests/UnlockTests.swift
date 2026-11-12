import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The window root's unlock over a stand-in provider.
@MainActor
@Suite struct UnlockTests {
    let grant = Grant(kind: .lifetime, verifiedAt: Date(timeIntervalSince1970: 1_800_000_000))

    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 where !done() { await Task.yield() }
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a lapse waits for a return; a restore keeps all")
    func lapseAndRestore() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        let url = try #require(URL(string: "https://example.com/list.m3u"))
        container.mainContext.insert(
            SourceRecord(descriptor: SourceDescriptor(name: "Home", kind: .m3u, url: url, credentialKey: "home"), sortOrder: 0))
        container.mainContext.insert(FavoriteRecord(channelID: "news", sourceID: nil, sortOrder: 0))
        try container.mainContext.save()

        let (unlock, provider) = Unlock.fixed(.entitled(grant)) { ScriptedPaywallStore() }
        let running = Task { await unlock.run() }
        await settle { false }
        #expect(unlock.gate.route(holdsPaywall: false) == .app)

        await provider.set(.notEntitled(.revoked))
        await settle { unlock.gate.latest != .entitled(grant) }
        #expect(unlock.gate.route(holdsPaywall: false) == .app, "still open until the user returns")
        unlock.activate()
        #expect(unlock.gate.route(holdsPaywall: false) == .paywall)

        await unlock.purchased([PurchaseEvidence(kind: .lifetime)])
        await settle { unlock.gate.applied.isUnlocked }
        #expect(unlock.gate.route(holdsPaywall: false) == .app)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SourceRecord>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FavoriteRecord>()) == 1)
        running.cancel()
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in UI tests and the test host open unlocked")
    func testingDefault() throws {
        let unlock = try #require(UITestingPaywall.unlock(arguments: ["-ui-testing-live", "channels"], environment: [:]))
        #expect(unlock.gate.route(holdsPaywall: false) == .app)
        let locked = try #require(UITestingPaywall.unlock(arguments: ["-antenna.entitlement", "locked"], environment: [:]))
        #expect(locked.gate.route(holdsPaywall: false) == .paywall)
        #expect(UITestingPaywall.unlock(arguments: [], environment: [:]) == nil, "a normal launch reads StoreKit")
    }
}
