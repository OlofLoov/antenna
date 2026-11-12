import AntennaCore
import Foundation
import OSLog
import SwiftData

/// Saves a checked playlist file as a file source, or onto an existing one
/// (local-m3u-file-import capability). The logins in its links go to one
/// Keychain item per source before the record is saved, so the synced text
/// never holds one.
@MainActor
struct FileImport {
    var credentials: any CredentialStoring = CredentialStore()
    var now: () -> Date = { .now }

    static let logger = Logger(subsystem: "se.codecrave.antenna", category: "import")

    /// What the sheet hands over when the user taps Import or Replace.
    struct Request {
        var inspected: PlaylistImport.Inspected
        var fileName: String
        /// The Name field; empty saves the file name without its extension.
        var name = ""
        /// The Guide URL field, as typed.
        var guideLink = ""
        /// The source Replace writes onto. Nil, or a source deleted in the
        /// meantime, inserts a new one.
        var replacing: UUID?
    }

    enum SaveError: Error, Equatable {
        case credentials(String)
    }

    /// Writes the logins to the Keychain, then inserts or updates the
    /// record and saves the context. Replace keeps the record's id, name,
    /// sort order and creation date, so favorites of channels still in the
    /// file keep working.
    @discardableResult
    func save(_ request: Request, into context: ModelContext) throws(SaveError) -> SourceRecord {
        let existing = request.replacing.flatMap { Self.record($0, in: context) }
        let id = existing?.id ?? UUID()
        let token = PlaylistImport.token(for: request.inspected.text, preferred: existing?.playlistToken)
        let stripped = PlaylistImport.stripCredentials(request.inspected.text, token: token)
        var key: String?
        if stripped.credentials.isEmpty {
            if let old = existing?.credentialKey { try? credentials.delete(for: old) }
        } else {
            let itemKey = existing?.credentialKey ?? id.uuidString
            do {
                try StreamLoginStore(credentials: credentials).save(stripped.credentials, for: itemKey)
            } catch {
                throw .credentials("\(error)")
            }
            key = itemKey
        }
        let record: SourceRecord
        if let existing {
            record = existing
        } else {
            let name = request.name.trimmingCharacters(in: .whitespaces)
            let count = (try? context.fetchCount(FetchDescriptor<SourceRecord>())) ?? 0
            record = SourceRecord(
                descriptor: SourceDescriptor(
                    id: id, name: name.isEmpty ? ImportText.defaultName(fileName: request.fileName) : name, kind: .m3uFile,
                    url: URL(fileURLWithPath: "/")),
                sortOrder: count)
            record.url = nil
            context.insert(record)
        }
        record.kindRaw = SourceKind.m3uFile.rawValue
        record.playlistData = Data(stripped.text.utf8)
        record.playlistToken = token
        record.fileName = request.fileName
        record.importedAt = now()
        record.credentialKey = key
        record.epgURL = Self.guideLink(request.guideLink, header: request.inspected.playlist.epgURLs.first)
        try? context.save()
        let channels = request.inspected.playlist.channels.count
        let bytes = stripped.text.utf8.count
        let moved = stripped.credentials.count
        Self.logger.info("Imported \(request.fileName, privacy: .private), \(bytes) bytes, as \(id, privacy: .public)")
        Self.logger.info("\(channels) channels, \(moved) logins moved")
        return record
    }

    /// The guide link to store: nil when the field is empty, does not parse,
    /// or repeats the header's own link, which the loader reads with its
    /// login put back.
    static func guideLink(_ text: String, header: URL?) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host() != nil else { return nil }
        return url == header ? nil : url
    }

    /// The file source with `id`, nil when it was deleted.
    static func record(_ id: UUID, in context: ModelContext) -> SourceRecord? {
        var descriptor = FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The file source a file with `fileName` was imported as before: the
    /// lowest sort order, then the earliest creation date.
    static func importedBefore(_ fileName: String, in context: ModelContext) -> SourceRecord? {
        let name: String? = fileName
        let descriptor = FetchDescriptor<SourceRecord>(
            predicate: #Predicate { $0.fileName == name }, sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor))?.first { $0.kind == .m3uFile }
    }
}
