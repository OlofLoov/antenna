#if DEBUG
    import Foundation

    /// Made-up matches for previews, tests and Debug builds while the lookup
    /// service does not exist. Compiled into Debug builds only, and
    /// `scripts/check-rules.sh` fails when code outside `#if DEBUG` names it.
    ///
    /// Every answer is worked out from the title's folded name, so the same
    /// title gets the same scores on every run and every device. Each match
    /// is marked `isSample`, and the page labels its scores "Sample". It
    /// fills no backdrop, so nothing reaches the network.
    public struct MockTitleLookup: TitleLookup {
        /// The sites that get a score, TMDB alone by default as in the first release.
        public var sites: [Score.Site]

        public init(sites: [Score.Site] = [.tmdb]) {
            self.sites = sites
        }

        public func match(_ query: TitleLookupQuery) async throws -> TitleMatch? {
            let key = TitleName.folded(query.name)
            guard !key.isEmpty else { return nil }
            let hash = Self.stableHash(key)
            let scores = sites.map { Self.score($0, hash: hash) }
            let genres = ["Drama", "Thriller", "Comedy", "Adventure", "Science Fiction", "Crime"]
            let details = TitleDetails(
                plot: "Sample description for \(query.name), made up by the mock lookup.",
                year: query.year ?? 1980 + Int(hash % 45),
                duration: query.kind == .movie ? TimeInterval(85 + Int((hash >> 12) % 70)) * 60 : nil,
                genre: genres[Int((hash >> 20) % UInt64(genres.count))],
                cast: "Sample Actor One, Sample Actor Two, Sample Actor Three",
                director: "Sample Director")
            return TitleMatch(tmdbID: 1 + Int(hash % 900_000), details: details, scores: scores, isSample: true)
        }

        /// TMDB 50 to 90%, IMDb 5.0 to 9.0, Rotten Tomatoes 40 to 100%,
        /// Metacritic 40 to 90, each from different bits of the hash.
        static func score(_ site: Score.Site, hash: UInt64) -> Score {
            switch site {
            case .tmdb: Score(site: .tmdb, value: 5 + Double(hash % 41) / 10, scale: 10)
            case .imdb: Score(site: .imdb, value: 5 + Double((hash >> 8) % 41) / 10, scale: 10)
            case .rottenTomatoes: Score(site: .rottenTomatoes, value: 40 + Double((hash >> 16) % 61), scale: 100)
            case .metacritic: Score(site: .metacritic, value: 40 + Double((hash >> 24) % 51), scale: 100)
            }
        }

        /// 64-bit FNV-1a of the UTF-8 bytes. Swift's `Hasher` is seeded per
        /// launch, so it would change the scores on every run.
        public static func stableHash(_ text: String) -> UInt64 {
            text.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
        }
    }
#endif
