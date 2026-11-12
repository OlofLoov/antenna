import Foundation

/// Works out where a source's guide lives. Sends nothing over the network.
public enum GuideURLResolver {
    /// The link the user entered (`epgURL`) when there is one. Otherwise, for
    /// `.m3u` and `.m3uFile` the first of `playlistEPGURLs`, for `.xtream` the provider's
    /// `xmltv.php` link built from `url` and `credential`. Nil when none
    /// applies: a playlist that names no guide, an Xtream source without a
    /// credential, a Stalker portal without `epgURL`, which uses the
    /// portal's own guide instead (see `usesPortalGuide`). A Channels DVR
    /// server's guide is its own seven-day export
    /// (guide-data/guide-address-worked-out-from-the-source).
    public static func resolve(
        kind: SourceKind,
        url: URL,
        epgURL: URL?,
        playlistEPGURLs: [URL],
        credential: (username: String, password: String)?
    ) -> URL? {
        if let epgURL { return epgURL }
        switch kind {
        case .m3u, .m3uFile:
            return playlistEPGURLs.first
        case .xtream:
            guard let credential else { return nil }
            let login = XtreamCredentials(server: url, username: credential.username, password: credential.password)
            return XtreamClient(credentials: login).xmltvURL()
        case .stalker, .jellyfin:
            return nil
        case .channelsDVR:
            return ChannelsDVRClient(server: url).guideURL()
        }
    }

    /// True for a Stalker portal with no guide link entered. Its guide is
    /// then the portal's own, asked for with a signed request when it loads.
    public static func usesPortalGuide(kind: SourceKind, epgURL: URL?) -> Bool {
        kind == .stalker && epgURL == nil
    }
}
