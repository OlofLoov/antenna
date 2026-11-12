import AntennaCore
import Foundation
import Synchronization

/// One sign-in key per Jellyfin source on this device, kept in memory, so
/// the channel loader and the guide share it and the app signs in once
/// per launch (jellyfin-live-tv-source/signing-in-remembers-this-device).
/// Where the key lives across launches waits for its own decision.
final class JellyfinClients: Sendable {
    /// The clients the app uses.
    static let shared = JellyfinClients()

    private let session: URLSession
    private let device: JellyfinDevice
    private let stores = Mutex<[String: JellyfinMemorySessionStore]>([:])
    private let clients = Mutex<[UUID: JellyfinClient]>([:])

    /// Tests pass a stub session and a fixed device.
    init(session: URLSession = .shared, device: JellyfinDevice = JellyfinClients.thisDevice()) {
        self.session = session
        self.device = device
    }

    /// The source's client with the Keychain login. Nil when the source is
    /// not an http or https Jellyfin server.
    func client(for source: SourceDescriptor, credential: CredentialStore.Credential) -> JellyfinClient? {
        guard source.kind == .jellyfin, let scheme = source.url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        let client = client(
            server: source.url, username: credential.username, password: credential.password,
            storeKey: source.credentialKey ?? source.id.uuidString)
        clients.withLock { $0[source.id] = client }
        return client
    }

    /// A client for a server and login, sharing the key kept under `storeKey`.
    func client(server: URL, username: String, password: String, storeKey: String) -> JellyfinClient {
        let store = stores.withLock { stores in
            if let existing = stores[storeKey] { return existing }
            let store = JellyfinMemorySessionStore()
            stores[storeKey] = store
            return store
        }
        return JellyfinClient(
            credentials: JellyfinCredentials(server: server, username: username, password: password), device: device, sessionStore: store,
            session: session)
    }

    /// The client the source's channels were loaded with, nil before its
    /// first load on this device.
    func client(sourceID: UUID) -> JellyfinClient? {
        clients.withLock { $0[sourceID] }
    }

    /// Forgets this device's key for a deleted source.
    func forget(sourceID: UUID, storeKey: String) {
        clients.withLock { $0[sourceID] = nil }
        stores.withLock { $0[storeKey] = nil }
    }

    /// Whether a key is held for `storeKey`. Tests read it.
    func hasSession(storeKey: String) async -> Bool {
        guard let store = stores.withLock({ $0[storeKey] }) else { return false }
        return await store.load() != nil
    }

    // MARK: This device

    static let deviceIDKey = "jellyfin.deviceID"

    /// This device as the server sees it: an id made once and kept in
    /// `UserDefaults`, never synced, and the platform's name, never the
    /// user's own device name.
    static func thisDevice(defaults: UserDefaults = .standard) -> JellyfinDevice {
        let id: String
        if let saved = defaults.string(forKey: deviceIDKey), !saved.isEmpty {
            id = saved
        } else {
            id = UUID().uuidString
            defaults.set(id, forKey: deviceIDKey)
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return JellyfinDevice(id: id, name: platformName, appVersion: version)
    }

    /// "Apple TV", "iPhone", "iPad" or "Mac", read from the hardware model
    /// so it never needs the main actor.
    static var platformName: String {
        #if os(tvOS)
            return "Apple TV"
        #else
            let info = ProcessInfo.processInfo
            if info.isiOSAppOnMac || info.isMacCatalystApp { return "Mac" }
            let model = info.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine()
            return model.hasPrefix("iPad") ? "iPad" : "iPhone"
        #endif
    }

    /// The hardware model, such as "iPhone17,1".
    private static func machine() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}
