import AntennaCore
import Foundation
import SwiftData
import SwiftUI
import Testing

#if os(iOS)
    import UIKit
#endif

@testable import Antenna

/// Where the app opens: onboarding with no source, the app with one.
@MainActor
@Suite struct OnboardingRoutingTests {
    let container: ModelContainer
    let store = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private func insert(_ kind: SourceKind, url: String, credentialKey: String? = nil) throws {
        let descriptor = SourceDescriptor(name: "Source", kind: kind, url: try #require(URL(string: url)), credentialKey: credentialKey)
        container.mainContext.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        try container.mainContext.save()
    }

    private func route() throws -> OnboardingRoute {
        OnboardingRoute(sourceCount: try container.mainContext.fetchCount(FetchDescriptor<SourceRecord>()))
    }

    @Test("first-run-onboarding/a-new-user-is-asked-for-a-provider: no source opens onboarding")
    func noSourceOpensOnboarding() throws {
        #expect(try route() == .welcome)
    }

    @Test("first-run-onboarding/a-returning-user-goes-straight-to-their-channels: a playlist opens the app")
    func playlistOpensTheApp() throws {
        try insert(.m3u, url: "http://routing.test/list.m3u")
        #expect(try route() == .app)
    }

    // An Xtream source whose password has not reached this device still opens
    // the app, and Live says it is waiting for the password.
    @Test("first-run-onboarding/a-returning-user-goes-straight-to-their-channels: a password still in iCloud opens Live, waiting")
    func waitingForPasswordOpensLive() async throws {
        try insert(.xtream, url: "http://routing-xtream.test", credentialKey: "absent-\(UUID().uuidString)")
        #expect(try route() == .app)

        let loader = SourceLoader(session: StubURLProtocol.session(), credentials: store)
        let live = LiveModel(.live(loader: loader, guide: nil))
        let records = try container.mainContext.fetch(FetchDescriptor<SourceRecord>())
        live.sourcesChanged(records.compactMap(\.descriptor))
        await live.settled()
        #expect(live.sources.map(\.state) == [.waitingForLogin])
        #expect(StubURLProtocol.requests(host: "routing-xtream.test").isEmpty)
    }

    // A source that loaded nothing keeps the app open; only deleting every
    // source returns to onboarding.
    @Test("first-run-onboarding/a-returning-user-goes-straight-to-their-channels: a source with no channels opens the app")
    func sourceWithNoChannelsOpensTheApp() throws {
        try insert(.m3u, url: "http://routing-empty.test/list.m3u")
        #expect(try route() == .app)
        for record in try container.mainContext.fetch(FetchDescriptor<SourceRecord>()) {
            SourceRecord.delete(record, from: container.mainContext, credentials: store)
        }
        #expect(try route() == .welcome)
    }

    #if os(iOS)
        // Onboarding on screen contacts no server; once a source exists the
        // app replaces it and loads, so the zero is not vacuous.
        @Test("first-run-onboarding/a-new-user-is-asked-for-a-provider: onboarding makes no request")
        func onboardingMakesNoRequest() async throws {
            let tag = "onboarding-\(UUID().uuidString)"
            let loader = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: store)
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(
                rootView: OnboardingGate { RootView() }.modelContainer(container).environment(\.sourceLoader, loader))
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            try await Task.sleep(for: .seconds(1))
            #expect(StubURLProtocol.requestCount(tag: tag) == 0)

            try insert(.m3u, url: "http://onboarding-gate.test/list.m3u")
            for _ in 0..<50 where StubURLProtocol.requestCount(tag: tag) == 0 {
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect(StubURLProtocol.requestCount(tag: tag) > 0)
        }
    #endif
}
