import AntennaCore
import Foundation
import Observation
import SwiftData

/// A source's details form (sources-and-settings/fix-a-source-s-link-or-login):
/// the name, the link, the guide link and the Xtream login. The saved
/// password never reaches a field; an empty password field keeps it
/// (sources-and-settings/your-password-stays-hidden).
@MainActor @Observable
final class SourceEditor {
    let id: UUID
    let kind: SourceKind
    var name: String
    var link: String
    var guideLink: String
    var username: String
    /// Empty until the user types a new password.
    var password = ""
    private(set) var error: String?
    private(set) var saving = false
    /// True when a login for this source is on this device.
    private(set) var hasLogin: Bool

    @ObservationIgnored private var original: SourceDescriptor
    @ObservationIgnored private let connector: SourceConnector

    init(_ descriptor: SourceDescriptor, connector: SourceConnector) {
        id = descriptor.id
        kind = descriptor.kind
        original = descriptor
        self.connector = connector
        name = descriptor.name
        link = descriptor.url.absoluteString
        guideLink = descriptor.epgURL?.absoluteString ?? ""
        let saved = descriptor.credentialKey.flatMap { try? connector.credentials.load(for: $0) }
        username = saved?.username ?? ""
        hasLogin = saved != nil
    }

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The link or the login differs from what is saved, so Save asks the server first.
    var needsCheck: Bool {
        guard kind != .stalker else { return false }
        let saved = original.credentialKey.flatMap { try? connector.credentials.load(for: $0) }
        return trimmedLink != original.url.absoluteString || !password.isEmpty || (kind == .xtream && username != (saved?.username ?? ""))
    }

    /// Saves the form. A changed name or guide link saves at once; a
    /// changed link or login is checked against the server first and saves
    /// only when the check works. Returns true when something was saved,
    /// after which the caller reloads the source.
    @discardableResult
    func save(in context: ModelContext) async -> Bool {
        guard !saving, let record = record(in: context) else { return false }
        error = nil
        guard needsCheck else {
            apply(to: record, url: original.url, in: context)
            return true
        }
        guard let url = URL(string: trimmedLink), url.scheme != nil else {
            error = ConnectFailure.invalidURL.message
            return false
        }
        if isDuplicate(url, in: context) {
            error = "This source is already added."
            return false
        }
        let saved = original.credentialKey.flatMap { try? connector.credentials.load(for: $0) }
        // source-management/an-xtream-source-needs-a-username-and-password
        if kind == .xtream, username.isBlank || (saved == nil && password.isBlank) {
            error = "Enter your username and password."
            return false
        }
        let login = CredentialStore.Credential(username: username, password: password.isBlank ? (saved?.password ?? "") : password)
        saving = true
        defer { saving = false }
        do {
            _ = try await connector.probe(
                kind, link: url, username: login.username, password: login.password, host: url.host() ?? trimmedLink)
        } catch is CancellationError {
            return false
        } catch {
            self.error = ConnectFailure(error, host: url.host() ?? trimmedLink).message
            return false
        }
        if kind == .xtream {
            let key = record.credentialKey ?? record.id.uuidString
            do {
                try connector.credentials.save(login, for: key)
            } catch {
                self.error = ConnectFailure.credentials("\(error)").message
                return false
            }
            record.credentialKey = key
            hasLogin = true
        }
        password = ""
        apply(to: record, url: url, in: context)
        return true
    }

    private func apply(to record: SourceRecord, url: URL, in context: ModelContext) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // An emptied name is replaced by the link's host.
        name = trimmedName.isEmpty ? url.host() ?? "Source" : name
        record.name = name
        record.url = url
        let guide = guideLink.trimmingCharacters(in: .whitespacesAndNewlines)
        record.epgURL = guide.isEmpty ? nil : URL(string: guide)
        try? context.save()
        if let descriptor = record.descriptor { original = descriptor }
        link = url.absoluteString
    }

    /// Another source of the same type with the same link; for Xtream also
    /// the same username in its login on this device.
    private func isDuplicate(_ url: URL, in context: ModelContext) -> Bool {
        let key = SourceLink.key(url)
        let others = ((try? context.fetch(FetchDescriptor<SourceRecord>())) ?? []).filter {
            $0.id != id && $0.kind == kind && $0.url.map(SourceLink.key) == key
        }
        guard kind == .xtream else { return !others.isEmpty }
        return others.contains { other in
            guard let key = other.credentialKey, let login = try? connector.credentials.load(for: key) else { return false }
            return login.username == username
        }
    }

    func record(in context: ModelContext) -> SourceRecord? {
        let id = id
        return try? context.fetch(FetchDescriptor<SourceRecord>(predicate: #Predicate { $0.id == id })).first
    }
}

extension String {
    fileprivate var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
