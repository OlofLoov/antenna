import AntennaCore
import Foundation
import SwiftData

/// What the user typed into the Add source sheet. `save` validates it, writes
/// the credential to the Keychain and inserts the record, so the sheet itself
/// only shows the error or dismisses.
struct NewSource: Equatable {
    var kind: SourceKind = .m3u
    var name = ""
    var url = ""
    var epgURL = ""
    var username = ""
    var password = ""
    /// The optional Stalker portal login, kept in the Keychain item.
    var login = ""

    enum SaveError: Error, Equatable {
        case invalidURL
        case credentials(String)

        /// The text the sheet shows under the form.
        var message: String {
            switch self {
            case .invalidURL: "Enter a valid URL."
            case .credentials(let reason): "Could not store credentials: \(reason)"
            }
        }
    }

    /// Inserts one `SourceRecord` and, for Xtream and Stalker, one Keychain item
    /// keyed by the record id. Throws before inserting anything when the URL
    /// has no scheme or the Keychain write fails.
    @MainActor
    @discardableResult
    func save(into context: ModelContext, credentials: any CredentialStoring) throws(SaveError) -> SourceRecord {
        guard var serverURL = URL(string: url.trimmingCharacters(in: .whitespaces)), serverURL.scheme != nil else {
            throw .invalidURL
        }
        if kind == .stalker, let portal = StalkerPortal(url) { serverURL = portal.url }
        var descriptor = SourceDescriptor(
            name: name.isEmpty ? serverURL.host() ?? "Source" : name,
            kind: kind,
            url: serverURL,
            epgURL: URL(string: epgURL)
        )
        if kind != .m3u {
            let key = descriptor.id.uuidString
            do {
                let mac = kind == .stalker ? MACAddress(username)?.text ?? username : username
                try credentials.save(.init(username: mac, password: password, login: login.isEmpty ? nil : login), for: key)
            } catch {
                throw .credentials("\(error)")
            }
            descriptor.credentialKey = key
        }
        let existing = (try? context.fetchCount(FetchDescriptor<SourceRecord>())) ?? 0
        let record = SourceRecord(descriptor: descriptor, sortOrder: existing)
        context.insert(record)
        return record
    }
}

extension SourceRecord {
    /// Deletes the record and its Keychain item, then the source's watch
    /// progress and My list entries (source-management/deleting-a-source-removes-its-watch-history).
    /// A Keychain failure is ignored: the record goes regardless and the item is left behind.
    @MainActor
    static func delete(_ record: SourceRecord, from context: ModelContext, credentials: any CredentialStoring) {
        if let key = record.credentialKey { try? credentials.delete(for: key) }
        let id = record.id
        context.delete(record)
        ActivityStore.removeSource(id, in: context)
    }
}
