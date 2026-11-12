import AntennaCore
import Foundation
import SwiftData

/// Connect in the add-source form: checks the fields, asks the server once,
/// and saves the source the way the Settings form does
/// (first-run-onboarding/a-working-provider-is-saved-once). The reply feeds
/// the loading checklist, so nothing is fetched twice.
struct SourceConnector: Sendable {
    var session: URLSession = .shared
    var credentials: any CredentialStoring = CredentialStore()
    /// Stalker portals are asked with no cookies and no cache.
    var portalSession: URLSession = SourceConnector.portalSession

    static let portalSession = URLSession(configuration: .stalker)
    /// Jellyfin servers are asked through these clients.
    var jellyfinClients: JellyfinClients = .shared

    /// What one successful Connect saved and what the server said.
    struct Connection: Sendable {
        enum Reply: Sendable {
            /// The Xtream account, from `player_api.php` with no action.
            case account(XtreamAccountInfo.UserInfo)
            /// The downloaded playlist, parsed.
            case playlist(Playlist)
        }

        var descriptor: SourceDescriptor
        var reply: Reply
        /// The username Connect stored, for the client that loads the rest.
        var login: CredentialStore.Credential?
        /// True when this Connect inserted the source rather than reusing one.
        var inserted: Bool
        /// The Keychain item this Connect created, nil when it updated one
        /// that existed or the source has no login.
        var createdCredential: String?
        /// The imported file's name, for a file source added from onboarding.
        var fileName: String?
    }

    /// Checks `fields`, contacts the server and saves the source. Throws
    /// before saving anything when a field is wrong, the server says no or
    /// the task was cancelled. A source of the same type and link that
    /// exists already, from this device or another, is reused.
    @MainActor
    func connect(_ fields: SourceFields, into context: ModelContext) async throws -> Connection {
        if let problem = fields.check() { throw problem }
        guard var link = fields.link else { throw ConnectFailure.invalidURL }
        if fields.kind == .stalker, let portal = StalkerPortal(link.absoluteString) { link = portal.url }
        let login = Self.credential(for: fields)
        let reply = try await probe(
            fields.kind, link: link, username: login?.username ?? "", password: fields.password, login: login?.login, host: fields.host)
        try Task.checkCancellation()
        return try save(fields, link: link, reply: reply, login: login, into: context)
    }

