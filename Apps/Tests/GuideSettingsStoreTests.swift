import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Guide settings as they are stored: one record per source, the Keychain
/// for links with a login, and removal with the source.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct GuideSettingsStoreTests {
    let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func records() throws -> [GuideSettingsRecord] {
        try context.fetch(FetchDescriptor<GuideSettingsRecord>())
    }

    @Test("guide-sources-and-channel-mapping/settings-follow-you-to-every-device duplicates merge into one record")
    func duplicates() throws {
        let source = UUID()
        var phone = GuideSettings()
        _ = phone.setMatch("news", for: "a", at: .now, present: [])
        var tablet = GuideSettings()
        _ = tablet.setMatch("sport", for: "b", at: .now, present: [])
        context.insert(GuideSettingsRecord(sourceID: source, payload: try JSONEncoder().encode(phone)))
        context.insert(GuideSettingsRecord(sourceID: source, payload: try JSONEncoder().encode(tablet)))
        context.insert(GuideSettingsRecord(sourceID: source, payload: Data("not json".utf8)))
        try context.save()

        #expect(GuideSettingsStore.settings(for: source, in: context).activeMatches == ["a": "news", "b": "sport"])
        GuideSettingsStore.update(source, in: context) { settings in
            settings.setEnabled(false, for: .provider, at: .now)
            return true
        }
        let kept = try records()
        #expect(kept.count == 2)
        #expect(kept.contains { $0.settings == nil })
        let merged = try #require(kept.compactMap(\.settings).first)
        #expect(merged.activeMatches == ["a": "news", "b": "sport"])
        #expect(merged.flags["provider"]?.enabled == false)
    }

    @Test(
        "guide-sources-and-channel-mapping/passwords-in-guide-links-stay-private the login stays in the Keychain and out of the guide rows")
    func privateLink() async throws {
        let credentials = HeldCredentialStore()
        let descriptor = SourceDescriptor(
            name: "Sport Pack", kind: .m3u, url: try #require(URL(string: "http://gss-private-list.test/list.m3u")))
        let source = SourceRecord(descriptor: descriptor, sortOrder: 0)
        context.insert(source)
        try context.save()
        let link = try #require(URL(string: "http://alice7:s3cr3t@gss-private.test/epg/all.xml.gz?key=abc123"))
        let stored = GuideLinkInput.storage(for: link, at: .now)
        try GuideSettingsStore.saveLink(link, sourceID: source.id, linkID: "l1", credentials: credentials)
        GuideSettingsStore.update(source.id, in: context) { $0.addLink(stored.link, id: "l1") }

        let payload = try #require(try records().first?.payload)
        let text = String(decoding: payload, as: UTF8.self)
        for secret in ["alice7", "s3cr3t", "abc123", "epg/all"] { #expect(!text.contains(secret)) }
        #expect(GuideSettingsStore.link(source.id, "l1", credentials: credentials) == link)

        StubURLProtocol.register(host: "gss-private.test", body: GuideStoreTests.guide)
        let guide = AppGuideStore.live(
            container: container, session: StubURLProtocol.session(), credentials: credentials,
            directory: FileManager.default.temporaryDirectory.appending(path: "guide-settings-\(UUID().uuidString)"))
        await guide.refreshIfStale(now: .now)
        let deadline = ContinuousClock.now + .seconds(20)
        while guide.statuses[source.id]?.rows.first?.address == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        let address = try #require(guide.statuses[source.id]?.rows.first?.address)
        #expect(address == "http://gss-private.test/….gz?key=…")

        await SourceRemoval(credentials: credentials, guide: guide).delete(source, in: context)
        #expect(try records().isEmpty)
        #expect(GuideSettingsStore.link(source.id, "l1", credentials: credentials) == nil)
    }
}
