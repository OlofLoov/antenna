import AntennaCore
import Foundation
import Observation
import SwiftData

/// A source's details form (sources-and-settings/fix-a-source-s-link-or-login):
/// the name, the link, the guide link, the Xtream login, a portal's MAC
/// address and optional login, or a Channels DVR server address. The saved password never reaches a field;
/// an empty password field keeps it
/// (sources-and-settings/your-password-stays-hidden).
@MainActor @Observable
final class SourceEditor {
    let id: UUID
    let kind: SourceKind
    var name: String
    var link: String
    var guideLink: String
    /// The Xtream username, or a portal's optional login.
    var username: String
    /// A portal's MAC address. Other kinds leave it empty.
    var mac: String
    /// Empty until the user types a new password.
    var password = ""
    private(set) var error: String?
    private(set) var saving = false
    /// True when a login for this source is on this device.
    private(set) var hasLogin: Bool
    /// True when the login on this device has a password, which an empty field keeps.
    private(set) var hasPassword: Bool

    @ObservationIgnored private var original: SourceDescriptor
    @ObservationIgnored private let connector: SourceConnector
    /// Where this device keeps recents, the last channel and language picks.
    @ObservationIgnored var defaults: UserDefaults = .standard

    init(_ descriptor: SourceDescriptor, connector: SourceConnector) {
        id = descriptor.id
        kind = descriptor.kind
        original = descriptor
        self.connector = connector
        name = descriptor.name
        link = descriptor.url.absoluteString
        guideLink = descriptor.epgURL?.absoluteString ?? ""
        let saved = descriptor.credentialKey.flatMap { try? connector.credentials.load(for: $0) }
        if descriptor.kind == .stalker {
            mac = saved?.username ?? ""
            username = saved?.login ?? ""
        } else {
            mac = ""
            username = saved?.username ?? ""
        }
        hasLogin = saved != nil
        hasPassword = saved.map { !$0.password.isEmpty } ?? false
    }

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var savedLogin: CredentialStore.Credential? {
        original.credentialKey.flatMap { try? connector.credentials.load(for: $0) }
    }

    /// The link or the login differs from what is saved, so Save asks the server first.
    var needsCheck: Bool {
        let saved = savedLogin
        let linkChanged = trimmedLink != original.url.absoluteString || !password.isEmpty
        switch kind {
        case .m3u, .m3uFile: return linkChanged
        case .xtream, .jellyfin: return linkChanged || username != (saved?.username ?? "")
        case .stalker: return linkChanged || mac != (saved?.username ?? "") || username != (saved?.login ?? "")
        case .channelsDVR: return linkChanged
        }
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
        if kind == .channelsDVR, let problem = SourceFields(kind: .channelsDVR, url: trimmedLink).check() {
            error = problem.message
            return false
        }
        let typed = kind == .channelsDVR ? ChannelsDVRClient.serverURL(from: trimmedLink) : URL(string: trimmedLink)
        guard var url = typed, url.scheme != nil else {
            error = ConnectFailure.invalidURL.message
            return false
        }
        if kind == .stalker {
            guard let portal = StalkerPortal(trimmedLink) else {
                error = ConnectFailure.invalidURL.message
                return false
            }
            url = portal.url
            if let problem = SourceFields(kind: .stalker, url: trimmedLink, mac: mac).check() {
                error = problem.message
                return false
            }
        }
        if kind == .jellyfin, SourceFields(kind: .jellyfin, url: trimmedLink, username: "-", password: "-").check() != nil {
            error = ConnectFailure.invalidURL.message
            return false
        }
        if isDuplicate(url, in: context) {
            error = "This source is already added."
            return false
        }
        let saved = savedLogin
        // source-management/an-xtream-source-needs-a-username-and-password
        if kind == .xtream || kind == .jellyfin, username.isBlank || (saved == nil && password.isBlank) {
            error = "Enter your username and password."
            return false
        }
        let login = credential(saved: saved)
        saving = true
        defer { saving = false }
        do {
            _ = try await connector.probe(
                kind, link: url, username: login.username, password: login.password, login: login.login, host: url.host() ?? trimmedLink)
        } catch is CancellationError {
            return false
        } catch {
            self.error = ConnectFailure(error, host: url.host() ?? trimmedLink).message
            return false
        }
        if kind == .xtream || kind == .stalker || kind == .jellyfin {
            let key = record.credentialKey ?? record.id.uuidString
            do {
                try connector.credentials.save(login, for: key)
            } catch {
                self.error = ConnectFailure.credentials("\(error)").message
                return false
            }
            record.credentialKey = key
            hasLogin = true
            hasPassword = !login.password.isEmpty
            if kind == .stalker { mac = login.username }
            // A changed Jellyfin login signs in afresh on the next load.
            if kind == .jellyfin { connector.jellyfinClients.forget(sourceID: record.id, storeKey: key) }
        }
        password = ""
        apply(to: record, url: url, in: context)
        return true
    }

