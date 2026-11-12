import Foundation

/// The app's preferences (sources-and-settings/choose-how-the-app-behaves),
/// with the defaults a new user starts on.
public struct AppPreferences: Equatable, Sendable {
    public enum LaunchScreen: String, CaseIterable, Sendable {
        case live, guide, movies

        public var title: String {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            }
        }
    }

    public enum RefreshInterval: Int, CaseIterable, Sendable {
        case six = 6
        case twelve = 12
        case day = 24
        /// Only manually.
        case manual = 0

        public var title: String {
            switch self {
            case .six: "Every 6 hours"
            case .twelve: "Every 12 hours"
            case .day: "Every 24 hours"
            case .manual: "Only manually"
            }
        }

        /// Nil for manual refresh only.
        public var duration: Duration? {
            self == .manual ? nil : .seconds(rawValue * 3600)
        }

        /// The listed order: 6, 12, 24 hours, then manual.
        public static let ordered: [RefreshInterval] = [.six, .twelve, .day, .manual]
    }

    public enum Swipe: String, CaseIterable, Sendable {
        case changesChannel, showsZapBar

        public var title: String {
            switch self {
            case .changesChannel: "Changes channel"
            case .showsZapBar: "Shows the zap bar"
            }
        }
    }

    public static let guideHours = [2, 3, 4]

    public var openOnLaunch: LaunchScreen
    public var guideHours: Int
    public var refresh: RefreshInterval
    public var swipe: Swipe

    public init(
        openOnLaunch: LaunchScreen = .live, guideHours: Int = 2, refresh: RefreshInterval = .twelve, swipe: Swipe = .changesChannel
    ) {
        self.openOnLaunch = openOnLaunch
        self.guideHours = Self.guideHours.contains(guideHours) ? guideHours : 2
        self.refresh = refresh
        self.swipe = swipe
    }

    /// "2 hours".
    public static func hoursTitle(_ hours: Int) -> String { "\(hours) hours" }

    /// The screen to open, Live when Movies is stored and not offered here.
    public func launchScreen(offersMovies: Bool) -> LaunchScreen {
        openOnLaunch == .movies && !offersMovies ? .live : openOnLaunch
    }

    /// Which of several stored copies counts: the newest, and at equal
    /// times the one with the smaller id.
    public static func winner<ID: Comparable>(_ copies: [(id: ID, updated: Date)]) -> ID? {
        copies.min { lhs, rhs in
            lhs.updated != rhs.updated ? lhs.updated > rhs.updated : lhs.id < rhs.id
        }?.id
    }
}
