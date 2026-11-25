import Foundation

/// A button or gesture on the Siri Remote, as a remote hint names it.
public enum RemoteControl: String, CaseIterable, Sendable {
    case click, clickLeftRight, hold, swipeUpDown, swipeDown, swipeLeftRight, swipe, playPause, back

    /// What the legend calls it: "Click", "Swipe up or down", "Back".
    public var name: String { name(.autoupdatingCurrent) }

    public func name(_ locale: Locale) -> String {
        let words = Words(locale)
        return switch self {
        case .click: words("Click")
        case .clickLeftRight: words("Click left or right")
        case .hold: words("Hold")
        case .swipeUpDown: words("Swipe up or down")
        case .swipeDown: words("Swipe down")
        case .swipeLeftRight: words("Swipe left or right")
        case .swipe: words("Swipe")
        case .playPause: words("Play/Pause")
        case .back: words("Back")
        }
    }
}

/// One line of the legend: a control and what it does on this screen.
public struct ControlHint: Hashable, Sendable {
    public let control: RemoteControl
    public let action: String

    public init(_ control: RemoteControl, _ action: String) {
        self.control = control
        self.action = action
    }
}

/// An Apple TV screen that has remote hints, with what decides its list
/// (control-hints/each-screen-lists-its-own-actions).
public enum ControlHintScreen: Hashable, Sendable {
    /// Live full screen with nothing over the picture. The swipe preference
    /// decides what up and down do.
    case livePicture(swipe: AppPreferences.Swipe)
    /// Live full screen with the info bar along the bottom.
    case infoBar(swipe: AppPreferences.Swipe)
    /// The channel overlay with the highlight in the groups.
    case overlayGroups
    /// The channel overlay with the highlight on a channel or its panel.
    case overlayChannels
    /// The guide grid and its panel.
    case guide
    /// The highlight in the tab bar.
    case tabBar
    /// The Movies or Series rows, or a grid opened from them.
    case titleRows(ShelfTitle.Kind)
    /// A movie's or series' page.
    case titlePage
    /// A movie or episode playing full screen; while scrubbing, a slide
    /// has set a new place that select plays from. `nextEpisode` while the
    /// Next episode button shows (up-next/up-next-on-the-siri-remote).
    case titlePlayer(scrubbing: Bool, nextEpisode: Bool = false)
    /// Focus on the Next episode button.
    case nextEpisodeButton
    /// The Up next card, or "Still watching?" when `asking`.
    case upNext(asking: Bool)
    /// Settings and the pages it opens.
    case settings

    /// Live full screen, with the info bar or without it.
    public static func live(swipe: AppPreferences.Swipe, infoBar: Bool) -> ControlHintScreen {
        infoBar ? .infoBar(swipe: swipe) : .livePicture(swipe: swipe)
    }

    /// The controls that do something here, most useful first, at most five.
    public var hints: [ControlHint] { hints(.autoupdatingCurrent) }

    public func hints(_ locale: Locale) -> [ControlHint] { hints(Words(locale)) }

    private func hints(_ words: Words) -> [ControlHint] {
        switch self {
        case .livePicture(let swipe):
            [
                ControlHint(.click, words("Channel list")),
                ControlHint(.swipeUpDown, swipe == .changesChannel ? words("Change channel") : words("Info bar")),
                ControlHint(.swipeLeftRight, words("Last channel or Recents")),
                ControlHint(.hold, words("Info, audio and subtitles")),
                ControlHint(.back, words("Tab bar")),
            ]
        case .infoBar(let swipe):
            [
                ControlHint(.click, words("Channel list")),
                swipe == .changesChannel ? ControlHint(.swipeUpDown, words("Change channel")) : nil,
                ControlHint(.hold, words("Info, audio and subtitles")),
                ControlHint(.playPause, words("Pause")),
                ControlHint(.back, words("Hide the info bar")),
            ].compactMap(\.self)
        case .overlayGroups:
            [
                ControlHint(.swipeUpDown, words("Choose a group")),
                ControlHint(.click, words("Show its channels")),
                ControlHint(.back, words("Close")),
            ]
        case .overlayChannels:
            [
                ControlHint(.click, words("Watch")),
                ControlHint(.hold, words("Add to or remove from Favorites")),
                ControlHint(.swipeLeftRight, words("Groups or details")),
                ControlHint(.back, words("Close")),
            ]
        case .guide:
            [
                ControlHint(.swipe, words("Move through the guide")),
                ControlHint(.click, words("Watch, or details for later")),
                ControlHint(.hold, words("Add to or remove from Favorites")),
                ControlHint(.back, words("Tab bar")),
            ]
        case .tabBar:
            [
                ControlHint(.swipeLeftRight, words("Choose a tab")),
                ControlHint(.click, words("Open")),
                ControlHint(.back, words("Home Screen")),
            ]
        default:
            titleHints(words)
        }
    }

