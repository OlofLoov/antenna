import Foundation
import Testing

@testable import AntennaCore

/// Sources, logins and a clock that a test changes while an engine runs.
final class GuideWorld: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSources: [GuideSourceDescriptor] = []
    private var storedCredentials: [String: GuideCredentialLookup] = [:]
    private var storedNow = guideTime(19)
    let log = Recorder<String>()
    let directory = temporaryGuideDirectory()

    var sources: [GuideSourceDescriptor] {
        get { lock.withLock { storedSources } }
        set { lock.withLock { storedSources = newValue } }
    }
    var now: Date {
        get { lock.withLock { storedNow } }
        set { lock.withLock { storedNow = newValue } }
    }
    func setCredential(_ lookup: GuideCredentialLookup, for key: String) {
        lock.withLock { storedCredentials[key] = lookup }
    }
    func credential(_ key: String) -> GuideCredentialLookup {
        lock.withLock { storedCredentials[key] ?? .missing }
    }

    /// Adds a source whose guide is at `http://<host>/guide.xml`, or an Xtream
    /// source at `http://<host>` when `kind` is `.xtream` and `link` is false.
    @discardableResult
    func add(_ kind: SourceKind = .m3u, host: String, link: Bool = true, order: Int? = nil) -> GuideSourceDescriptor {
        let server = URL(filePath: "/").settingHTTP(host: host)
        let source = GuideSourceDescriptor(
            sourceID: UUID(), kind: kind, url: server,
            epgURL: link ? server.appending(path: "guide.xml") : nil,
            credentialKey: kind == .xtream ? "key-\(host)" : nil, sortOrder: order ?? sources.count)
        sources.append(source)
        return source
    }

    func engine(limits: GuideLimits = .platform) -> GuideEngine {
        GuideEngine(
            GuideEngine.Configuration(
                session: GuideStubProtocol.session(), directory: directory, limits: limits,
                sources: { [self] in sources }, credential: { [self] in credential($0) },
                log: { [log] in log.append($0) }, now: { [self] in now }, chunkSize: 1024))
    }
}

extension URL {
    /// `http://<host>`.
    func settingHTTP(host: String) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        return components.url ?? self
    }
}

/// Collects every event a progress stream yields.
final class ProgressTap: Sendable {
    let events = Recorder<GuideProgress>()
    private let task: Task<Void, Never>

    init(_ stream: AsyncStream<GuideProgress>) {
        let events = events
        task = Task {
            for await event in stream { events.append(event) }
        }
    }

    deinit { task.cancel() }

