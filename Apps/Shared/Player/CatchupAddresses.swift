import AntennaCore
import Foundation

/// Builds catch-up addresses in the app: an Xtream channel's login comes
/// from the Keychain and its panel's time zone from `XtreamTimeZones`,
/// asked for once more when missing
/// (timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects).
/// Addresses carry the login, so they are never logged or stored.
struct CatchupAddresses: Sendable {
    var credentials: any CredentialStoring = CredentialStore()
    var timeZones: XtreamTimeZones = SourceLoader.sharedTimeZones
    var session: URLSession = .shared
    /// Answers in place of building, for UI tests.
    var scripted: (@Sendable (Channel, CatchupRequest) -> URL?)?

    /// The address for `request` on `channel` from `source`, nil when none can be built.
    func url(for channel: Channel, source: SourceDescriptor?, request: CatchupRequest) async -> URL? {
        if let scripted { return scripted(channel, request) }
        var context: XtreamCatchupContext?
        if let source, source.kind == .xtream, let key = source.credentialKey, let login = try? credentials.load(for: key) {
            let credentials = XtreamCredentials(server: source.url, username: login.username, password: login.password)
            let session = self.session
            let zone = await timeZones.timeZone(for: source.id) {
                try? await XtreamClient(credentials: credentials, session: session).accountInfo().serverInfo?.timezone
            }
            context = XtreamCatchupContext(credentials: credentials, timeZone: zone)
        }
        return CatchupURLBuilder.url(for: channel, request: request, xtream: context)
    }
}
