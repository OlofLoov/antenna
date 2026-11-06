import AntennaCore
import Foundation
import SwiftData
import SwiftUI
import Testing

#if os(iOS)
    import UIKit
#endif

@testable import Antenna

/// Spec 0014, app side: the Keychain mapping, the triggers and source
/// deletion. The engine itself is tested in AntennaCore.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct GuideStoreTests {
    let container: ModelContainer

    static let guide = """
        <tv><programme start="20261103180000 +0000" stop="20261103190000 +0000" channel="news.se"><title>News</title></programme></tv>
        """

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: SourceRecord.self, FavoriteRecord.self, configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func store(credentials: any CredentialStoring = HeldCredentialStore()) -> AppGuideStore {
        .live(
            container: container, session: StubURLProtocol.session(), credentials: credentials,
            directory: FileManager.default.temporaryDirectory.appending(path: "guide-tests-\(UUID().uuidString)"))
    }

    @discardableResult
    private func insert(_ kind: SourceKind, url: String, epgURL: String? = nil, credentialKey: String? = nil) throws -> SourceRecord {
        let descriptor = SourceDescriptor(
            name: url, kind: kind, url: try #require(URL(string: url)), epgURL: epgURL.flatMap(URL.init(string:)),
            credentialKey: credentialKey)
        let record = SourceRecord(descriptor: descriptor, sortOrder: (try? context.fetchCount(FetchDescriptor<SourceRecord>())) ?? 0)
        context.insert(record)
        try context.save()
        return record
    }

    private func key(_ record: SourceRecord) -> GuideKey {
        GuideKey(sourceID: record.id, epgID: "news.se")
    }

    /// Waits up to five seconds for `condition`.
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("timed out")
    }

    @Test("guide-data/login-not-on-this-device Keychain miss and failure reach the guide")
    func keychain() async throws {
        let held = HeldCredentialStore()
        let missing = try insert(.xtream, url: "http://ac1a-app-missing.test", credentialKey: "ac1a-missing")
        StubURLProtocol.register(host: "ac1a-app-missing.test", body: Self.guide)
        let guide = store(credentials: held)

        await guide.refreshIfStale(now: .now)
        try await wait { guide.loadingState(for: key(missing)) == .unavailable }
        #expect(StubURLProtocol.requests(host: "ac1a-app-missing.test").isEmpty)

        try held.save(.init(username: "alice", password: "secret"), for: "ac1a-missing")
        await guide.refreshIfStale(now: .now)
        try await wait { guide.loadingState(for: key(missing)) == .loaded }
        #expect(StubURLProtocol.requests(host: "ac1a-app-missing.test").first?.url?.path() == "/xmltv.php")

        let unreadable = try insert(.xtream, url: "http://ac1a-app-unreadable.test", credentialKey: "ac1a-unreadable")
        let failing = store(credentials: FailingCredentialStore())
        await failing.refreshIfStale(now: .now)
        try await wait { failing.loadingState(for: key(unreadable)) == .failed(.credentialUnreadable) }
        #expect(StubURLProtocol.requests(host: "ac1a-app-unreadable.test").isEmpty)
    }

    @Test("guide-data/refreshed-about-twice-a-day loading channels triggers the guide")
    func channelLoadTriggers() async throws {
        StubURLProtocol.register(
            host: "ac13-list.test",
            body: """
                #EXTM3U url-tvg="http://ac13-guide.test/guide.xml"
                #EXTINF:-1 tvg-id="news.se",News
                http://ac13-list.test/1.ts
                """)
        StubURLProtocol.register(host: "ac13-guide.test", body: Self.guide)
        let record = try insert(.m3u, url: "http://ac13-list.test/list.m3u")
        let guide = store()
        let model = ChannelListModel()

        await model.load([try #require(record.descriptor)], using: SourceLoader(session: StubURLProtocol.session()), guide: guide)

        let channel = try #require(model.channels.first)
        #expect(channel.sourceID == record.id)
        try await wait { guide.loadingState(for: channel) == .loaded }
        #expect(StubURLProtocol.requests(host: "ac13-guide.test").count == 1)
    }

    #if os(iOS)
        /// Shows `RootView` with `guide` in a window until the returned
        /// window is hidden. A hosting controller outside the app's scene
        /// never gets a scene phase, so the test sets `.active` the way the
        /// app's window does at launch.
        private func host(_ guide: AppGuideStore) throws -> UIWindow {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(
                rootView: RootView()
                    .modelContainer(container)
                    .environment(\.guideStore, guide)
                    .environment(\.sourceLoader, SourceLoader(session: StubURLProtocol.session()))
                    .environment(\.scenePhase, .active))
            window.makeKeyAndVisible()
            return window
        }

        @Test("guide-data/deleting-a-source-removes-its-guide deleting a source in the store drops its guide through RootView")
        func deletionThroughRootView() async throws {
            StubURLProtocol.register(host: "ac18-root-a.test", body: Self.guide)
            StubURLProtocol.register(host: "ac18-root-b.test", body: Self.guide)
            let doomed = try insert(.m3u, url: "http://ac18-root-a-list.test/list.m3u", epgURL: "http://ac18-root-a.test/guide.xml")
            let kept = try insert(.m3u, url: "http://ac18-root-b-list.test/list.m3u", epgURL: "http://ac18-root-b.test/guide.xml")
            let guide = store()
            let window = try host(guide)
            defer { window.isHidden = true }
            try await wait { guide.loadingState(for: key(doomed)) == .loaded && guide.loadingState(for: key(kept)) == .loaded }

            let doomedKey = key(doomed)
            context.delete(doomed)
            try context.save()

            try await wait { guide.loadingState(for: doomedKey) == .unavailable }
            #expect(guide.loadingState(for: key(kept)) == .loaded)
        }

        @Test("guide-data/refreshed-about-twice-a-day launch asks for stale guides")
        func launchTriggers() async throws {
            StubURLProtocol.register(host: "ac13-launch.test", body: Self.guide)
            try insert(.m3u, url: "http://ac13-launch-list.test/list.m3u", epgURL: "http://ac13-launch.test/guide.xml")
            let guide = store()
            let window = try host(guide)
            defer { window.isHidden = true }

            // The playlist host has no stub, so Channels loads nothing and
            // never calls the guide. Only the launch hook can ask for it.
            try await wait { !StubURLProtocol.requests(host: "ac13-launch.test").isEmpty }
            #expect(StubURLProtocol.requests(host: "ac13-launch.test").count == 1)
        }
    #endif

    @Test("guide-data/deleting-a-source-removes-its-guide a source gone from the store loses its guide")
    func deletion() async throws {
        StubURLProtocol.register(host: "ac18-a.test", body: Self.guide)
        StubURLProtocol.register(host: "ac18-b.test", body: Self.guide)
        let doomed = try insert(.m3u, url: "http://ac18-a.test/list.m3u", epgURL: "http://ac18-a.test/guide.xml")
        let kept = try insert(.m3u, url: "http://ac18-b.test/list.m3u", epgURL: "http://ac18-b.test/guide.xml")
        let guide = store()
        await guide.sourcesChanged(to: [doomed.id, kept.id])
        await guide.refreshIfStale(now: .now)
        try await wait { guide.loadingState(for: key(doomed)) == .loaded && guide.loadingState(for: key(kept)) == .loaded }

        let doomedKey = key(doomed)
        context.delete(doomed)
        try context.save()
        await guide.sourcesChanged(to: [kept.id])

        try await wait { guide.loadingState(for: doomedKey) == .unavailable }
        let start = try #require(guide.horizon?.start)
        #expect(guide.current(for: doomedKey, at: start) == nil)
        #expect(guide.loadingState(for: key(kept)) == .loaded)
    }
}
