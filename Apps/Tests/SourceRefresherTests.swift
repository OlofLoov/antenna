import AntennaCore
import Foundation
import Synchronization
import Testing

@testable import Antenna

/// The shared source loader: order, schedule, failed refreshes, sync and
/// late logins, driven through the Live model as the app runs it.
@MainActor
@Suite struct SourceRefresherTests {
    let defaults: UserDefaults
    let held = HeldCredentialStore()

    init() throws {
        let suite = "refresher-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    private static func playlist(_ host: String, _ count: Int) -> String {
        "#EXTM3U\n" + (0..<count).map { "#EXTINF:-1 group-title=\"G\",\(host) \($0)\nhttp://\(host)/\($0).ts\n" }.joined()
    }

    private static func source(_ host: String, kind: SourceKind = .m3u, key: String? = nil) throws -> SourceDescriptor {
        SourceDescriptor(name: host, kind: kind, url: try #require(URL(string: "http://\(host)/tv.m3u")), credentialKey: key)
    }

    private func refresher(tag: String, now: @escaping @MainActor () -> Date = { .now }) -> SourceRefresher {
        let loader = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: held)
        var dependencies = SourceRefresher.Dependencies.app(loader: loader, guide: nil)
        dependencies.lastLoads = LastLoadStore(defaults: defaults)
        dependencies.now = now
        return SourceRefresher(dependencies)
    }

