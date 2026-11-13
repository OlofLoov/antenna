#if os(iOS) || os(macOS)
    import AntennaCore

    /// The iPad and Mac sections as the session stores them
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    extension LiveSection {
        /// Movies and Series open only when a source offers them, else Live
        /// (m3u-playlists/what-a-playlist-offered-is-remembered).
        init(_ tab: LiveSession.Tab, offer: TitleOffer) {
            switch tab {
            case .guide: self = .guide
            case .movies: self = offer.movies ? .movies : .live
            case .series: self = offer.series ? .series : .live
            case .live, .search, .settings: self = .live
            }
        }

        /// The titles section to open for Movies: Movies, or Series when
        /// only series are offered.
        static func titles(_ offer: TitleOffer) -> LiveSection {
            !offer.movies && offer.series ? .series : .movies
        }

        /// False for Movies or Series when the sources do not offer it.
        func isOffered(by offer: TitleOffer) -> Bool {
            switch self {
            case .movies: offer.movies
            case .series: offer.series
            default: true
            }
        }

        var session: LiveSession.Tab {
            switch self {
            case .live: .live
            case .guide: .guide
            case .movies: .movies
            case .series: .series
            case .search: .search
            case .settings: .settings
            }
        }
    }
#endif
