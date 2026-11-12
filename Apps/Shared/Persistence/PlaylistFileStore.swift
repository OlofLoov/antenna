import AntennaCore
import Foundation
import SwiftData
import Synchronization

/// Reads an imported file's stored text for the loader, off the main actor
/// (local-m3u-file-import capability). The app sets `shared.container` once
/// at launch; tests make their own store.
final class PlaylistFileStore: Sendable {
    /// The store every `SourceLoader` reads from unless a test gives it another.
    static let shared = PlaylistFileStore()

    private let box: Mutex<ModelContainer?>

    init(container: ModelContainer? = nil) {
        box = Mutex(container)
    }

    var container: ModelContainer? {
        get { box.withLock { $0 } }
        set { box.withLock { $0 = newValue } }
    }

    /// One stored list: its text with placeholders and their token.
    struct Contents: Sendable {
        var text: String
        var token: String?
    }

    /// The stored text of the file source `id`, nil while it has not arrived.
    func contents(of id: UUID) -> Contents? {
        guard let container else { return nil }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first, let data = record.playlistData else { return nil }
        return Contents(text: String(decoding: data, as: UTF8.self), token: record.playlistToken)
    }

    /// True when the file source `id` has its text on this device. Asks the
    /// store without reading the text.
    func hasContents(_ id: UUID) -> Bool {
        guard let container else { return false }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id && $0.playlistData != nil })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// The link a file source's descriptor carries: `antenna-file:<id>`,
    /// with the import time, so each import loads again.
    static func standIn(id: UUID, importedAt: Date?) -> URL? {
        let stamp = importedAt.map { "?imported=\(Int64($0.timeIntervalSince1970 * 1000))" } ?? ""
        return URL(string: "antenna-file:\(id.uuidString)\(stamp)")
    }
}

/// The Keychain item holding the logins moved out of one file source's
/// links: one synchronizable item per source, under the sources service,
/// its value the JSON list of `StreamCredential`.
struct StreamLoginStore: Sendable {
    var credentials: any CredentialStoring = CredentialStore()

    /// The marker in the item's username field that says the password field holds a list.
    static let marker = "antenna.stream-logins"

    enum LoginError: Error, Equatable {
        /// The item exists but does not hold a list of logins.
        case unreadable
    }

    func save(_ logins: [StreamCredential], for key: String) throws {
        let json = String(decoding: try JSONEncoder().encode(logins), as: UTF8.self)
        try credentials.save(.init(username: Self.marker, password: json), for: key)
    }

    /// Nil when the item has not reached this device.
    func load(for key: String) throws -> [StreamCredential]? {
        guard let item = try credentials.load(for: key) else { return nil }
        guard item.username == Self.marker,
            let logins = try? JSONDecoder().decode([StreamCredential].self, from: Data(item.password.utf8))
        else { throw LoginError.unreadable }
        return logins
    }
}
