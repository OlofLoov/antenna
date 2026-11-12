import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// "Sign in your Apple TV" on the iPhone as a model: the rows, Enter, Send
/// and the pickup, against an in-memory store, Keychain and drop store, a
/// stubbed server and a scripted clock.
@MainActor
@Suite struct SendLoginsTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let drops = InMemoryLoginDrops()
    let identity = FixedICloudIdentity(signedIn: true)
    let tv = LoginReceiverKey()
    let clock = LoginReceiverTests.Clock()
    let tag = "send-\(UUID().uuidString)"
    let home: SourceDescriptor
    let flat: SourceDescriptor

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        StubURLProtocol.register(host: "send-home.test", body: LoginReceiverTests.account)
        StubURLProtocol.register(host: "send-flat.test", body: LoginReceiverTests.account)
        home = SourceDescriptor(name: "Home provider", kind: .xtream, url: try #require(URL(string: "http://send-home.test")))
        flat = SourceDescriptor(name: "Holiday flat", kind: .xtream, url: try #require(URL(string: "http://send-flat.test")))
        for (order, source) in [home, flat].enumerated() {
            container.mainContext.insert(SourceRecord(descriptor: source, sortOrder: order))
        }
        try held.save(.init(username: "anna", password: "secret"), for: home.id.uuidString)
    }

    private var context: ModelContext { container.mainContext }

    private func link(_ ids: [UUID]) -> SetupLink {
        SetupLink(token: PairingToken(), key: tv.publicKey, sources: ids)
    }

    typealias Wait = @MainActor (Int) async -> Void

    /// Each wait moves the clock by `step` seconds and runs `onWait` with the count so far.
    private func deliveryDependencies(step: TimeInterval = 2, onWait: @escaping Wait = { _ in }) -> LoginDelivery.Dependencies {
        var dependencies = LoginDelivery.Dependencies(identity: identity, drops: drops)
        var waits = 0
        dependencies.sleep = { [clock] _ in
            waits += 1
            clock.now += step
            await onWait(waits)
        }
        dependencies.now = { [clock] in clock.now }
        return dependencies
    }

    private func model(
        _ link: SetupLink, step: TimeInterval = 2, onWait: @escaping @MainActor (Int) async -> Void = { _ in }
    ) -> SendLoginsModel {
        let model = SendLoginsModel(
            link: link,
            dependencies: .init(
                connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held),
                delivery: deliveryDependencies(step: step, onWait: onWait)))
        model.update([home, flat])
        return model
    }

    @Test("apple-tv-login-from-iphone/the-iphone-asks-before-it-sends: ready and not on this iPhone")
    func rows() {
        let model = model(link([home.id, flat.id]))
        #expect(model.rows.map(\.id) == [home.id, flat.id])
        #expect(model.rows.map(\.ready) == [true, false])
        #expect(model.missing == 0 && model.canSend && model.delivery == nil)
    }

    @Test("apple-tv-login-from-iphone/sources-the-iphone-does-not-have: one missing and none at all")
    func absent() {
        let one = model(link([home.id, UUID()]))
        #expect(one.rows.map(\.id) == [home.id] && one.missing == 1)
        #expect(SendLogins.missing(1, device: "iPhone")?.hasPrefix("1 source the Apple TV asked for isn't on this iPhone yet.") == true)
        let none = model(link([UUID(), UUID()]))
        #expect(none.hasNone && !none.canSend && none.missing == 2)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-asks-before-it-sends: Send sends only the ready logins, sealed for the TV")
    func sendReady() async throws {
        let link = link([home.id, flat.id])
        let model = model(link) { waits in
            if waits == 2 {
                // The TV opens it, as its model would, and picks it up.
                guard case .waiting(let sealed)? = try? await drops.fetch(token: link.token),
                    let payload = try? LoginSeal.open(sealed, with: tv, token: link.token)
                else { return }
                #expect(payload.logins == [.init(source: home.id, username: "anna", password: "secret")])
                try? await drops.pickUp(token: link.token)
            }
        }
        #expect(try await drops.fetch(token: link.token) == nil)
        model.send()
        let delivery = try #require(model.delivery)
        await delivery.run()
        #expect(delivery.state == .pickedUp)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: not picked up yet, then picked up")
    func notPickedUpThenPickedUp() async throws {
        let link = link([home.id])
        var seen: [LoginDelivery.State] = []
        var delivery: LoginDelivery?
        let model = model(link, step: 30) { waits in
            seen.append(delivery?.state ?? .sending)
            if waits == 4 { await drops.pickUpWaiting() }
        }
        model.send()
        delivery = model.delivery
        await delivery?.run()
        #expect(seen.contains(.notPickedUp))
        #expect(delivery?.state == .pickedUp)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: ten minutes later the delivery is deleted")
    func deletedAfterTenMinutes() async throws {
        let link = link([home.id])
        let model = model(link, step: 61)
        model.send()
        let delivery = try #require(model.delivery)
        await delivery.run()
        #expect(delivery.state == .notPickedUp)
        #expect(try await drops.fetch(token: link.token) == nil)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: offline, not signed in, storage full, used")
    func failures() async throws {
        let cases: [(failure: LoginDropError?, expected: LoginDelivery.State)] = [
            (.offline, .offline), (nil, .notSignedIn), (.quotaExceeded, .storageFull), (.alreadyUsed, .alreadyUsed),
        ]
        for (failure, expected) in cases {
            await drops.fail(with: failure)
            identity.signedIn = expected != .notSignedIn
            let model = model(link([home.id]))
            model.send()
            let delivery = try #require(model.delivery)
            await delivery.run()
            #expect(delivery.state == expected)
            #expect(delivery.canRetry == (expected == .offline))
        }
        await drops.fail(with: nil)
        identity.signedIn = true
        #expect(await drops.isEmpty)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: Try again sends once online")
    func tryAgain() async throws {
        let link = link([home.id])
        let model = model(link) { waits in if waits == 1 { await drops.pickUpWaiting() } }
        await drops.fail(with: .offline)
        model.send()
        await model.delivery?.run()
        #expect(model.delivery?.state == .offline)
        await drops.fail(with: nil)
        model.send()
        await model.delivery?.run()
        #expect(model.delivery?.state == .pickedUp)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have: an accepted login is kept and ready")
    func enterAccepted() async throws {
        let model = model(link([home.id, flat.id]))
        let row = try #require(model.rows.last)
        var fields = SourceFields(kind: .xtream, name: flat.name, url: flat.url.absoluteString)
        fields.username = "anna"
        fields.password = "flat"
        #expect(await model.enter(fields, for: row, in: context) == nil)
        #expect(model.rows.map(\.ready) == [true, true])
        #expect(try held.load(for: flat.id.uuidString)?.password == "flat")
    }

    @Test("apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have: a refused login stays not ready")
    func enterRefused() async throws {
        StubURLProtocol.register(host: "send-refused.test", status: 401, body: "")
        let refused = SourceDescriptor(name: "Cabin", kind: .xtream, url: try #require(URL(string: "http://send-refused.test")))
        context.insert(SourceRecord(descriptor: refused, sortOrder: 2))
        let model = model(link([home.id, refused.id]))
        model.update([home, refused])
        let row = try #require(model.rows.last)
        var fields = SourceFields(kind: .xtream, name: refused.name, url: refused.url.absoluteString)
        fields.username = "anna"
        fields.password = "wrong"
        let message = await model.enter(fields, for: row, in: context)
        #expect(message?.isEmpty == false)
        #expect(model.rows.map(\.ready) == [true, false])
        #expect(try held.load(for: refused.id.uuidString) == nil)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-asks-before-it-sends: a sign-in code opens the sheet, a setup code the form")
    func inboxKinds() throws {
        let inbox = SetupInbox()
        let signIn = link([home.id])
        #expect(inbox.receive(signIn.url))
        #expect(inbox.pending?.kind == .signIn(signIn))
        inbox.use(signIn)
        inbox.take()
        #expect(inbox.receive(signIn.url))
        #expect(inbox.pending == nil)
        inbox.receive(handoff: link([flat.id]).userInfo)
        if case .signIn = inbox.pending?.kind {} else { Issue.record("Handoff did not open the sign-in sheet") }
        inbox.take()
        let setup = SetupLink(token: PairingToken(), key: tv.publicKey)
        inbox.receive(setup.url)
        #expect(inbox.pending?.kind == .setup(setup))
    }

    @Test(
        "iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: the setup screen sends the login"
    )
    func setupSendsLogin() throws {
        let withKey = SetupLink(token: PairingToken(), key: tv.publicKey)
        let login = SourceConnector.Connection(
            descriptor: home, reply: .playlist(Playlist(channels: [])), login: .init(username: "anna", password: "secret"), inserted: true,
            createdCredential: nil)
        #expect(SetupFromTVScreen.login(of: login, to: withKey) != nil)
        // A playlist has no login and sends nothing; neither does a version 1 link.
        var playlist = login
        playlist.login = nil
        #expect(SetupFromTVScreen.login(of: playlist, to: withKey) == nil)
        #expect(SetupFromTVScreen.login(of: login, to: SetupLink(token: PairingToken())) == nil)
    }
}
