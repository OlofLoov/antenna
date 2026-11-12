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

    /// The time zones every loader in the app records into.
    static let sharedTimeZones = XtreamTimeZones()

    enum LoadError: LocalizedError, Equatable {
        /// The playlist URL answered with a status outside 200 to 299.
        case badStatus(Int)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): "The playlist server answered with status \(code)."
            }
        }
    }

    /// False when an Xtream or Stalker source has no Keychain item on this
    /// device yet. An item that cannot be read counts as present, so the load
    /// runs and reports the failure.
    func hasLogin(_ source: SourceDescriptor) -> Bool {
        guard source.kind != .m3u else { return true }
        guard let key = source.credentialKey else { return false }
        do {
            return try credentials.load(for: key) != nil
        } catch {
            return true
        }
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
        case .stalker:
            // TODO: Stalker/MAG portal handshake (handshake → get_profile → get_all_channels).
            return Playlist(channels: [])
        }
    }
}