    /// Movies, series and their players, Up next and Settings.
    private func titleHints(_ words: Words) -> [ControlHint] {
        switch self {
        case .titleRows:
            [
                ControlHint(.click, words("Open")),
                ControlHint(.hold, words("My list")),
                ControlHint(.back, words("Tab bar")),
            ]
        case .titlePage:
            [
                ControlHint(.click, words("Play or choose")),
                ControlHint(.back, words("Back")),
            ]
        case .titlePlayer(scrubbing: false, nextEpisode: true):
            [
                ControlHint(.clickLeftRight, words("Skip 10 seconds")),
                ControlHint(.swipeDown, words("Next episode")),
                ControlHint(.playPause, words("Pause or play")),
                ControlHint(.hold, words("Audio and subtitles")),
                ControlHint(.back, words("Stop and go back")),
            ]
        case .titlePlayer(scrubbing: false, nextEpisode: false):
            [
                ControlHint(.clickLeftRight, words("Skip 10 seconds")),
                ControlHint(.swipeLeftRight, words("Scrub")),
                ControlHint(.playPause, words("Pause or play")),
                ControlHint(.hold, words("Audio and subtitles")),
                ControlHint(.back, words("Stop and go back")),
            ]
        case .titlePlayer(scrubbing: true, _):
            [
                ControlHint(.swipeLeftRight, words("Move the new place")),
                ControlHint(.click, words("Play from here")),
                ControlHint(.back, words("Cancel")),
            ]
        case .nextEpisodeButton:
            [
                ControlHint(.click, words("Play the next episode")),
                ControlHint(.back, words("Keep watching")),
            ]
        case .upNext(asking: false):
            [
                ControlHint(.click, words("Play now")),
                ControlHint(.clickLeftRight, words("Skip 10 seconds")),
                ControlHint(.playPause, words("Pause or play")),
                ControlHint(.back, words("Cancel")),
            ]
        case .upNext(asking: true):
            [
                ControlHint(.click, words("Keep watching")),
                ControlHint(.back, words("Cancel")),
            ]
        case .settings:
            [
                ControlHint(.click, words("Open or change")),
                ControlHint(.back, words("Back or close")),
            ]
        default:
            []
        }
    }

    /// The legend as one sentence for VoiceOver: "Remote: Click, Channel
    /// list. Hold, Info, audio and subtitles."
    public var spoken: String { spoken(.autoupdatingCurrent) }

    public func spoken(_ locale: Locale) -> String {
        let words = Words(locale)
        let items = hints(locale).map { words("\($0.control.name(locale)), \($0.action).") }.joined(separator: " ")
        return words("Remote: \(items)")
    }
}

extension ControlHintScreen {
    /// Screens that count as one place for the schedule. The info bar
    /// coming and going over the picture, the highlight crossing from the
    /// groups to the channels, or a slide starting a scrub does not bring
    /// the legend back.
    var place: ControlHintScreen {
        switch self {
        case .livePicture, .infoBar: .livePicture(swipe: .changesChannel)
        case .overlayGroups, .overlayChannels: .overlayGroups
        case .titlePlayer: .titlePlayer(scrubbing: false)
        case .upNext: .upNext(asking: false)
        case .guide, .tabBar, .titleRows, .titlePage, .settings, .nextEpisodeButton: self
        }
    }

    /// Live TV, Movies or Series, the parts of the app the viewer switches
    /// between in the tab bar. The guide is part of Live. The tab bar,
    /// title pages, the players and Settings belong to none, so passing
    /// through them does not count as a switch.
    enum Section: Hashable, Sendable {
        case live, movies, series
    }

    var section: Section? {
        switch self {
        case .livePicture, .infoBar, .overlayGroups, .overlayChannels, .guide: .live
        case .titleRows(.movie): .movies
        case .titleRows(.series): .series
        case .tabBar, .titlePage, .titlePlayer, .nextEpisodeButton, .upNext, .settings: nil
        }
    }
}

/// When the legend shows (control-hints/hints-fade-and-come-back-on-a-new-screen):
/// on arriving at a new place, for `visibleFor`, at most
/// `showingsPerLaunch` times per place until the app launches again.
/// Moving to another section always shows it, past that limit. The first
/// arrival at the live picture and at the title player is the first time
/// something plays, so it shows like every first arrival.
public struct ControlHintSchedule: Sendable {
    public static let visibleFor: Duration = .seconds(6)
    public static let showingsPerLaunch = 3

    private var current: ControlHintScreen?
    private var section: ControlHintScreen.Section?
    private var showings: [ControlHintScreen: Int] = [:]

    public init() {}

    /// Whether the legend should show as the highlight arrives at `screen`.
    /// Nil, as while focus moves between screens, changes nothing.
    public mutating func arrive(at screen: ControlHintScreen?) -> Bool {
        guard let screen, screen.place != current else { return false }
        let place = screen.place
        current = place
        var switched = false
        if let section = screen.section {
            switched = section != self.section
            self.section = section
        }
        let count = showings[place, default: 0]
        guard switched || count < Self.showingsPerLaunch else { return false }
        showings[place] = count + 1
        return true
    }
}

/// Whether this device shows remote hints (control-hints/turn-remote-hints-off).
/// Kept per device as JSON under `hints.remote`, never synced. A missing or
/// unreadable value reads as on.
public struct ControlHintsSetting: Codable, Equatable, Sendable {
    public static let key = "hints.remote"

    public var shows: Bool

    public init(shows: Bool = true) {
        self.shows = shows
    }

    /// The stored setting, or the default (on) when nothing readable is stored.
    public static func decode(_ data: Data?) -> ControlHintsSetting {
        guard let data, let setting = try? JSONDecoder().decode(ControlHintsSetting.self, from: data) else {
            return ControlHintsSetting()
        }
        return setting
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
