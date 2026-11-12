import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The Apple TV taking logins sent from the iPhone, as models: the QR card
/// on the sign-in step and on the setup card, against an in-memory store,
/// the in-memory drop store, stubbed servers and a scripted clock. The
/// models run the same on every platform; only the Apple TV shows them.
@MainActor
@Suite struct LoginReceiverTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let identity = FixedICloudIdentity(signedIn: true)
    let activity = NoSetupActivity()
    let drops = InMemoryLoginDrops()
    let clock = Clock()
    let tag = "receive-\(UUID().uuidString)"

    final class Clock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    static let account = #"{"user_info":{"username":"anna","status":"Active","max_connections":"1","auth":1}}"#

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        StubURLProtocol.register(host: "receive-home.test", body: Self.account)
        StubURLProtocol.register(host: "receive-flat.test", body: Self.account)
    }

    private var context: ModelContext { container.mainContext }

    private func source(_ name: String, host: String, order: Int, id: UUID = UUID()) throws -> SourceDescriptor {
        let descriptor = SourceDescriptor(id: id, name: name, kind: .xtream, url: try #require(URL(string: "http://\(host)")))
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: order))
        try context.save()
        return descriptor
    }

    private func model() -> OnboardingModel {
        let model = OnboardingModel(
            connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held), clipboard: nil)
        model.setupDependencies = SourceSetup.Dependencies(
            channels: { _ in Playlist(channels: []) }, library: { _ in SourceSetup.Library(movies: 0, series: 0) }, guide: nil)
        return model
    }

    private func receiver(for model: OnboardingModel) async -> LoginReceiverModel {
        var dependencies = LoginReceiverModel.Dependencies(identity: identity, drops: drops, activity: activity)
        dependencies.now = { [clock] in clock.now }
        let receiver = LoginReceiverModel(dependencies)
        // As LoginReceiverRuntime wires it.
        receiver.onDelivery = { [context] payload in
            await model.receive(payload, into: context)
            receiver.ask(for: model.signIns.map(\.id))
        }
        receiver.ask(for: model.signIns.map(\.id))
        await receiver.start()
        return receiver
    }

    /// What an iPhone sends for `ids`: `anna` and `password`.
    private func send(_ ids: [UUID], to link: SetupLink, password: String = "secret") async throws {
        let payload = LoginPayload(logins: ids.map { .init(source: $0, username: "anna", password: password) })
        try await drops.save(try LoginSeal.seal(payload, to: try #require(link.key), token: link.token), token: link.token)
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code: the code asks for every source still to sign in")
    func codeAsksForSources() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let flat = try source("Holiday flat", host: "receive-flat.test", order: 1)
        let model = model()
        model.startSignIn([home, flat])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        #expect(link.sources == [home.id, flat.id])
        #expect(link.key != nil)
        #expect(activity.current == link)
        #expect(receiver.status == .waiting)
        #expect(receiver.requested == [home.id, flat.id])
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: the logins work and the sources load")
    func pickup() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let flat = try source("Holiday flat", host: "receive-flat.test", order: 1)
        let model = model()
        model.startSignIn([home, flat])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        try await send([home.id, flat.id], to: link)
        await receiver.check()
        #expect(model.signIns.isEmpty)
        #expect(model.setups.map(\.id) == [home.id, flat.id])
        #expect(try held.load(for: home.id.uuidString)?.password == "secret")
        #expect(try context.fetch(FetchDescriptor<SourceRecord>()).count == 2)
        #expect(try await drops.fetch(token: link.token) == .pickedUp)
        #expect(receiver.card == .keyboard)
        #expect(activity.current == nil)
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: one login does not work")
    func oneFails() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let flat = try source("Holiday flat", host: "receive-nowhere.test", order: 1)
        let model = model()
        model.startSignIn([home, flat])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        try await send([home.id, flat.id], to: link)
        await receiver.check()
        #expect(model.signIns.map(\.id) == [flat.id])
        #expect(try held.load(for: home.id.uuidString) != nil)
        #expect(try held.load(for: flat.id.uuidString) == nil)
        #expect(model.error?.hasPrefix("The login from your iPhone didn't work here. ") == true)
        #expect(model.fields.name == "Holiday flat" && model.fields.username.isEmpty)
        let next = try #require(receiver.link)
        #expect(next != link && next.sources == [flat.id])
        #expect(receiver.status == .waiting)
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: a delivery it cannot read")
    func unreadable() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let model = model()
        model.startSignIn([home])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        try await drops.save(SealedLogin(enc: Data(repeating: 3, count: 32), box: Data(repeating: 4, count: 60)), token: link.token)
        await receiver.check()
        #expect(receiver.status == .unreadable)
        #expect(try #require(receiver.link) != link)
        #expect(model.signIns.map(\.id) == [home.id])
        // Sealed for another code: never opens under this one.
        let next = try #require(receiver.link)
        let moved = try LoginSeal.seal(
            LoginPayload(logins: [.init(source: home.id, username: "anna", password: "secret")]), to: try #require(next.key),
            token: link.token)
        try await drops.save(moved, token: next.token)
        await receiver.check()
        #expect(receiver.status == .unreadable)
        #expect(model.signIns.map(\.id) == [home.id])
    }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: two iPhones scan the same code")
    func twoSenders() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let model = model()
        model.startSignIn([home])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        try await send([home.id], to: link)
        await #expect(throws: LoginDropError.alreadyUsed) { try await send([home.id], to: link, password: "other") }
        await receiver.check()
        await #expect(throws: LoginDropError.alreadyUsed) { try await send([home.id], to: link, password: "other") }
        #expect(try held.load(for: home.id.uuidString)?.password == "secret")
    }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: ten minutes pass")
    func tenMinutes() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let model = model()
        model.startSignIn([home])
        let receiver = await receiver(for: model)
        let old = try #require(receiver.link)
        clock.now += 599
        await receiver.check()
        #expect(receiver.link == old)
        clock.now += 1
        await receiver.check()
        let fresh = try #require(receiver.link)
        #expect(fresh != old && fresh.key != old.key)
        // A delivery for the old code is never opened.
        try await send([home.id], to: old)
        await receiver.check()
        #expect(model.signIns.map(\.id) == [home.id])
        #expect(try await drops.fetch(token: old.token) != .pickedUp)
    }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: leaving or signing out stops the code")
    func leaveAndSignOut() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let model = model()
        model.startSignIn([home])
        let receiver = await receiver(for: model)
        let first = try #require(receiver.link)
        identity.signedIn = false
        await receiver.followSignIn()
        #expect(receiver.card == .keyboard && activity.current == nil)
        identity.signedIn = true
        await receiver.followSignIn()
        #expect(try #require(receiver.link) != first)
        receiver.stop()
        #expect(receiver.link == nil && activity.current == nil)
        try await send([home.id], to: first)
        await receiver.check()
        #expect(model.signIns.map(\.id) == [home.id])
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code: typing on the TV still works")
    func typedFirst() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let flat = try source("Holiday flat", host: "receive-flat.test", order: 1)
        let model = model()
        model.startSignIn([home, flat])
        let receiver = await receiver(for: model)
        let link = try #require(receiver.link)
        model.fields.username = "typed"
        model.fields.password = "typed"
        await model.signIn(into: context)
        #expect(model.signIns.map(\.id) == [flat.id])
        try await send([home.id], to: link)
        await receiver.check()
        #expect(try held.load(for: home.id.uuidString)?.password == "typed")
        #expect(model.signIns.map(\.id) == [flat.id])
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: the hint after two minutes")
    func hint() async throws {
        let home = try source("Home provider", host: "receive-home.test", order: 0)
        let model = model()
        model.startSignIn([home])
        let receiver = await receiver(for: model)
        clock.now += 119
        await receiver.check()
        #expect(!receiver.showsHint)
        clock.now += 1
        await receiver.check()
        #expect(receiver.showsHint)
    }

    @Test("apple-tv-login-from-iphone/every-kind-of-source-with-a-login: Channels DVR signs in only with a proxy login")
    func channelsDVR() throws {
        let url = try #require(URL(string: "http://dvr.test:8089"))
        #expect(!SourceDescriptor(name: "DVR", kind: .channelsDVR, url: url).signsInOnAppleTV)
        #expect(SourceDescriptor(name: "DVR", kind: .channelsDVR, url: url, credentialKey: "k").signsInOnAppleTV)
        #expect(SourceDescriptor(name: "Home", kind: .jellyfin, url: url).signsInOnAppleTV)
        #expect(!SourceDescriptor(name: "List", kind: .m3u, url: url).signsInOnAppleTV)
    }
}

