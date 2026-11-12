import AntennaCore
import Foundation
import SwiftData

/// Checks a login with its source's server and keeps it in this device's
/// Keychain under the source's credential key, adding no source
/// (first-run-onboarding/sign-in-again-on-an-apple-tv,
/// apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it).
/// A source without a credential key gets its id as the key. The Apple TV
/// sign-in, a delivered login and the iPhone's Enter all keep a login here.
struct LoginKeeper {
    let connector: SourceConnector

    /// Why a login was not kept.
    enum Failure: Error, Equatable {
        case cancelled
        /// The sentence the sign-in shows.
        case refused(String)
    }

    @MainActor
    func keep(
        _ login: CredentialStore.Credential, for source: SourceDescriptor, in context: ModelContext
    ) async throws(Failure) -> SourceConnector.Connection {
        let host = source.url.host() ?? source.url.absoluteString
        let reply: SourceConnector.Connection.Reply
        do {
            reply = try await connector.probe(
                source.kind, link: source.url, username: login.username, password: login.password, login: login.login, host: host)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .refused(ConnectFailure(error, host: host).message)
        }
        let key = source.credentialKey ?? source.id.uuidString
        do {
            try connector.credentials.save(login, for: key)
        } catch {
            throw .refused(ConnectFailure.credentials("\(error)").message)
        }
        if source.credentialKey == nil {
            let id = source.id
            try? context.fetch(FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id })).first?.credentialKey = key
            try? context.save()
        }
        var signed = source
        signed.credentialKey = key
        return SourceConnector.Connection(descriptor: signed, reply: reply, login: login, inserted: false, createdCredential: nil)
    }
}

extension CredentialStore.Credential {
    /// The Keychain item for a delivered login.
    init(_ login: LoginPayload.Login) {
        self.init(username: login.username, password: login.password, login: login.login)
    }
}
