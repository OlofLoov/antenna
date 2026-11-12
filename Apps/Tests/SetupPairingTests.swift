import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The Apple TV's QR card as a model: the iCloud state, the store check,
/// arrivals, the hint and Connect on the TV, against an in-memory store,
/// stubbed servers and a scripted clock. The model runs the same on every
/// platform; only the Apple TV shows it.
@MainActor
@Suite struct SetupPairingTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let identity = FixedICloudIdentity(signedIn: true)
    let activity = NoSetupActivity()
    let clock = Clock()
    let tag = "setup-\(UUID().uuidString)"

    final class Clock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        StubURLProtocol.register(
            host: "setup-playlist.test",
            body: "#EXTM3U\n#EXTINF:-1 group-title=\"News\",News One\nhttp://setup-playlist.test/one.ts\n")
        StubURLProtocol.register(
            host: "setup-xtream.test", body: #"{"user_info":{"username":"anna","status":"Active","max_connections":"1","auth":1}}"#)
    }

    private var context: ModelContext { container.mainContext }

    private func sources() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<SourceRecord>())
    }

    private func pairing() -> SetupPairingModel {
        var dependencies = SetupPairingModel.Dependencies(identity: identity, activity: activity)
        dependencies.now = { [clock] in clock.now }
        return SetupPairingModel(dependencies)
    }

    /// Onboarding on the details step with the QR card running, as the screen wires it.
    private func onboarding() async -> (OnboardingModel, SetupPairingModel) {
        let model = OnboardingModel(
            connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held), clipboard: nil)
        model.setupDependencies = SourceSetup.Dependencies(
            channels: { connection in
                guard case .playlist(let playlist) = connection.reply else { return Playlist(channels: []) }
                return playlist
            },
            library: { _ in SourceSetup.Library(movies: 0, series: 0) }, guide: nil)
        let pairing = pairing()
        model.pairing = pairing
        pairing.onArrival = { source in Task { await model.received(source) } }
        await pairing.start(in: context)
        return (model, pairing)
    }

    /// A source as iCloud would deliver it, created `seconds` after now.
    @discardableResult
    private func send(_ kind: String, name: String, url: String?, after seconds: TimeInterval = 5) throws -> SourceRecord {
        let record = SourceRecord(
            descriptor: SourceDescriptor(id: UUID(), name: name, kind: .m3u, url: URL(fileURLWithPath: "/")))
        record.kindRaw = kind
        record.url = url.flatMap(URL.init(string:))
        record.createdAt = clock.now.addingTimeInterval(seconds)
        context.insert(record)
        try context.save()
        return record
    }

    /// Waits for the arrival handed to onboarding to settle.
    private func settle(_ model: OnboardingModel) async {
        for _ in 0..<200 where model.connecting || (model.setups.isEmpty && model.arrival == nil && model.error == nil) {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        for setup in model.setups { await setup.finished() }
    }

    @Test("iphone-as-setup-device/the-apple-tv-offers-a-qr-code: signed in, the card shows a link and offers Handoff")
    func showsCodeWhenSignedIn() async {
        let (model, pairing) = await onboarding()
        let link = try? #require(pairing.link)
        #expect(activity.current == link)
        #expect(model.holdsApp)
        #expect(link.map { SetupLink(userInfo: $0.userInfo) == $0 } == true)
    }

    @Test("iphone-as-setup-device/no-icloud-no-qr-code: not signed in, the keyboard card and no Handoff")
    func keyboardCardWhenSignedOut() async {
        identity.signedIn = false
        let (model, pairing) = await onboarding()
        #expect(pairing.card == .keyboard)
        #expect(pairing.link == nil)
        #expect(activity.offered.isEmpty)
        #expect(!model.holdsApp)
    }

    @Test("iphone-as-setup-device/the-apple-tv-offers-a-qr-code: signing out and in swaps the cards with a fresh code")
    func signInChangesSwapCards() async throws {
        let (_, pairing) = await onboarding()
        let first = try #require(pairing.link)
        identity.signedIn = false
        await pairing.followSignIn()
        #expect(pairing.card == .keyboard)
        #expect(activity.current == nil)
        identity.signedIn = true
        await pairing.followSignIn()
        let second = try #require(pairing.link)
        #expect(second != first)
        #expect(activity.current == second)
    }

    @Test("iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code: each visit to the step has a new code")
    func newCodeEachVisit() async throws {
        let (_, first) = await onboarding()
        let firstLink = try #require(first.link)
        first.stop()
        #expect(first.link == nil && activity.current == nil)
        let (_, second) = await onboarding()
        #expect(try #require(second.link) != firstLink)
    }

    @Test("iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv: a new playlist loads, old ones not")
    func playlistArrives() async throws {
        try send("m3u", name: "Already here", url: "http://setup-playlist.test/old.m3u", after: -10)
        let (model, pairing) = await onboarding()
        // Created before the window, downloaded from iCloud only now.
        try send("m3u", name: "Older", url: "http://setup-playlist.test/older.m3u", after: -400)
        pairing.check()
        #expect(pairing.arrived == nil)
        model.fields = SourceFields(kind: .xtream, name: "Typed", url: "http://typed.test", username: "u", password: "p")
        let sent = try send("m3u", name: "Kitchen", url: "http://setup-playlist.test/tv.m3u")
        pairing.check()
        #expect(pairing.arrived?.id == sent.id)
        #expect(activity.current == nil)
        await settle(model)
        #expect(model.setups.map(\.id) == [sent.id])
        #expect(model.setups.first?.channels.value?.channels == 1)
        #expect(model.showsChecklist)
        #expect(model.fields == SourceFields())
        #expect(try sources().count == 3)
    }

    @Test("iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv: two senders, the first wins")
    func twoSenders() async throws {
        let (model, pairing) = await onboarding()
        let second = try send("m3u", name: "Second", url: "http://setup-playlist.test/b.m3u", after: 8)
        let first = try send("m3u", name: "First", url: "http://setup-playlist.test/a.m3u", after: 4)
        pairing.check()
        await settle(model)
        #expect(model.setups.map(\.id) == [first.id])
        #expect(try sources().map(\.id).contains(second.id))
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: Xtream, one source")
    func xtreamArrives() async throws {
        let (model, pairing) = await onboarding()
        model.fields = SourceFields(kind: .m3u, name: "Mine", url: "http://typed.test", username: "anna", password: "secret")
        let sent = try send("xtream", name: "Home provider", url: "http://setup-xtream.test")
        pairing.check()
        await settle(model)
        #expect(model.arrival?.id == sent.id)
        #expect(model.fields.kind == .xtream)
        #expect(model.fields.name == "Home provider")
        #expect(model.fields.url == "http://setup-xtream.test")
        #expect(model.fields.username == "anna" && model.fields.password == "secret")
        #expect(model.holdsApp)
        #expect(!model.showsChecklist)
        await model.signIn(into: context)
        #expect(model.error == nil)
        #expect(try held.load(for: sent.id.uuidString)?.username == "anna")
        #expect(try sources().count == 1)
        #expect(try sources().first?.credentialKey == sent.id.uuidString)
        #expect(model.arrival == nil)
        #expect(model.setups.map(\.id) == [sent.id])
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: portal MAC, Menu")
    func stalkerArrivesAndMenu() async throws {
        let (model, pairing) = await onboarding()
        model.fields = SourceFields(kind: .stalker, name: "", url: "http://mine.test/c/", mac: "00:1A:79:00:00:01")
        try send("stalker", name: "Hallway", url: "http://portal.test/c/")
        pairing.check()
        await settle(model)
        #expect(model.fields.url == "http://portal.test/c/")
        #expect(model.fields.mac == "00:1A:79:00:00:01")
        model.leaveArrival()
        #expect(model.arrival == nil && model.signIns.isEmpty)
        #expect(model.fields.name.isEmpty)
        #expect(model.fields.url == "http://mine.test/c/")
    }

    @Test("iphone-as-setup-device/nothing-arrives-and-the-tv-says-why-that-might-be: the hint after two minutes")
    func hintAfterTwoMinutes() async throws {
        let (_, pairing) = await onboarding()
        clock.now += 119
        pairing.check()
        #expect(pairing.hint == nil)
        clock.now += 1
        pairing.check()
        #expect(pairing.hint == .nothing)
        #expect(pairing.link != nil)
        #expect(SetupCard.text(.nothing).hasPrefix("Nothing yet?"))
    }

    @Test("iphone-as-setup-device/nothing-arrives-and-the-tv-says-why-that-might-be: a kind the card cannot set up asks to update")
    func hintForUnusableKind() async throws {
        let (_, pairing) = await onboarding()
        try send("channelsDVR", name: "DVR", url: "http://dvr.test")
        pairing.check()
        #expect(pairing.arrived == nil && pairing.hint == nil)
        clock.now += 120
        pairing.check()
        #expect(pairing.hint == .unusable)
        #expect(SetupCard.text(.unusable).contains("Update Antenna"))
    }

    @Test("iphone-as-setup-device/typing-on-the-tv-still-works: Connect on the TV drops the card and ignores later arrivals")
    func connectOnTheTV() async throws {
        let (model, pairing) = await onboarding()
        model.fields = SourceFields(kind: .m3u, name: "Typed", url: "http://setup-playlist.test/typed.m3u")
        await model.connect(into: context)
        #expect(model.error == nil)
        #expect(pairing.link == nil)
        #expect(activity.current == nil)
        let typed = try #require(model.setups.first?.id)
        try send("m3u", name: "Late", url: "http://setup-playlist.test/late.m3u")
        pairing.check()
        #expect(pairing.arrived == nil)
        #expect(model.setups.map(\.id) == [typed])
        #expect(try sources().count == 2)
    }

    @Test("iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv: the store is checked on a timer")
    func runChecksOnATimer() async throws {
        var dependencies = SetupPairingModel.Dependencies(identity: identity, activity: activity)
        dependencies.sleep = { _ in await Task.yield() }
        let pairing = SetupPairingModel(dependencies)
        let run = Task { await pairing.run(in: context) }
        while pairing.link == nil { await Task.yield() }
        let sent = try send("m3u", name: "Kitchen", url: "http://setup-playlist.test/tv.m3u", after: 0)
        sent.createdAt = .now
        await run.value
        #expect(pairing.arrived?.id == sent.id)
    }
}
