import Foundation

/// A key on a hardware keyboard, as a menu item names it.
public enum Key: Hashable, Sendable {
    case character(Character)
    case space
    case delete
    case upArrow, downArrow, leftArrow, rightArrow
}

/// The modifier keys held with a `Key`.
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let shift = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let control = KeyModifiers(rawValue: 1 << 3)
}

/// A key with its modifiers.
public struct KeyCombination: Hashable, Sendable {
    public var key: Key
    public var modifiers: KeyModifiers

    public init(_ key: Key, _ modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Combinations macOS and iPadOS keep for themselves or for their
    /// standard menu items (keyboard-commands/shortcuts-stay-clear-of-the-system-s).
    /// Command-Comma is in the list too; only Sources & Settings may use it.
    public static let reserved: Set<KeyCombination> = {
        let command: [Character] = ["q", "w", "h", "m", "n", "`", "x", "c", "v", "z", "a", ","]
        var set = Set(command.map { KeyCombination(.character($0), .command) })
        set.insert(KeyCombination(.character("\t"), .command))
        set.insert(KeyCombination(.space, .command))
        set.insert(KeyCombination(.character("z"), [.command, .shift]))
        set.insert(KeyCombination(.character("f"), [.command, .control]))
        set.insert(KeyCombination(.character("q"), [.command, .control]))
        for digit: Character in ["3", "4", "5"] { set.insert(KeyCombination(.character(digit), [.command, .shift])) }
        set.insert(KeyCombination(.character("\u{1B}"), [.command, .option]))
        return set
    }()
}

/// The menus Antenna adds to, in the menu bar's order.
public enum KeyCommandMenu: Hashable, Sendable, CaseIterable {
    case edit, view, playback, go
}

/// Where a command can be available. Commands for two screens that never
/// show at once may share a key; `window` commands are available everywhere.
public enum KeyCommandScreen: Hashable, Sendable, CaseIterable {
    case live, guide, search, moviePlayer, multiView, window
}

/// Every command in the Mac and iPad menus (keyboard-commands capability):
/// its menu, generic title, key and modifiers, and the screens that can
/// enable it. Moving through lists with the arrows, Return and Escape stays
/// in the screens and is not listed here.
public enum KeyCommand: Hashable, Sendable {
    case find
    case zoomIn, zoomOut
    case playPause, skipBack, skipForward
    case mute, volumeUp, volumeDown
    case addToMultiView
    /// Tile 1 to 4.
    case selectTile(Int)
    case removeTile
    case goLive, goGuide, goMovies, goSeries, goSearch, goSettings

    /// Every command, in menu order.
    public static let all: [KeyCommand] =
        [.find, .zoomIn, .zoomOut, .playPause, .skipBack, .skipForward, .mute, .volumeUp, .volumeDown, .addToMultiView]
        + (1...4).map(KeyCommand.selectTile) + [.removeTile, .goLive, .goGuide, .goMovies, .goSeries, .goSearch, .goSettings]

    public var menu: KeyCommandMenu {
        switch self {
        case .find: .edit
        case .zoomIn, .zoomOut: .view
        case .playPause, .skipBack, .skipForward, .mute, .volumeUp, .volumeDown, .addToMultiView, .selectTile, .removeTile: .playback
        case .goLive, .goGuide, .goMovies, .goSeries, .goSearch, .goSettings: .go
        }
    }

