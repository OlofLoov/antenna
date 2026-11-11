#if os(iOS) || os(macOS)
    import AntennaCore

    /// The iPad and Mac sections as the session stores them
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    extension LiveSection {
        /// Movies and Series without an Xtream source open Live.
        init(_ tab: LiveSession.Tab, hasXtream: Bool) {
            switch tab {
            case .guide: self = .guide
            case .movies: self = hasXtream ? .movies : .live
            case .series: self = hasXtream ? .series : .live
            case .live, .search, .settings: self = .live
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
