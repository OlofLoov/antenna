import AntennaCore
import Foundation
import SwiftUI

extension EnvironmentValues {
    /// The loader the Live screen uses. Tests replace it with one on a stubbed session.
    @Entry var sourceLoader = SourceLoader()
}

/// Turns a stored source into channels. Lives in the app layer because it
/// needs the Keychain; the parsers themselves are in AntennaCore.
struct SourceLoader: Sendable {
    var session: URLSession = .shared
    var credentials: any CredentialStoring = CredentialStore()
    /// Where each load leaves its Xtream panel's time zone, for catch-up.
    var timeZones: XtreamTimeZones = SourceLoader.sharedTimeZones
    /// Where imported files' text is read from.
    var files: PlaylistFileStore = .shared
    /// The per-source portal clients, shared with the guide and playback.
    var stalkerClients: StalkerClients = .shared

    /// The time zones every loader in the app records into.
    static let sharedTimeZones = XtreamTimeZones()

    enum LoadError: LocalizedError, Equatable {
        /// The playlist URL answered with a status outside 200 to 299.
        case badStatus(Int)
        /// A file source whose text has not arrived through iCloud.
        case waitingForICloud
        /// A file source whose Keychain item cannot be read, or holds fewer
        /// logins than its links name. No request is made.
        case loginUnreadable

        /// A Stalker portal call failed for a reason other than the
        /// connection, which arrives as a `URLError` instead.
        case portal(StalkerError)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): "The playlist server answered with status \(code)."
            case .waitingForICloud: "Waiting for its playlist to sync from iCloud."
            case .loginUnreadable: "Its saved login is unreadable. Re-import the file."
            case .portal(let error): Self.message(error)
            }
        }

        private static func message(_ error: StalkerError) -> String {
            switch error {
            case .serverError(let status): "The portal answered with status \(status)."
            case .notAuthorized: "The portal turned down this MAC address or login."
            case .deviceRefused(let message): "The portal turned this device down. It said “\(message)”."
            case .noPortal: "No Stalker portal answered at this address."
            case .transport, .unreadable, .notStalkerChannel, .noLink: "The portal replied with something Antenna could not read."
            }
        }
    }

    /// False when an Xtream or Stalker source has no Keychain item on this
    /// device yet, or a Stalker item's username is not a MAC. An item that
    /// cannot be read counts as present, so the load runs and reports the
    /// failure.
    func hasLogin(_ source: SourceDescriptor) -> Bool {
        guard source.kind != .m3u else { return true }
        if source.kind == .m3uFile {
            guard files.hasContents(source.id) else { return false }
            guard source.credentialKey != nil else { return true }
        }
        guard let key = source.credentialKey else { return false }
        do {
            guard let found = try credentials.load(for: key) else { return false }
            return source.kind != .stalker || MACAddress(found.username) != nil
        } catch {
            return true
        }
    }

    /// True for a file source whose text is not on this device yet; it
    /// shows as waiting for iCloud rather than for its login.
    func waitsForICloud(_ source: SourceDescriptor) -> Bool {
        source.kind == .m3uFile && !files.hasContents(source.id)
    }

    /// The source's channels, and for a playlist the guide links its header names.
    func load(_ source: SourceDescriptor) async throws -> Playlist {
        switch source.kind {
        case .m3u:
            let (data, response) = try await session.data(from: source.url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LoadError.badStatus(http.statusCode)
            }
            let text = String(decoding: data, as: UTF8.self)
            return M3UParser().parse(text)
        case .xtream:
            guard let key = source.credentialKey,
                let cred = try credentials.load(for: key)
            else { return Playlist(channels: []) }
            let client = XtreamClient(
                credentials: .init(server: source.url, username: cred.username, password: cred.password),
                session: session)
            let live = try await client.liveLoad()
            await timeZones.loaded(source.id, timeZoneName: live.timeZoneName)
            return Playlist(channels: live.channels, serverTimeZone: live.timeZoneName)
        case .m3uFile:
            return try loadFile(source)
        case .stalker:
            guard let key = source.credentialKey, let cred = try credentials.load(for: key),
                let client = stalkerClients.client(for: source, credential: cred)
            else { return Playlist(channels: []) }
            do {
                return Playlist(channels: try await client.liveLoad(guide: source.epgURL == nil ? .portal : .xmltv).channels)
            } catch StalkerError.transport(let code) {
                throw URLError(code)
            } catch let error as StalkerError {
                throw LoadError.portal(error)
            }
        }
    }

    /// An imported file from the store, with the logins from its Keychain
    /// item put back into its links. Makes no network request.
    private func loadFile(_ source: SourceDescriptor) throws -> Playlist {
        guard let contents = files.contents(of: source.id) else { throw LoadError.waitingForICloud }
        guard let key = source.credentialKey else {
            return PlaylistImport.playlist(stored: contents.text, restored: contents.text)
        }
        let logins: [StreamCredential]?
        do {
            logins = try StreamLoginStore(credentials: credentials).load(for: key)
        } catch {
            throw LoadError.loginUnreadable
        }
        guard let logins, let token = contents.token else { throw LoadError.loginUnreadable }
        do {
            let restored = try PlaylistImport.restoreCredentials(contents.text, credentials: logins, token: token)
            return PlaylistImport.playlist(stored: contents.text, restored: restored)
        } catch {
            throw LoadError.loginUnreadable
        }
    }
}