    /// The Keychain item a form saves: the username and password for Xtream,
    /// the MAC in colon form with the optional login for a portal, nil for a playlist.
    static func credential(for fields: SourceFields) -> CredentialStore.Credential? {
        switch fields.kind {
        case .m3u, .m3uFile:
            return nil
        case .xtream, .jellyfin:
            return .init(username: fields.username, password: fields.password)
        case .stalker:
            let login = fields.username.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                username: MACAddress(fields.mac)?.text ?? fields.mac, password: fields.password, login: login.isEmpty ? nil : login)
        }
    }

    /// Asks the server once, saving nothing: downloads the playlist, signs
    /// in to the Xtream account and checks it is active, or signs in to the
    /// Stalker portal with `username` as the MAC and the optional `login`
    /// and loads its channels. Throws a `ConnectFailure`, or
    /// `CancellationError` when cancelled
    /// (sources-and-settings/fix-a-source-s-link-or-login).
    func probe(
        _ kind: SourceKind, link: URL, username: String, password: String, login: String? = nil, host: String
    ) async throws -> Connection.Reply {
        do {
            switch kind {
            case .m3u, .m3uFile:
                return .playlist(try await download(link))
            case .stalker:
                // The portal hands out its channel list as one answer, so Connect
                // keeps it as the downloaded list and nothing is fetched twice.
                guard let portal = StalkerPortal(link.absoluteString) else { throw ConnectFailure.invalidURL }
                guard let mac = MACAddress(username) else { throw ConnectFailure.invalidMAC }
                let client = StalkerClient(
                    credentials: .init(portal: portal, mac: mac, password: password, login: login), session: portalSession)
                return .playlist(Playlist(channels: try await client.liveLoad(guide: .portal).channels))
            case .jellyfin:
                return .playlist(try await probeJellyfin(link, username: username, password: password, host: host))
            case .xtream:
                let client = XtreamClient(credentials: .init(server: link, username: username, password: password), session: session)
                let info = try await client.accountInfo().userInfo
                if let inactive = ConnectFailure.accountStatus(info.status) { throw inactive }
                return .account(info)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw ConnectFailure(error, host: host)
        }
    }

    /// Checks the address is a Jellyfin server, which sends no password,
    /// then signs in and loads the Live TV channels. An answer that is not
    /// Jellyfin's, or a 404, is `.noJellyfin`
    /// (first-run-onboarding/add-a-jellyfin-server). The probe keeps its key
    /// to itself, so a check that fails leaves no key behind.
    private func probeJellyfin(_ link: URL, username: String, password: String, host: String) async throws -> Playlist {
        let client = jellyfinClients.client(server: link, username: username, password: password, storeKey: "probe-\(UUID().uuidString)")
        do {
            _ = try await client.serverInfo()
        } catch JellyfinClient.JellyfinError.decoding, JellyfinClient.JellyfinError.badStatus(404) {
            throw ConnectFailure.noJellyfin(host: host)
        }
        return Playlist(channels: try await client.liveChannels().items)
    }

    /// Removes what `connection` saved: the source when Connect inserted
    /// it, and the Keychain item when Connect created it
    /// (first-run-onboarding/a-provider-with-no-live-channels).
    @MainActor
    func undo(_ connection: Connection, in context: ModelContext) {
        if connection.inserted {
            let id = connection.descriptor.id
            let records = (try? context.fetch(FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id }))) ?? []
            for record in records { SourceRecord.delete(record, from: context, credentials: credentials) }
        }
        if let key = connection.createdCredential { try? credentials.delete(for: key) }
    }

    private func download(_ link: URL) async throws -> Playlist {
        let (data, response) = try await session.data(from: link)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ConnectFailure.serverError(status: http.statusCode)
        }
        let text = String(decoding: data, as: UTF8.self)
        return await Task.detached { M3UParser().parse(text) }.value
    }

    @MainActor
    private func save(
        _ fields: SourceFields, link: URL, reply: Connection.Reply, login: CredentialStore.Credential?, into context: ModelContext
    ) throws -> Connection {
        let key = SourceLink.key(link)
        let records = (try? context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder))) ?? []
        let existing = records.first { $0.kind == fields.kind && $0.url.map(SourceLink.key) == key }
        if let existing, let descriptor = existing.descriptor {
            var created: String?
            if let login {
                let itemKey = existing.credentialKey ?? existing.id.uuidString
                let existed = (try? credentials.load(for: itemKey)) != nil
                do {
                    try credentials.save(login, for: itemKey)
                } catch {
                    throw ConnectFailure.credentials("\(error)")
                }
                if !existed { created = itemKey }
                if existing.credentialKey == nil { existing.credentialKey = itemKey }
            }
            var saved = descriptor
            saved.credentialKey = existing.credentialKey
            return Connection(descriptor: saved, reply: reply, login: login, inserted: false, createdCredential: created)
        }
        let form = NewSource(
            kind: fields.kind, name: fields.name, url: link.absoluteString, epgURL: fields.epgURL, username: login?.username ?? "",
            password: fields.password, login: login?.login ?? "")
        let record: SourceRecord
        do {
            record = try form.save(into: context, credentials: credentials)
        } catch {
            switch error {
            case .invalidURL: throw ConnectFailure.invalidURL
            case .credentials(let reason): throw ConnectFailure.credentials(reason)
            }
        }
        try? context.save()
        guard let descriptor = record.descriptor else { throw ConnectFailure.invalidURL }
        return Connection(descriptor: descriptor, reply: reply, login: login, inserted: true, createdCredential: record.credentialKey)
    }
}