    private func live(_ refresher: SourceRefresher, tag: String) -> LiveModel {
        let loader = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: held)
        var dependencies = LiveModel.Dependencies.live(loader: loader, guide: nil, refresher: refresher)
        dependencies.loginCheck = .seconds(3600)
        let live = LiveModel(dependencies)
        refresher.attach { [weak live] in live?.reload($0) }
        return live
    }

    // sources-and-settings/refresh-by-hand: one source at a time in the user's order.
    @Test("source-management/channels-from-all-sources-are-combined: three sources load one at a time in order")
    func oneAtATime() async throws {
        let inFlight = Mutex(0)
        let most = Mutex(0)
        let order = Mutex<[String]>([])
        var dependencies = SourceRefresher.Dependencies(
            load: { source in
                inFlight.withLock { $0 += 1 }
                most.withLock { $0 = max($0, inFlight.withLock { $0 }) }
                order.withLock { $0.append(source.name) }
                for _ in 0..<50 { await Task.yield() }
                inFlight.withLock { $0 -= 1 }
                let url = source.url
                return Playlist(channels: [Channel(id: source.name, name: source.name, streamURL: url, group: "G")])
            },
            hasLogin: { _ in true })
        dependencies.lastLoads = LastLoadStore(defaults: defaults)
        let refresher = SourceRefresher(dependencies)
        var liveDependencies = LiveModel.Dependencies.live(loader: SourceLoader(), guide: nil, refresher: refresher)
        liveDependencies.loginCheck = .seconds(3600)
        let live = LiveModel(liveDependencies)
        live.sourcesChanged([try Self.source("a.test"), try Self.source("b.test"), try Self.source("c.test")])
        await live.settled()
        #expect(most.withLock { $0 } == 1)
        #expect(order.withLock { $0 } == ["a.test", "b.test", "c.test"])
        #expect(live.channels.map(\.name) == ["a.test", "b.test", "c.test"])
        #expect(live.channels.allSatisfy { $0.sourceID != nil })
        #expect(live.catalogue.count(of: .all) == 3)
    }

    @Test("sources-and-settings/sources-refresh-on-a-schedule: only the source past its interval reloads")
    func schedule() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let tag = "schedule-\(UUID().uuidString)"
        StubURLProtocol.register(host: "old.test", body: Self.playlist("old.test", 1))
        StubURLProtocol.register(host: "fresh.test", body: Self.playlist("fresh.test", 1))
        let refresher = refresher(tag: tag) { clock }
        let live = live(refresher, tag: tag)
        let old = try Self.source("old.test")
        let fresh = try Self.source("fresh.test")
        live.sourcesChanged([old])
        await live.settled()
        clock.addTimeInterval(11 * 3600)
        live.sourcesChanged([old, fresh])
        await live.settled()
        clock.addTimeInterval(2 * 3600)

        // Only manually: nothing is due.
        #expect(refresher.due(interval: nil).isEmpty)
        // Every 12 hours: the 13-hour-old source is due, the 2-hour-old one is not.
        #expect(refresher.due(interval: .seconds(12 * 3600)) == [old.id])
        refresher.refreshDue(interval: .seconds(12 * 3600))
        await live.settled()
        #expect(StubURLProtocol.hosts(tag: tag) == ["old.test", "fresh.test", "old.test"])
        #expect(LastLoadStore(defaults: defaults).read(old.id) == clock)
    }

    @Test("sources-and-settings/a-failed-refresh-keeps-your-channels: an offline refresh keeps the channels and says why")
    func offlineRefresh() async throws {
        let tag = "offline-\(UUID().uuidString)"
        let host = "offline-refresh.test"
        StubURLProtocol.register(host: host, body: Self.playlist(host, 3))
        let refresher = refresher(tag: tag)
        let live = live(refresher, tag: tag)
        let source = try Self.source(host)
        live.sourcesChanged([source])
        await live.settled()
        let channels = live.channels
        #expect(channels.count == 3)

        StubURLProtocol.fail(host: host, with: .notConnectedToInternet)
        refresher.refresh([source.id])
        // sources-and-settings/refresh-by-hand: the channels stay while the source loads again.
        #expect(live.channels == channels)
        await live.settled()
        #expect(live.channels == channels)
        #expect(live.sources.first?.state == .loaded(channels: 3))
        let status = refresher.status(of: source.id)
        #expect(status.channels == 3)
        #expect(status.load == .failed("You're offline. Connect to the internet and try again."))
        let lines = SourceStatusText(locale: Locale(identifier: "en-US")).rowLines(status, now: .now)
        #expect(lines.last?.text == "Could not refresh: You're offline. Connect to the internet and try again.")
        StubURLProtocol.recover(host: host)
    }

    @Test("sources-and-settings/a-failed-refresh-keeps-your-channels: a broken playlist says why")
    func brokenResponse() async throws {
        let tag = "broken-\(UUID().uuidString)"
        let host = "broken.test"
        StubURLProtocol.register(host: host, status: 500, body: "")
        let refresher = refresher(tag: tag)
        let live = live(refresher, tag: tag)
        let source = try Self.source(host)
        live.sourcesChanged([source])
        await live.settled()
        #expect(
            refresher.status(of: source.id).load == .failed("The server answered with an error (500). Check the address and try again."))
    }

    // source-management/sources-sync-between-devices, this device's side
    @Test("sources-and-settings/changes-from-other-devices-show-up-by-themselves: unchanged sources keep their channels")
    func syncChanges() async throws {
        let tag = "sync-\(UUID().uuidString)"
        StubURLProtocol.register(host: "kept.test", body: Self.playlist("kept.test", 2))
        StubURLProtocol.register(host: "added.test", body: Self.playlist("added.test", 1))
        let refresher = refresher(tag: tag)
        let live = live(refresher, tag: tag)
        var kept = try Self.source("kept.test")
        live.sourcesChanged([kept])
        await live.settled()
        // Another device adds a source, renames this one and puts the new one first.
        kept.name = "Renamed"
        live.sourcesChanged([try Self.source("added.test"), kept])
        await live.settled()
        #expect(StubURLProtocol.hosts(tag: tag) == ["kept.test", "added.test"])
        #expect(live.sources.map(\.name) == ["added.test", "Renamed"])
        #expect(live.channels.map(\.name).first == "added.test 0")
        // And deletes it.
        live.sourcesChanged([try Self.source("added.test")])
        await live.settled()
        #expect(live.channels.map(\.name) == ["added.test 0"])
    }

    @Test("sources-and-settings/sign-in-on-this-apple-tv: a login that arrives later loads the source by itself")
    func lateLogin() async throws {
        let tag = "late-\(UUID().uuidString)"
        let host = "late-login.test"
        StubURLProtocol.register(host: host, action: "get_live_categories", body: #"[{"category_id":"1","category_name":"News"}]"#)
        StubURLProtocol.register(host: host, action: "get_live_streams", body: #"[{"name":"One","stream_id":1,"category_id":"1"}]"#)
        let refresher = refresher(tag: tag)
        let live = live(refresher, tag: tag)
        let key = "late-\(UUID().uuidString)"
        let source = SourceDescriptor(name: "Late", kind: .xtream, url: try #require(URL(string: "http://\(host)")), credentialKey: key)
        live.sourcesChanged([source])
        await live.settled()
        #expect(refresher.status(of: source.id).load == .waitingForLogin)
        #expect(StubURLProtocol.hosts(tag: tag).isEmpty)

        try held.save(.init(username: "anna", password: "pw"), for: key)
        live.checkLogins()
        await live.settled()
        #expect(live.channels.map(\.name) == ["One"])
        #expect(refresher.status(of: source.id).load == .loaded)
    }

    @Test("sources-and-settings/refresh-by-hand: a huge playlist loads within 10 seconds while the main actor stays free")
    func hugePlaylist() async throws {
        let tag = "huge-\(UUID().uuidString)"
        let host = "huge.test"
        StubURLProtocol.register(host: host, body: Self.playlist(host, 50_000))
        let refresher = refresher(tag: tag)
        let live = live(refresher, tag: tag)
        let start = ContinuousClock.now
        var ticks = 0
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                await Task.yield()
            }
        }
        live.sourcesChanged([try Self.source(host)])
        await live.settled()
        ticker.cancel()
        #expect(live.channels.count == 50_000)
        #expect(ContinuousClock.now - start < .seconds(10))
        #expect(ticks > 100, "the main actor was blocked while the playlist loaded")
    }
}
