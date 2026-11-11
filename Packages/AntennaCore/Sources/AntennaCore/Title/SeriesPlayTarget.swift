import Foundation

/// The episode Play starts for a series, and whether it resumes
/// (title-detail-and-episode-picker/play-starts-the-right-episode).
/// The page, a series poster and Continue watching share this rule.
public struct SeriesPlayTarget: Sendable, Hashable {
    public var episode: Episode
    /// True when the episode is in progress and plays from `position`.
    public var resumes: Bool
    /// Seconds from the start; 0 unless `resumes`.
    public var position: Double

    public init(episode: Episode, resumes: Bool, position: Double) {
        self.episode = episode
        self.resumes = resumes
        self.position = position
    }

    /// "Resume S2 E4", "Play E3", "Play S2" or "Play".
    public var label: String {
        PlayLabel.text(resumes: resumes, episode: episode)
    }

    /// Picks the episode. `progress` holds the series' saved positions by
    /// episode id. Order is the season picker's: Season 1 to n, Specials,
    /// then Other.
    ///
    /// - Under 2% counts as not started, as does a record with no length.
    /// - An episode from 2% to under 95% resumes; with several, the latest
    ///   saved wins, and a tie goes to the earlier episode.
    /// - Otherwise the first episode under 95% after the latest saved one,
    ///   wrapping to the start.
    /// - With nothing saved, or every episode watched, the first episode.
    ///
    /// Nil without episodes.
    public static func resolve(episodes: [Episode], progress: [String: WatchProgress]) -> SeriesPlayTarget? {
        let ordered = SeasonGroup.group(episodes).flatMap(\.episodes)
        guard let first = ordered.first else { return nil }
        var resume: (index: Int, record: WatchProgress)?
        var lastWatched: (index: Int, record: WatchProgress)?
        for (index, episode) in zip(ordered.indices, ordered) {
            guard let record = progress[episode.id] else { continue }
            switch record.state {
            case .inProgress:
                if resume.map({ record.updatedAt > $0.record.updatedAt }) ?? true { resume = (index, record) }
            case .watched:
                if lastWatched.map({ record.updatedAt > $0.record.updatedAt }) ?? true { lastWatched = (index, record) }
            case .notStarted:
                continue
            }
        }
        if let resume {
            return SeriesPlayTarget(episode: ordered[resume.index], resumes: true, position: resume.record.position)
        }
        guard let lastWatched else { return SeriesPlayTarget(episode: first, resumes: false, position: 0) }
        let count = ordered.count
        for step in 1...count {
            let episode = ordered[(lastWatched.index + step) % count]
            if progress[episode.id]?.state != .watched {
                return SeriesPlayTarget(episode: episode, resumes: false, position: 0)
            }
        }
        return SeriesPlayTarget(episode: first, resumes: false, position: 0)
    }
}

/// The words on the Play button (title-detail-and-episode-picker).
public enum PlayLabel {
    /// "Play" or "Resume", followed for an episode by "S2 E3", "E3" or "S2"
    /// as far as the provider numbers it.
    public static func text(resumes: Bool, episode: Episode? = nil) -> String {
        let verb = resumes ? "Resume" : "Play"
        let code = [episode?.season.map { "S\($0)" }, episode?.number.map { "E\($0)" }].compactMap(\.self).joined(separator: " ")
        return code.isEmpty ? verb : "\(verb) \(code)"
    }
}
