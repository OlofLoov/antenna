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
    }

    /// Checks `fields`, contacts the server and saves the source. Throws
    /// before saving anything when a field is wrong, the server says no or
    /// the task was cancelled. A source of the same type and link that
    /// exists already, from this device or another, is reused.
    @MainActor
    func connect(_ fields: SourceFields, into context: ModelContext) async throws -> Connection {
        if let problem = fields.check() { throw problem }
        guard let link = fields.link else { throw ConnectFailure.invalidURL }
        let reply: Connection.Reply
        let login: CredentialStore.Credential?
        do {
            switch fields.kind {
            case .m3u:
                reply = .playlist(try await download(link))
                login = nil
            case .xtream, .stalker:
                let credential = CredentialStore.Credential(username: fields.username, password: fields.password)
                let client = XtreamClient(
                    credentials: .init(server: link, username: credential.username, password: credential.password), session: session)
                let info = try await client.accountInfo().userInfo
                if let inactive = ConnectFailure.accountStatus(info.status) { throw inactive }
                reply = .account(info)
                login = credential
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw ConnectFailure(error, host: fields.host)
        }
        try Task.checkCancellation()
        return try save(fields, link: link, reply: reply, login: login, into: context)
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
