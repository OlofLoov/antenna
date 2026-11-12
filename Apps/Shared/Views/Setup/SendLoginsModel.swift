import AntennaCore
import Foundation
import Observation
import SwiftData

/// "Sign in your Apple TV" on iPhone, iPad and Mac
/// (apple-tv-login-from-iphone/the-iphone-asks-before-it-sends): the sources
/// the TV's code asks for, whether this device has each login, Enter for
/// one it lacks, and Send, which seals the ready logins to the code's key.
/// Nothing leaves the device before Send.
@MainActor @Observable
final class SendLoginsModel {
    /// One requested source on this device.
    struct Row: Identifiable, Equatable {
        var source: SourceDescriptor
        /// Its login is in this device's Keychain.
        var ready: Bool
        var id: UUID { source.id }
    }

    struct Dependencies {
        /// Checks an entered login and keeps it in the Keychain, whose items Send reads.
        var connector: SourceConnector
        var delivery: LoginDelivery.Dependencies
    }

    let link: SetupLink
    private(set) var rows: [Row] = []
    /// How many requested sources are not on this device.
    private(set) var missing = 0
    /// The send in progress or done; nil before Send.
    private(set) var delivery: LoginDelivery?
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var sources: [SourceDescriptor] = []

    init(link: SetupLink, dependencies: Dependencies) {
        self.link = link
        self.dependencies = dependencies
    }

    /// The device's sources, as the store has them now.
    func update(_ sources: [SourceDescriptor]) {
        self.sources = sources
        let found = link.sources.compactMap { id in
            sources.first { $0.id == id && $0.signsInOnAppleTV }
        }
        rows = found.map { Row(source: $0, ready: login(for: $0) != nil) }
        missing = link.sources.count - found.count
    }

    /// True when the TV asked for sources and none is on this device.
    var hasNone: Bool { rows.isEmpty }

    /// Send is enabled once a row is ready and nothing was sent.
    var canSend: Bool { delivery == nil && rows.contains(where: \.ready) }

    /// Seals the ready logins and starts sending; the screen runs the delivery.
    func send() {
        guard delivery == nil || delivery?.canRetry == true else { return }
        let logins = rows.filter(\.ready).compactMap { row -> LoginPayload.Login? in
            guard let login = login(for: row.source) else { return nil }
            return .init(source: row.id, username: login.username, password: login.password, login: login.login)
        }
        guard !logins.isEmpty else { return }
        delivery = LoginDelivery(LoginPayload(logins: logins), to: link, dependencies: dependencies.delivery)
    }

    /// Checks a login typed for `row` with its server and keeps it in this
    /// device's Keychain (apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have).
    /// Returns the sentence to show when it does not work.
    func enter(_ fields: SourceFields, for row: Row, in context: ModelContext) async -> String? {
        if let problem = fields.check() { return problem.message }
        guard let login = SourceConnector.credential(for: fields) else { return ConnectFailure.invalidUsername.message }
        do {
            let connection = try await LoginKeeper(connector: dependencies.connector).keep(login, for: row.source, in: context)
            sources = sources.map { $0.id == row.id ? connection.descriptor : $0 }
            update(sources)
            return nil
        } catch {
            guard case .refused(let message) = error else { return nil }
            return message
        }
    }

    /// The Keychain item for `source`, or nil when this device does not have it.
    private func login(for source: SourceDescriptor) -> CredentialStore.Credential? {
        guard let found = try? dependencies.connector.credentials.load(for: source.credentialKey ?? source.id.uuidString) else {
            return nil
        }
        if source.kind == .stalker, MACAddress(found.username) == nil { return nil }
        return found
    }
}

extension SendLoginsModel.Dependencies {
    /// The network, the Keychain and CloudKit, or the scripted ones in a
    /// Debug build launched for UI tests.
    @MainActor static var app: Self {
        #if DEBUG
            if let scripted = UITestingLoginDrops.sendDependencies() { return scripted }
        #endif
        return .init(connector: SourceConnector(), delivery: .app)
    }
}

extension LoginDelivery.Dependencies {
    /// CloudKit, or the scripted store in a Debug build launched for UI tests.
    @MainActor static var app: Self {
        #if DEBUG
            if let scripted = UITestingLoginDrops.deliveryDependencies() { return scripted }
        #endif
        return .init(identity: CloudKitIdentity(), drops: CloudKitLoginDrops())
    }
}
