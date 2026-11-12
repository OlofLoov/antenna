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
        let reply = try await probe(fields.kind, link: link, username: fields.username, password: fields.password, host: fields.host)
        let username = fields.kind == .stalker ? MACAddress(fields.username)?.text ?? fields.username : fields.username
        let login = fields.kind == .m3u ? nil : CredentialStore.Credential(username: username, password: fields.password)
        try Task.checkCancellation()
        return try save(fields, link: link, reply: reply, login: login, into: context)
    }

    /// Asks the server once, saving nothing: downloads the playlist, signs
    /// in to the Xtream account and checks it is active, or signs in to the
    /// Stalker portal and loads its channels. Throws a
    /// `ConnectFailure`, or `CancellationError` when cancelled
    /// (sources-and-settings/fix-a-source-s-link-or-login).
    func probe(_ kind: SourceKind, link: URL, username: String, password: String, host: String) async throws -> Connection.Reply {
        do {
            switch kind {
            case .m3u, .m3uFile:
                return .playlist(try await download(link))
            case .stalker:
                // The portal hands out its channel list as one answer, so Connect
                // keeps it as the downloaded list and nothing is fetched twice.
                guard let portal = StalkerPortal(link.absoluteString) else { throw ConnectFailure.invalidURL }
                guard let mac = MACAddress(username) else { throw ConnectFailure.invalidMAC }
                let client = StalkerClient(credentials: .init(portal: portal, mac: mac, password: password), session: portalSession)
                return .playlist(Playlist(channels: try await client.liveLoad(guide: .portal).channels))
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
            kind: fields.kind, name: fields.name, url: link.absoluteString, epgURL: fields.epgURL, username: fields.username,
            password: fields.password)
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
