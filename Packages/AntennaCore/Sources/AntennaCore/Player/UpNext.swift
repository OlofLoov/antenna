import Foundation

/// Playing the next episode from the end of one (up-next capability): the
/// timing, which episode comes next, and the words on the button and card.
public enum UpNext {
    /// How long before the end the Next episode button shows.
    public static let buttonLead: Duration = .seconds(60)
    /// How long before the end the Up next card replaces the button.
    public static let cardLead: Duration = .seconds(15)
    /// Seconds the card counts down from.
    public static let countdown = 10
    /// Episodes shorter than this show the card only when they end.
    public static let shortEpisode: Duration = .seconds(5 * 60)
    /// Episodes started by the countdown in a row, with no input, before
    /// the card asks "Still watching?" instead.
    public static let askAfter = 3

    /// The episode after `current` in the season picker's order
    /// (up-next/which-episode-is-next): the next one in the same group,
    /// else, from a numbered season, the first episode of the next numbered
    /// season. Specials and Other lead only within their own group. Nil
    /// after the last episode, and when `current` is not in the list.
    public static func next(after current: Episode, in episodes: [Episode]) -> Episode? {
        let groups = SeasonGroup.group(episodes)
        guard let groupIndex = groups.firstIndex(where: { $0.episodes.contains { $0.id == current.id } }) else { return nil }
        let group = groups[groupIndex]
        if let index = group.episodes.firstIndex(where: { $0.id == current.id }), index + 1 < group.episodes.count {
            return group.episodes[index + 1]
        }
        guard case .season = group.kind, groupIndex + 1 < groups.count else { return nil }
        let following = groups[groupIndex + 1]
        guard case .season = following.kind else { return nil }
        return following.episodes.first
    }
}

/// What the end of one episode shows, fed with the engine's positions, its
/// end and one tick a second while the card counts down
/// (up-next/next-episode-near-the-end, up-next/up-next-counts-down,
/// up-next/cancel-keeps-watching, up-next/still-watching).
public struct UpNextTimer: Sendable, Equatable {
    /// What is on screen.
    public enum Offer: Sendable, Equatable {
        case none
        /// The small Next episode button.
        case button
        /// The card with this many seconds left.
        case countdown(Int)
        /// "Still watching?", with no countdown.
        case asking
    }

    /// What the player does after a call.
    public enum Step: Sendable, Equatable {
        case stay
        case playNext
        /// Back to where the episode started from.
        case close
    }

    public private(set) var offer = Offer.none
    /// True once the viewer pressed Cancel; nothing shows again this episode.
    public private(set) var cancelled = false
    /// True while the episode is over and its last frame shows.
    public private(set) var hasEnded = false

    public init() {}

    /// The engine reported `time` into an episode of `length`. `asks` is
    /// true when the card should ask "Still watching?" instead of counting.
    public mutating func position(_ time: Duration, length: Duration?, asks: Bool) {
        guard !cancelled, !hasEnded else { return }
        guard let length, length >= UpNext.shortEpisode else { return offer = .none }
        let left = length - time
        if left > UpNext.buttonLead {
            offer = .none
        } else if left > UpNext.cardLead {
            offer = .button
        } else {
            switch offer {
            case .countdown, .asking: break
            case .none, .button: offer = asks ? .asking : .countdown(UpNext.countdown)
            }
        }
    }

    /// The episode ended. A running count plays the next episode at once;
    /// an episode that showed no card yet shows it now.
    public mutating func ended(asks: Bool) -> Step {
        hasEnded = true
        if cancelled { return .close }
        switch offer {
        case .countdown: return .playNext
        case .asking: return .stay
        case .none, .button:
            offer = asks ? .asking : .countdown(UpNext.countdown)
            return .stay
        }
    }

    /// The episode plays again after it ended, as after a skip back.
    public mutating func playing() {
        guard hasEnded else { return }
        hasEnded = false
        offer = .none
    }

    /// One second passed with the card counting and the episode playing or
    /// ended. Returns `.playNext` at zero.
    public mutating func tick() -> Step {
        guard case .countdown(let left) = offer else { return .stay }
        if left <= 1 {
            offer = .countdown(0)
            return .playNext
        }
        offer = .countdown(left - 1)
        return .stay
    }

    /// Cancel, or Back on Apple TV: nothing shows for the rest of the
    /// episode, and an episode already over closes.
    public mutating func cancel() -> Step {
        cancelled = true
        offer = .none
        return hasEnded ? .close : .stay
    }

    /// The viewer did something, so a pending "Still watching?" counts down instead.
    public mutating func input() {
        if offer == .asking { offer = .countdown(UpNext.countdown) }
    }
}

/// Episodes started by the countdown in a row since the viewer last did
/// anything (up-next/still-watching).
public struct UpNextRun: Sendable, Equatable {
    public private(set) var inRow = 0

    public init() {}

    /// True when the next card should ask "Still watching?".
    public var asks: Bool { inRow >= UpNext.askAfter }

    /// The countdown started an episode.
    public mutating func autoplayed() { inRow += 1 }

    /// A press, tap, click or key, or a button on the card.
    public mutating func input() { inRow = 0 }
}

/// The words of the button and the card.
public enum UpNextText {
    public static func button(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Next episode")
    }
    public static func stillWatching(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Still watching?")
    }
    public static func playNow(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Play now")
    }
    public static func keepWatching(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Keep watching")
    }

    /// "S2 E5 · The Long Night", or the title alone without a number.
    public static func title(_ episode: Episode, locale: Locale = .autoupdatingCurrent) -> String {
        guard let code = ShelfText.episodeCode(episode) else { return episode.title }
        return [code, episode.title].joinedAsDetail(locale)
    }

    /// "Next episode in 7", or "Still watching?"; nil for no card.
    public static func heading(_ offer: UpNextTimer.Offer, locale: Locale = .autoupdatingCurrent) -> String? {
        switch offer {
        case .countdown(let left): Words(locale)("Next episode in \(left)")
        case .asking: stillWatching(locale)
        case .none, .button: nil
        }
    }

    /// "Up next, Season 2 Episode 5, The Long Night, next episode in 7
    /// seconds", or "Still watching? Season 2 Episode 5, The Long Night".
    public static func spoken(_ episode: Episode, offer: UpNextTimer.Offer, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        let code: String? =
            switch (episode.season, episode.number) {
            case (let season?, let number?): words("Season \(String(season)) Episode \(String(number))")
            case (let season?, nil): words("Season \(String(season))")
            case (nil, let number?): words("Episode \(String(number))")
            case (nil, nil): nil
            }
        let name = [code, episode.title].compactMap(\.self).joined(separator: ", ")
        switch offer {
        case .countdown(let left): return words("Up next, \(name), next episode in \(left) seconds")
        case .asking: return words("Still watching? \(name)")
        case .none, .button: return words("Next episode, \(name)")
        }
    }
}

/// Whether this device plays the next episode on its own
/// (up-next/turn-autoplay-off). Kept per device as JSON under
/// `player.autoplay`, never synced. A missing or unreadable value reads as on.
public struct AutoplaySetting: Codable, Equatable, Sendable {
    public static let key = "player.autoplay"

    public var plays: Bool

    public init(plays: Bool = true) {
        self.plays = plays
    }

    /// The stored setting, or the default (on) when nothing readable is stored.
    public static func decode(_ data: Data?) -> AutoplaySetting {
        guard let data, let setting = try? JSONDecoder().decode(AutoplaySetting.self, from: data) else { return AutoplaySetting() }
        return setting
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// The footer under the Settings row.
    public static func footer(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Plays the next episode of a series when one ends. Applies to this device only.")
    }
}
