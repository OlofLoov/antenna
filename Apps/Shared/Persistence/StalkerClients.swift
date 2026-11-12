import AntennaCore
import Foundation
import Synchronization

/// One `StalkerClient` per Stalker source for the life of the process, so
/// the channel loader, the guide and playback share one sign-in and never
/// cancel each other's session
/// (stalker-portal-source/channels-guide-and-playback-share-one-sign-in).
final class StalkerClients: Sendable {
    /// The clients the app uses.
    static let shared = StalkerClients()

    private let session: URLSession
    private let clients = Mutex<[UUID: StalkerClient]>([:])

    /// Tests pass a stub session.
    init(session: URLSession = URLSession(configuration: .stalker)) {
        self.session = session
    }

    /// The source's client, made on first use and kept while its portal,
    /// MAC, password and login stay the same. Nil when the source's address
    /// is not an http or https portal, or the Keychain username is not a MAC
    /// (stalker-portal-source/your-mac-and-login-stay-in-the-keychain).
    func client(for source: SourceDescriptor, credential: CredentialStore.Credential) -> StalkerClient? {
        guard source.kind == .stalker, let portal = StalkerPortal(source.url.absoluteString),
            let mac = MACAddress(credential.username)
        else { return nil }
        let credentials = StalkerCredentials(portal: portal, mac: mac, password: credential.password, login: credential.login)
        return clients.withLock { clients in
            if let existing = clients[source.id], existing.credentials == credentials { return existing }
            let client = StalkerClient(credentials: credentials, session: session)
            clients[source.id] = client
            return client
        }
    }

    /// The client the source's channels were loaded with, nil before its
    /// first load on this device.
    func client(sourceID: UUID) -> StalkerClient? {
        clients.withLock { $0[sourceID] }
    }
}