    /// Waits up to five seconds for `condition` to hold over the events so far.
    func wait(until condition: ([GuideProgress]) -> Bool) async throws {
        for _ in 0..<1000 {
            if condition(events.all) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("timed out waiting for progress; got \(events.all)")
    }

    func of(_ source: GuideSourceDescriptor) -> [GuideProgress] {
        events.all.filter { $0.sourceID == source.sourceID }
    }
}

func isLoaded(_ event: GuideProgress) -> Bool {
    if case .loaded = event { return true }
    return false
}

func isFailed(_ event: GuideProgress) -> Bool {
    if case .failed = event { return true }
    return false
}

@Suite(.timeLimit(.minutes(1))) struct GuideEngineTests {
    private func key(_ source: GuideSourceDescriptor, _ id: String = "news.se") -> GuideKey {
        GuideKey(sourceID: source.sourceID, epgID: id)
    }

    /// Sends 3 KB of a guide and never ends the response, so a load stays in
    /// flight after reporting progress.
    private func serveStalled(_ host: String) {
        GuideStubProtocol.register(host: host, body: GuideFetcherTests.xml(programmes: 60).prefix(3000), finish: false)
    }

    /// True once the stub saw the request stopped, checked for two seconds:
    /// far less than the session's 30 s timeout, so only a cancel passes.
    private func stoppedQuickly(_ host: String) async throws -> Bool {
        for _ in 0..<80 {
            if GuideStubProtocol.wasStopped(host: host) { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    private func serveGuide(_ host: String) throws {
        GuideStubProtocol.register(host: host, body: try guideFixture("guide.xmltv"))
    }

    @Test("0014/AC-1a missing login waits, unreadable login fails")
    func credentials() async throws {
        let world = GuideWorld()
        let missing = world.add(.xtream, host: "ac1a-missing.panel", link: false)
        let unreadable = world.add(.xtream, host: "ac1a-unreadable.panel", link: false)
        world.setCredential(.unreadable, for: "key-ac1a-unreadable.panel")
        try serveGuide("ac1a-missing.panel")
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())

        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        try await Task.sleep(for: .milliseconds(50))

        #expect(tap.of(missing) == [.failed(sourceID: missing.sourceID, .credentialMissing)])
        #expect(tap.of(unreadable) == [.failed(sourceID: unreadable.sourceID, .credentialUnreadable)])
        #expect(GuideStubProtocol.requests(host: "ac1a-missing.panel").isEmpty)
        #expect(GuideStubProtocol.requests(host: "ac1a-unreadable.panel").isEmpty)
        #expect(await engine.index.loadingState(for: key(missing)) == .unavailable)
        #expect(await engine.index.loadingState(for: key(unreadable)) == .failed(.credentialUnreadable))

        world.setCredential(.found(username: "alice", password: "p&w"), for: "key-ac1a-missing.panel")
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        let request = try #require(GuideStubProtocol.requests(host: "ac1a-missing.panel").first)
        #expect(request.url?.path() == "/xmltv.php")
        #expect(await engine.index.loadingState(for: key(missing)) == .loaded)
    }

    @Test("0014/AC-11 state before the first load")
    func statesBeforeLoad() async throws {
        let world = GuideWorld()
        let unregistered = world.add(.m3u, host: "ac11-unregistered.epg", link: false)
        let emptyPlaylist = world.add(.m3u, host: "ac11-empty.epg", link: false)
        let stalker = world.add(.stalker, host: "ac11-stalker.portal", link: false)
        let broken = world.add(.m3u, host: "ac11-broken.epg")
        GuideStubProtocol.register(host: "ac11-broken.epg", .http(status: 500, chunks: []))
        let engine = world.engine()

        #expect(await engine.index.loadingState(for: key(broken)) == .loading)
        await engine.register(epgURLs: [], for: emptyPlaylist.sourceID)
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        let index = await engine.index
        #expect(index.loadingState(for: key(unregistered)) == .loading)
        #expect(GuideStubProtocol.requests(host: "ac11-unregistered.epg").isEmpty)
        #expect(index.loadingState(for: key(emptyPlaylist)) == .unavailable)
        #expect(index.loadingState(for: key(stalker)) == .unavailable)
        #expect(index.loadingState(for: key(broken)) == .failed(.httpStatus(500)))
    }

    @Test("0014/AC-11 state holds through failed refreshes")
    func stickyState() async throws {
        let world = GuideWorld()
        let source = world.add(host: "ac11-sticky.epg")
        try serveGuide("ac11-sticky.epg")
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())
        await engine.refresh(sourceID: source.sourceID)
        await engine.idle()
        #expect(await engine.index.loadingState(for: key(source)) == .loaded)
        #expect(await engine.index.loadingState(for: key(source, "nothing.se")) == .noData)

        for failure in [GuideStubProtocol.Reply.http(status: 500, chunks: []), .failure(.notConnectedToInternet)] {
            GuideStubProtocol.register(host: "ac11-sticky.epg", failure)
            await engine.refresh(sourceID: source.sourceID)
            await engine.idle()
            let index = await engine.index
            #expect(index.loadingState(for: key(source)) == .loaded)
            #expect(index.loadingState(for: key(source, "nothing.se")) == .noData)
            #expect(index.current(for: key(source), at: guideTime(18, 30))?.title == "Evening News")
        }
        try await tap.wait { $0.filter(isFailed).count == 2 }
        #expect(
            tap.of(source).filter(isFailed) == [
                .failed(sourceID: source.sourceID, .httpStatus(500)), .failed(sourceID: source.sourceID, .offline),
            ])
    }

    @Test("0014/AC-13 only stale or missing guides download")
    func staleness() async throws {
        let world = GuideWorld()
        let stale = world.add(host: "ac13-stale.epg")
        let fresh = world.add(host: "ac13-fresh.epg")
        let edge = world.add(host: "ac13-edge.epg")
        let missing = world.add(host: "ac13-missing.epg")
        for host in ["ac13-stale.epg", "ac13-fresh.epg", "ac13-edge.epg", "ac13-missing.epg"] { try serveGuide(host) }
        let engine = world.engine()
        let launch = guideTime(30)

        for (source, age) in [(stale, 13.0), (fresh, 1.0), (edge, 12.0)] {
            world.now = launch.addingTimeInterval(-age * 3600)
            await engine.refresh(sourceID: source.sourceID)
            await engine.idle()
        }
        world.now = launch
        await engine.refreshIfStale(now: launch)
        await engine.refreshIfStale(now: launch)
        await engine.idle()

        #expect(GuideStubProtocol.requests(host: "ac13-stale.epg").count == 2)
        #expect(GuideStubProtocol.requests(host: "ac13-fresh.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "ac13-edge.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "ac13-missing.epg").count == 1)

        await engine.refresh(sourceID: fresh.sourceID)
        await engine.idle()
        #expect(GuideStubProtocol.requests(host: "ac13-fresh.epg").count == 2)
        _ = missing
    }

    @Test("0014/AC-13 explicit refresh restarts")
    func restart() async throws {
        let world = GuideWorld()
        let source = world.add(host: "ac13-restart.epg")
        serveStalled("ac13-restart.epg")
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())

        await engine.refresh(sourceID: source.sourceID)
        try await tap.wait { !$0.isEmpty }
        try serveGuide("ac13-restart.epg")
        await engine.refresh(sourceID: source.sourceID)
        #expect(try await stoppedQuickly("ac13-restart.epg"))
        await engine.idle()

        #expect(GuideStubProtocol.requests(host: "ac13-restart.epg").count == 2)
        try await tap.wait { $0.contains(where: isLoaded) }
        #expect(!tap.events.all.contains(where: isFailed))
        #expect(await engine.index.loadingState(for: key(source)) == .loaded)
    }

