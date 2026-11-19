#if os(iOS) || os(macOS)
    import Foundation

    /// A section of the iPad and Mac sidebar.
    enum LiveSection: Hashable, CaseIterable {
        case live, guide, movies, series, search, settings

        var title: LocalizedStringResource {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            case .series: "Series"
            case .search: "Search"
            case .settings: "Sources & Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .live: "tv"
            case .guide: "list.bullet.rectangle"
            case .movies: "film"
            case .series: "square.grid.2x2"
            case .search: "magnifyingglass"
            case .settings: "gearshape"
            }
        }

        /// `browse.section.<identifier>`.
        var identifier: String {
            switch self {
            case .live: "live"
            case .guide: "guide"
            case .movies: "movies"
            case .series: "series"
            case .search: "search"
            case .settings: "settings"
            }
        }
    }
#endif
