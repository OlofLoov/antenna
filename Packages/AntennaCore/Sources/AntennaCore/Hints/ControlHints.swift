import Foundation

/// A button or gesture on the Siri Remote, as a remote hint names it.
public enum RemoteControl: String, CaseIterable, Sendable {
    case click, clickLeftRight, hold, swipeUpDown, swipeLeftRight, swipe, playPause, back

    /// What the legend calls it: "Click", "Swipe up or down", "Back".
    public var name: String {
        switch self {
        case .click: "Click"
        case .clickLeftRight: "Click left or right"
        case .hold: "Hold"
        case .swipeUpDown: "Swipe up or down"
        case .swipeLeftRight: "Swipe left or right"
        case .swipe: "Swipe"
        case .playPause: "Play/Pause"
        case .back: "Back"
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
    /// has set a new place that select plays from.
    case titlePlayer(scrubbing: Bool)
    /// Settings and the pages it opens.
    case settings

    /// Live full screen, with the info bar or without it.
    public static func live(swipe: AppPreferences.Swipe, infoBar: Bool) -> ControlHintScreen {
        infoBar ? .infoBar(swipe: swipe) : .livePicture(swipe: swipe)
    }

    /// Where the legend sits. The info bar and the players keep the bottom
    /// for the picture and the bar, so their legend goes top right
    /// (control-hints/hints-stay-out-of-the-way).
    public enum Corner: Sendable {
        case topTrailing, bottomTrailing
    }

    public var corner: Corner {
        switch self {
        case .livePicture, .infoBar, .titlePlayer: .topTrailing
        case .overlayGroups, .overlayChannels, .guide, .tabBar, .titleRows, .titlePage, .settings: .bottomTrailing
        }
    }

    /// The controls that do something here, most useful first, at most five.
    public var hints: [ControlHint] {
        switch self {
        case .livePicture(let swipe):
            [
                ControlHint(.click, "Channel list"),
                ControlHint(.swipeUpDown, swipe == .changesChannel ? "Change channel" : "Info bar"),
                ControlHint(.swipeLeftRight, "Last channel or Recents"),
                ControlHint(.hold, "Info, audio and subtitles"),
                ControlHint(.playPause, "Pause"),
            ]
        case .infoBar(let swipe):
            [
                ControlHint(.click, "Channel list"),
                swipe == .changesChannel ? ControlHint(.swipeUpDown, "Change channel") : nil,
                ControlHint(.hold, "Info, audio and subtitles"),
                ControlHint(.playPause, "Pause"),
                ControlHint(.back, "Hide the info bar"),
            ].compactMap(\.self)
        case .overlayGroups:
            [
                ControlHint(.swipeUpDown, "Choose a group"),
                ControlHint(.click, "Show its channels"),
                ControlHint(.back, "Close"),
            ]
        case .overlayChannels:
            [
                ControlHint(.click, "Watch"),
                ControlHint(.hold, "Add to or remove from Favorites"),
                ControlHint(.swipeLeftRight, "Groups or details"),
                ControlHint(.back, "Close"),
            ]
        case .guide:
            [
                ControlHint(.swipe, "Move through the guide"),
                ControlHint(.click, "Watch, or details for later"),
                ControlHint(.hold, "Add to or remove from Favorites"),
                ControlHint(.back, "Tab bar"),
            ]
        case .tabBar:
            [
                ControlHint(.swipeLeftRight, "Choose a tab"),
                ControlHint(.click, "Open"),
                ControlHint(.back, "Back to Live"),
            ]
        case .titleRows(.movie):
            [
                ControlHint(.click, "Play"),
                ControlHint(.hold, "More info and My list"),
                ControlHint(.back, "Tab bar"),
            ]
        case .titleRows(.series):
            [
                ControlHint(.click, "Open"),
                ControlHint(.hold, "My list"),
                ControlHint(.back, "Tab bar"),
            ]
        case .titlePage:
            [
                ControlHint(.click, "Play or choose"),
                ControlHint(.back, "Back"),
            ]
        case .titlePlayer(scrubbing: false):
            [
                ControlHint(.clickLeftRight, "Skip 10 seconds"),
                ControlHint(.swipeLeftRight, "Scrub"),
                ControlHint(.playPause, "Pause or play"),
                ControlHint(.hold, "Audio and subtitles"),
                ControlHint(.back, "Stop and go back"),
            ]
        case .titlePlayer(scrubbing: true):
            [
                ControlHint(.swipeLeftRight, "Move the new place"),
                ControlHint(.click, "Play from here"),
                ControlHint(.back, "Cancel"),
            ]
        case .settings:
            [
                ControlHint(.click, "Open or change"),
                ControlHint(.back, "Back or close"),
            ]
        }
    }

    /// The legend as one sentence for VoiceOver: "Remote: Click, Channel
    /// list. Hold, Info, audio and subtitles."
    public var spoken: String {
        "Remote: " + hints.map { "\($0.control.name), \($0.action)." }.joined(separator: " ")
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
        case .guide, .tabBar, .titleRows, .titlePage, .settings: self
        }
    }
}

/// When the legend shows (control-hints/hints-fade-and-come-back-on-a-new-screen):
/// on arriving at a new place, for `visibleFor`, at most
/// `showingsPerLaunch` times per place until the app launches again.
public struct ControlHintSchedule: Sendable {
    public static let visibleFor: Duration = .seconds(6)
    public static let showingsPerLaunch = 3

    private var current: ControlHintScreen?
    private var showings: [ControlHintScreen: Int] = [:]

    public init() {}

    /// Whether the legend should show as the highlight arrives at `screen`.
    /// Nil, as while focus moves between screens, changes nothing.
    public mutating func arrive(at screen: ControlHintScreen?) -> Bool {
        guard let place = screen?.place, place != current else { return false }
        current = place
        let count = showings[place, default: 0]
        guard count < Self.showingsPerLaunch else { return false }
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
