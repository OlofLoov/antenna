#if os(tvOS)
    /// Where focus is in the Apple TV movie player.
    enum TitlePanelFocus: Hashable {
        case picture
        /// The Next episode button, or Play now on the Up next card.
        case nextEpisode
        /// The Audio and Subtitles button on the bar.
        case tracks
        case segment(PanelTab)
        /// A track row by its id, or `TrackMenu.offID`.
        case track(String)
        /// The Subtitles On/Off switch after the tabs.
        case subtitles
    }

    /// Where up and down go in the Apple TV movie player
    /// (player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv,
    /// up-next/up-next-on-the-siri-remote): from the picture to the Next
    /// episode button while it shows, then to the bar's Audio and Subtitles
    /// button, and back up the same way. Nil leaves focus where it is.
    enum TitleRemoteMoves {
        /// Down from `focus`. `nextEpisode` is true while the Next episode
        /// button shows; `hasChoices` is false when the title has one sound
        /// and no subtitles, so the bar's button is grayed out.
        static func down(from focus: TitlePanelFocus?, nextEpisode: Bool, hasChoices: Bool) -> TitlePanelFocus? {
            switch focus {
            case .picture where nextEpisode: .nextEpisode
            case .picture, .nextEpisode: hasChoices ? .tracks : nil
            default: nil
            }
        }

        /// Up from `focus`.
        static func up(from focus: TitlePanelFocus?, nextEpisode: Bool) -> TitlePanelFocus? {
            switch focus {
            case .tracks: nextEpisode ? .nextEpisode : .picture
            case .nextEpisode: .picture
            default: nil
            }
        }
    }
#endif
