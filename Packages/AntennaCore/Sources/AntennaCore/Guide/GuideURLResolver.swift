import Foundation

/// Works out where a source's guide lives. Sends nothing over the network.
public enum GuideURLResolver {
    /// The link the user entered (`epgURL`) when there is one. Otherwise, for
    /// `.m3u` the first of `playlistEPGURLs`, for `.xtream` the provider's
    /// `xmltv.php` link built from `url` and `credential`. Nil when none
    /// applies: a playlist that names no guide, an Xtream source without a
    /// credential, a Stalker portal without `epgURL`.
    public static func resolve(
        kind: SourceKind,
        url: URL,
        epgURL: URL?,
        playlistEPGURLs: [URL],
        credential: (username: String, password: String)?
    ) -> URL? {
        if let epgURL { return epgURL }
        switch kind {
        case .m3u:
            return playlistEPGURLs.first
        case .xtream:
            guard let credential else { return nil }
            let login = XtreamCredentials(server: url, username: credential.username, password: credential.password)
            return XtreamClient(credentials: login).xmltvURL()
        case .stalker:
            return nil
        }
    }
}
