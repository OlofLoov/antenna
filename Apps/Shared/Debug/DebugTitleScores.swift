#if DEBUG
    import AntennaCore
    import Foundation

    /// Sample scores and details on title pages while the lookup service
    /// does not exist, compiled into Debug builds only. The page labels
    /// every score from here "Sample".
    ///
    /// `-mock-title-scores YES` turns it on for one launch, and the Sample
    /// scores switch in Settings keeps it on. `-mock-title-scores-all-sites`
    /// also turns it on and adds IMDb, Rotten Tomatoes and Metacritic to
    /// TMDB, to try the full row. Matches are kept in memory only, never in
    /// the Caches folder the real service will use.
    enum DebugTitleScores {
        static let key = "mock-title-scores"
        static let allSitesArgument = "-mock-title-scores-all-sites"

        static var isOn: Bool {
            UserDefaults.standard.bool(forKey: key) || ProcessInfo.processInfo.arguments.contains(allSitesArgument)
        }

        static let lookup = KeptTitleLookup(
            base: MockTitleLookup(sites: ProcessInfo.processInfo.arguments.contains(allSitesArgument) ? Score.Site.allCases : [.tmdb]),
            directory: nil)
    }
#endif