    /// The panel login in the link field of a playlist source, which can
    /// switch to Xtream (source-management/a-playlist-source-switches-to-xtream-in-place).
    var xtreamPanel: XtreamPanelLink? {
        kind == .m3u ? XtreamPanelLink(link) : nil
    }

    /// Use Xtream on a playlist source whose link is a panel link. Checks the
    /// login with the panel, then turns the source into an Xtream login in
    /// place: same id, name, order and guide link, the server as its link and
    /// the login in the Keychain. Favorites and own-group channels of
    /// `channels` move to their Xtream ids, and so do this device's recents,
    /// last channel and language picks and the source's guide matches
    /// (source-management/switching-to-xtream-keeps-what-was-remembered-per-channel). Changes nothing and sets `error`
    /// when a check fails. Returns the new descriptor, after which the caller
    /// reloads the source.
    func switchToXtream(channels: [Channel], in context: ModelContext) async -> SourceDescriptor? {
        guard !saving, let panel = xtreamPanel, let record = record(in: context) else { return nil }
        error = nil
        let login = panel.credentials
        let host = login.server.host() ?? login.server.absoluteString
        if isDuplicateXtream(login, in: context) {
            error = "This source is already added."
            return nil
        }
        saving = true
        defer { saving = false }
        do {
            _ = try await connector.probe(.xtream, link: login.server, username: login.username, password: login.password, host: host)
        } catch is CancellationError {
            return nil
        } catch {
            self.error = ConnectFailure(error, host: host).message
            return nil
        }
        let key = record.credentialKey ?? record.id.uuidString
        do {
            try connector.credentials.save(.init(username: login.username, password: login.password), for: key)
        } catch {
            self.error = ConnectFailure.credentials("\(error)").message
            return nil
        }
        let ids = panel.liveChannelIDs(for: channels.filter { $0.sourceID == id })
        record.kindRaw = SourceKind.xtream.rawValue
        record.url = login.server
        record.credentialKey = key
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { record.name = trimmedName }
        let guide = guideLink.trimmingCharacters(in: .whitespacesAndNewlines)
        record.epgURL = guide.isEmpty ? nil : URL(string: guide)
        ChannelIDMigration.rewrite(ids, source: id, in: context)
        try? context.save()
        ChannelIDMigration.moveRemembered(ids, source: id, defaults: defaults, in: context)
        return record.descriptor
    }

    /// Another Xtream source on the same server whose login on this device has the same username.
    private func isDuplicateXtream(_ login: XtreamCredentials, in context: ModelContext) -> Bool {
        let key = SourceLink.key(login.server)
        let others = ((try? context.fetch(FetchDescriptor<SourceRecord>())) ?? []).filter {
            $0.id != id && $0.kind == .xtream && $0.url.map(SourceLink.key) == key
        }
        return others.contains { other in
            guard let key = other.credentialKey, let saved = try? connector.credentials.load(for: key) else { return false }
            return saved.username == login.username
        }
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

    /// The login Save checks and keeps: the typed password, or the saved
    /// one when the field is empty. A portal's MAC goes in colon form.
    private func credential(saved: CredentialStore.Credential?) -> CredentialStore.Credential {
        let password = password.isBlank ? (saved?.password ?? "") : password
        guard kind == .stalker else { return .init(username: username, password: password) }
        let fields = SourceFields(kind: .stalker, username: username, password: password, mac: mac)
        return SourceConnector.credential(for: fields) ?? .init(username: mac, password: password)
    }

    /// Another source of the same type with the same link; for Xtream also
    /// the same username, and for a portal the same MAC, in its login on
    /// this device.
    private func isDuplicate(_ url: URL, in context: ModelContext) -> Bool {
        let key = SourceLink.key(url)
        let others = ((try? context.fetch(FetchDescriptor<SourceRecord>())) ?? []).filter {
            $0.id != id && $0.kind == kind && $0.url.map(SourceLink.key) == key
        }
        let account: String
        switch kind {
        case .m3u, .m3uFile, .channelsDVR: return !others.isEmpty
        case .xtream, .jellyfin: account = username
        case .stalker: account = MACAddress(mac)?.text ?? mac
        }
        return others.contains { other in
            guard let key = other.credentialKey, let login = try? connector.credentials.load(for: key) else { return false }
            return login.username == account
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
