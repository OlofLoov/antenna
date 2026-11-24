#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation
    import os

    /// The tabs of the Apple TV shell, in bar order.
    enum ShellTab: Hashable, CaseIterable, Sendable {
        case live, guide, movies, series, search, settings

        /// Movies, Series and Search: the video pauses behind them, then stops.
        var isContent: Bool { self == .movies || self == .series || self == .search }

        /// Live and the Guide show the picture and end a hold.
        var showsPicture: Bool { self == .live || self == .guide }
    }

    /// Where focus goes after the shell handles an input.
    enum ShellFocus: Hashable {
        /// Full-screen Live with a channel tuned.
        case picture
        /// Try again on the error in place of the full-screen picture.
        case retry
        /// Sign in on the error, for a source whose login is missing or refused.
        case signIn
        /// Channels on the error, which opens the overlay on the current group.
        case channels
        /// A tab or track in the info panel over the picture.
        case panel(PanelFocus)
        /// The loading screen's holder or the empty screen's Open Settings.
        case liveScreen
        case content
        /// A group, channel or the Search entry in the channel overlay.
        case overlay(OverlayFocus)
    }

    /// One source as the loading and empty screens list it.
    struct ShellSource: Identifiable, Equatable, Sendable {
        enum State: Equatable, Sendable {
            case loading
            case loaded(channels: Int)
            case offline
            case failed
            case waitingForLogin

            /// True once the source finished and added nothing: loaded empty,
            /// offline, failed or waiting for its login.
            var addedNothing: Bool { self != .loading && !isLoadedWithChannels }

            var isLoadedWithChannels: Bool {
                if case .loaded(let count) = self { return count > 0 }
                return false
            }
        }

        var id: UUID
        var name: String
        var state: State
        /// A file source waiting for its playlist rather than its login
        /// (tvos-shell/a-file-source-waiting-for-icloud).
        var waitsForICloud = false
    }

    /// What Live shows when nothing has been tuned yet, or the picture.
    enum LiveScreen: Equatable {
        case playing, loading, empty
    }
#endif