/// The setup card's key: the login of a source set up on the iPhone.
@MainActor
@Suite struct SetupLoginTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let drops = InMemoryLoginDrops()
    let clock = LoginReceiverTests.Clock()
    let tag = "setup-login-\(UUID().uuidString)"

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        StubURLProtocol.register(host: "setup-login.test", body: LoginReceiverTests.account)
    }

    private var context: ModelContext { container.mainContext }

    /// Onboarding on the details step with the QR card, wired as `SetupPairingRuntime` does.
    private func onboarding() async -> (OnboardingModel, SetupPairingModel) {
        let model = OnboardingModel(
            connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held), clipboard: nil)
        model.setupDependencies = SourceSetup.Dependencies(
            channels: { _ in Playlist(channels: []) }, library: { _ in SourceSetup.Library(movies: 0, series: 0) }, guide: nil)
        var dependencies = SetupPairingModel.Dependencies(
            identity: FixedICloudIdentity(signedIn: true), activity: NoSetupActivity(), drops: drops)
        dependencies.now = { [clock] in clock.now }
        let pairing = SetupPairingModel(dependencies)
        model.pairing = pairing
        let context = context
        pairing.onArrival = { source in
            Task {
                await model.received(source)
                if pairing.login == .checking, let login = pairing.heldLogin { await model.receive(login, into: context) }
            }
        }
        pairing.onLogin = { login in
            Task {
                await model.receive(login, into: context)
                if model.arrival != nil { pairing.loginDidNotWork() }
            }
        }
        await pairing.start(in: context)
        return (model, pairing)
    }

    private func arrive(id: UUID) throws {
        let url = try #require(URL(string: "http://setup-login.test"))
        let record = SourceRecord(descriptor: SourceDescriptor(id: id, name: "Home provider", kind: .xtream, url: url))
        record.createdAt = clock.now.addingTimeInterval(5)
        context.insert(record)
        try context.save()
    }

    private func send(_ id: UUID, to link: SetupLink) async throws {
        let payload = LoginPayload(logins: [.init(source: id, username: "anna", password: "secret")])
        try await drops.save(try LoginSeal.seal(payload, to: try #require(link.key), token: link.token), token: link.token)
    }

    private func settle(_ model: OnboardingModel) async {
        for _ in 0..<200 where model.setups.isEmpty && model.error == nil {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code: the setup card's link carries a key")
    func linkCarriesKey() async throws {
        let (_, pairing) = await onboarding()
        let link = try #require(pairing.link)
        #expect(link.key != nil && link.sources.isEmpty)
        #expect(link.url.absoluteString.contains("v=2"))
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: the login arrives after its source")
    func loginAfterSource() async throws {
        let (model, pairing) = await onboarding()
        let link = try #require(pairing.link)
        let id = UUID()
        try arrive(id: id)
        pairing.check()
        #expect(pairing.login == .waiting)
        try await send(id, to: link)
        await pairing.listen()
        await settle(model)
        #expect(model.setups.map(\.id) == [id])
        #expect(try held.load(for: id.uuidString)?.username == "anna")
        #expect(try await drops.fetch(token: link.token) == .pickedUp)
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: a login before its source is used")
    func loginBeforeSource() async throws {
        let (model, pairing) = await onboarding()
        let link = try #require(pairing.link)
        let id = UUID()
        try await send(id, to: link)
        await pairing.listen()
        #expect(pairing.heldLogin?.logins.map(\.source) == [id])
        try arrive(id: id)
        pairing.check()
        #expect(pairing.login == .checking)
        await settle(model)
        #expect(model.setups.map(\.id) == [id])
        #expect(try held.load(for: id.uuidString)?.password == "secret")
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: sign in here after a minute")
    func fallsBackAfterAMinute() async throws {
        let (model, pairing) = await onboarding()
        let link = try #require(pairing.link)
        let id = UUID()
        try arrive(id: id)
        pairing.check()
        for _ in 0..<50 where model.arrival == nil { await Task.yield() }
        #expect(model.arrival?.id == id)
        clock.now += 59
        await pairing.listen()
        #expect(pairing.login == .waiting)
        clock.now += 1
        await pairing.listen()
        #expect(pairing.login == .missing)
        // The TV keeps listening until the code's ten minutes end.
        try await send(id, to: link)
        await pairing.listen()
        await settle(model)
        #expect(model.setups.map(\.id) == [id])
    }
}