    @Test("0014/AC-13 no sources, no requests")
    func noSources() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        try await Task.sleep(for: .milliseconds(50))
        #expect(tap.events.all.isEmpty)
        #expect(world.log.all.isEmpty)
    }

    @Test("0014/AC-18 removing a source mid-load")
    func removeMidLoad() async throws {
        let world = GuideWorld()
        let doomed = world.add(host: "ac18-mid.epg")
        let other = world.add(host: "ac18-mid-other.epg")
        serveStalled("ac18-mid.epg")
        try serveGuide("ac18-mid-other.epg")
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())

        await engine.refresh(sourceID: doomed.sourceID)
        try await tap.wait { !$0.isEmpty }
        let heardBefore = tap.of(doomed)
        await engine.remove(sourceID: doomed.sourceID)
        #expect(try await stoppedQuickly("ac18-mid.epg"))
        world.sources.removeAll { $0.sourceID == doomed.sourceID }
        await engine.refresh(sourceID: other.sourceID)
        await engine.idle()
        try await tap.wait { $0.contains(where: isLoaded) }

        #expect(tap.of(doomed) == heardBefore)
        #expect(await engine.index.loadingState(for: key(doomed)) == .unavailable)
        let late = ProgressTap(engine.progressStream())
        try await late.wait { !$0.isEmpty }
        #expect(late.events.all.allSatisfy { $0.sourceID == other.sourceID })
    }

    @Test("0014/AC-18 removing a loaded source")
    func removeLoaded() async throws {
        let world = GuideWorld()
        let doomed = world.add(host: "ac18-loaded.epg")
        let other = world.add(host: "ac18-loaded-other.epg")
        try serveGuide("ac18-loaded.epg")
        GuideStubProtocol.register(
            host: "ac18-loaded-other.epg",
            body: Data(
                """
                <tv><programme start="20261103200000 +0000" stop="20261103210000 +0000" channel="news.se"><title>Late</title></programme></tv>
                """.utf8))
        let engine = world.engine()
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        #expect(await engine.index.horizon == DateInterval(start: guideTime(18), end: guideTime(25)))

        await engine.remove(sourceID: doomed.sourceID)
        let index = await engine.index
        #expect(index.horizon == DateInterval(start: guideTime(20), end: guideTime(21)))
        #expect(index.current(for: key(doomed), at: guideTime(18, 30)) == nil)
        #expect(index.loadingState(for: key(doomed)) == .unavailable)
        #expect(index.current(for: key(other), at: guideTime(20, 30))?.title == "Late")

        let late = ProgressTap(engine.progressStream())
        try await late.wait { !$0.isEmpty }
        try await Task.sleep(for: .milliseconds(50))
        #expect(late.of(doomed).isEmpty)
    }

    @Test("0014/AC-13 a removed source that comes back is loaded again")
    func readded() async throws {
        let world = GuideWorld()
        let source = world.add(host: "ac13-readded.epg")
        try serveGuide("ac13-readded.epg")
        let engine = world.engine()
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        await engine.remove(sourceID: source.sourceID)
        #expect(await engine.index.loadingState(for: key(source)) == .unavailable)

        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        #expect(GuideStubProtocol.requests(host: "ac13-readded.epg").count == 2)
        #expect(await engine.index.loadingState(for: key(source)) == .loaded)
    }

    @Test func leftoverDownloadFileIsDeleted() async throws {
        let world = GuideWorld()
        let source = world.add(host: "relaunch.epg")
        try FileManager.default.createDirectory(at: world.directory, withIntermediateDirectories: true)
        let partial = world.directory.appending(path: "\(source.sourceID.uuidString).download")
        try Data("<tv><programme".utf8).write(to: partial)
        try serveGuide("relaunch.epg")

        let engine = world.engine()
        #expect(!FileManager.default.fileExists(atPath: partial.path()))
        #expect(await engine.index.loadingState(for: key(source)) == .loading)
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        let request = try #require(GuideStubProtocol.requests(host: "relaunch.epg").first)
        #expect(request.value(forHTTPHeaderField: "Range") == nil)
    }
}