    public var combination: KeyCombination {
        switch self {
        case .find: KeyCombination(.character("f"), .command)
        case .zoomIn: KeyCombination(.character("+"), .command)
        case .zoomOut: KeyCombination(.character("-"), .command)
        case .playPause: KeyCombination(.space)
        case .skipBack: KeyCombination(.leftArrow)
        case .skipForward: KeyCombination(.rightArrow)
        case .mute: KeyCombination(.character("m"))
        case .volumeUp: KeyCombination(.upArrow, .command)
        case .volumeDown: KeyCombination(.downArrow, .command)
        case .addToMultiView: KeyCombination(.character("m"), [.command, .shift])
        case .selectTile(let number): KeyCombination(.character(Character(String(number))), [.command, .option])
        case .removeTile: KeyCombination(.delete, .command)
        case .goLive: KeyCombination(.character("1"), .command)
        case .goGuide: KeyCombination(.character("2"), .command)
        case .goMovies: KeyCombination(.character("3"), .command)
        case .goSeries: KeyCombination(.character("4"), .command)
        case .goSearch: KeyCombination(.character("5"), .command)
        case .goSettings: KeyCombination(.character(","), .command)
        }
    }

    /// The title with nothing in front that can use the item.
    public var title: String { title(.autoupdatingCurrent) }

    public func title(_ locale: Locale) -> String {
        let words = Words(locale)
        return switch self {
        case .find: words("Find")
        case .zoomIn: words("Zoom In")
        case .zoomOut: words("Zoom Out")
        case .playPause: words("Play")
        case .skipBack:
            String(localized: LocalizedStringResource("command.back", defaultValue: "Back", locale: locale, bundle: Words.bundle))
        case .skipForward: words("Forward")
        case .mute: words("Mute")
        case .volumeUp: words("Volume Up")
        case .volumeDown: words("Volume Down")
        case .addToMultiView: words("Add to Multi-view")
        case .selectTile(let number): words("Select Tile \(number)")
        case .removeTile: words("Remove Tile")
        case .goLive: words("Live")
        case .goGuide: words("Guide")
        case .goMovies: words("Movies")
        case .goSeries: words("Series")
        case .goSearch: words("Search")
        case .goSettings: words("Sources & Settings")
        }
    }

    /// The screens that can enable this command.
    public var screens: Set<KeyCommandScreen> {
        switch self {
        case .find: [.live, .guide, .search]
        case .zoomIn, .zoomOut: [.guide]
        case .playPause, .skipBack, .skipForward: [.live, .moviePlayer]
        case .mute, .volumeUp, .volumeDown, .addToMultiView: [.live]
        case .selectTile, .removeTile: [.multiView]
        case .goLive, .goGuide, .goMovies, .goSeries, .goSearch, .goSettings: [.window]
        }
    }

    /// Only in the Mac's menus; the iPad uses its hardware volume.
    public var isMacOnly: Bool {
        switch self {
        case .mute, .volumeUp, .volumeDown: true
        default: false
        }
    }

    /// Listed on iPad without its key, because iPadOS's own menus hold it:
    /// Edit's Find on Command-F and the app menu's Settings on Command-Comma.
    /// The iPad keeps Command-F as a key command on the screen.
    public var isHeldByIPadOS: Bool {
        self == .find || self == .goSettings
    }

    /// Dimmed while a text field has the keyboard: every key without
    /// Command, Option or Control, and the Command keys a text field uses
    /// for moving and deleting (keyboard-commands/typing-is-never-taken-by-a-shortcut).
    public var isDimmedWhileTyping: Bool {
        let modifiers = combination.modifiers
        if modifiers.isDisjoint(with: [.command, .option, .control]) { return true }
        return self == .volumeUp || self == .volumeDown || self == .removeTile
    }

    /// "Pause" while it plays, "Play" while paused.
    public static func pauseTitle(paused: Bool, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return paused ? words("Play") : words("Pause")
    }

    /// "Back 15 Seconds", "Forward 30 Seconds".
    public static func skipTitle(forward: Bool, seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return forward ? words("Forward \(seconds) Seconds") : words("Back \(seconds) Seconds")
    }

    /// Find's title on each screen that has it.
    public static func findTitle(on screen: KeyCommandScreen, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return switch screen {
        case .live: words("Find Channel")
        case .guide: words("Filter Channels")
        case .search: words("Search")
        case .moviePlayer, .multiView, .window: KeyCommand.find.title(locale)
        }
    }
}
