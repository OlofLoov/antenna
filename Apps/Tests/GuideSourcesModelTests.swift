import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The Guide sources screen's actions against a real guide store with a
/// stubbed network.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct GuideSourcesModelTests {
    let container: ModelContainer
    let credentials = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private static func guide(_ ids: [String], title: String) -> String {
        let channels = ids.map { "<channel id=\"\($0)\"><display-name>\($0)</display-name></channel>" }.joined()
        let now = Date.now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let start = formatter.string(from: now.addingTimeInterval(-3600))
        let stop = formatter.string(from: now.addingTimeInterval(3600))
        let programmes = ids.map {
            "<programme start=\"\(start) +0000\" stop=\"\(stop) +0000\" channel=\"\($0)\"><title>\(title)</title></programme>"
        }
        return "<tv>\(channels)\(programmes.joined())</tv>"
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(20)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        if !condition() { Issue.record("timed out") }
    }

    private struct Setup {
        var store: AppGuideStore
        var model: GuideSourcesModel
        var record: SourceRecord
        var channel: Channel
    }

    /// An M3U source with a saved link at `<host>-saved.test` and a channel
    /// "x" both that guide and `extra`'s guide cover.
    private func setup(_ host: String) async throws -> Setup {
        StubURLProtocol.register(host: "\(host)-saved.test", body: Self.guide(["x", "only-saved"], title: "From saved"))
        let descriptor = SourceDescriptor(
            name: "Sport Pack", kind: .m3u, url: try #require(URL(string: "http://\(host)-list.test/list.m3u")),
            epgURL: URL(string: "http://\(host)-saved.test/guide.xml"))
        let record = SourceRecord(descriptor: descriptor, sortOrder: 0)
        context.insert(record)
        try context.save()
        let store = AppGuideStore.live(
            container: container, session: StubURLProtocol.session(), credentials: credentials,
            directory: FileManager.default.temporaryDirectory.appending(path: "guide-sources-\(UUID().uuidString)"))
        let channel = Channel(id: "m3u.x", name: "X", streamURL: URL(filePath: "/x"), epgID: "x", sourceID: record.id)
        await store.register(epgURLs: [], for: record.id)
        await store.update(channels: [channel])
        await store.refreshIfStale(now: .now)
        let model = GuideSourcesModel(
            sourceID: record.id, source: "Sport Pack", kind: .m3u, store: store, context: context, credentials: credentials)
        try await wait { store.index.current(for: GuideKey(sourceID: record.id, epgID: "x"), at: .now) != nil }
        return Setup(store: store, model: model, record: record, channel: channel)
    }

    private func title(_ setup: Setup, _ id: String) -> String? {
        setup.store.index.current(for: GuideKey(sourceID: setup.record.id, epgID: id), at: .now)?.title
    }

    @Test("guide-sources-and-channel-mapping/turn-off-or-remove-a-guide turning off, then removing an added guide")
    func turnOffAndRemove() async throws {
        let setup = try await setup("gsm-off")
        StubURLProtocol.register(host: "gsm-off-added.test", body: Self.guide(["x"], title: "From added"))
        let problem = await setup.model.add("http://gsm-off-added.test/epg/all.xml?token=abc123")
        #expect(problem == nil)
        try await wait { setup.model.status.rows.count == 2 && setup.model.status.rows.last?.hasGuide == true }
        #expect(title(setup, "x") == "From saved")

        let saved = try #require(setup.model.status.rows.first)
        #expect(!saved.reference.isRemovable)
        setup.model.toggle(saved)
        try await wait { title(setup, "x") == "From added" }
        #expect(title(setup, "only-saved") == nil)
        #expect(setup.model.status.rows.first?.status == .off)

        let added = try #require(setup.model.status.rows.last?.reference)
        #expect(added.isRemovable)
        setup.model.remove(added)
        try await wait { setup.model.status.rows.count == 1 }
        #expect(title(setup, "x") == nil)
        guard case .added(let id) = added else { return }
        #expect(GuideSettingsStore.link(setup.record.id, id, credentials: credentials) == nil)
    }

    @Test("guide-sources-and-channel-mapping/undo-a-hand-picked-match removing a match goes back to the playlist's id")
    func undoMatch() async throws {
        let setup = try await setup("gsm-undo")
        let entry = try #require(setup.store.index.entries(sourceID: setup.record.id).first { $0.id == "only-saved" })
        #expect(setup.model.pick(entry, for: setup.channel))
        try await wait { setup.store.key(for: setup.channel)?.epgID == "only-saved" }
        #expect(setup.store.index.match(for: setup.channel)?.origin == .user)

        setup.model.removeMatch(for: setup.channel)
        try await wait { setup.store.key(for: setup.channel)?.epgID == "x" }
        #expect(setup.store.index.match(for: setup.channel) == nil)
    }

    @Test("guide-sources-and-channel-mapping/add-a-guide-link a repeated link is refused")
    func duplicate() async throws {
        let setup = try await setup("gsm-dup")
        #expect(await setup.model.add("http://gsm-dup-saved.test/guide.xml") == .duplicate)
        #expect(await setup.model.add("nonsense") == .invalid)
    }
}
