import Foundation

/// What a failed tile says (multi-view/a-tile-that-fails-says-why). A
/// provider refusing another stream and a device out of decoders get
/// their own words; every other reason reads as the player's usual
/// message. Built from the reason and the source's name only.
public enum MultiViewFailureText {
    /// `sharesSource` is true while another tile plays a channel of the
    /// same source. `source` is the source's display name.
    public static func message(
        _ failure: PlaybackFailure, sharesSource: Bool, source: String, device: FailureMessage.Device,
        locale: Locale = .autoupdatingCurrent
    ) -> FailureMessage {
        let words = Words(locale)
        let refusal = failure == .serverBusy || failure == .serverError || failure == .notAllowed
        switch failure {
        case .noDecoderFree:
            return FailureMessage(
                title: device == .appleTV ? words("This Apple TV can't play another stream") : words("This Mac can't play another stream"),
                explanation: words("Remove a tile or pick a lower-resolution channel."))
        case _ where refusal && sharesSource:
            let explanation =
                switch (failure, device) {
                case (.notAllowed, .appleTV):
                    words(
                        """
                        Many providers allow one or two streams per account at a time. If the login \
                        changed, sign in again on this Apple TV.
                        """
                    )
                case (.notAllowed, _):
                    words("Many providers allow one or two streams per account at a time. If the login changed, check it in Settings.")
                default: words("Many providers allow one or two streams per account at a time.")
                }
            return FailureMessage(title: words("Your provider refused another stream"), explanation: explanation)
        default:
            return FailureMessage(failure, source: source, device: device, locale: locale)
        }
    }
}

/// The other words multi-view shows.
public enum MultiViewText {
    /// The overlay button over full-screen live.
    public static func addToMultiView(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Add to multi-view")
    }
    /// The overlay button while picking a channel for a tile.
    public static func addAsNewTile(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Add as new tile")
    }
    /// The Mac's channel menu item, and its grayed form at the cap.
    public static func addToMultiViewMenu(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Add to Multi-view")
    }
    public static func full(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Multi-view is full")
    }
    public static func exit(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Exit multi-view")
    }
    public static func title(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Multi-view")
    }
    /// Under a failed tile on Apple TV.
    public static func failedHint(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Hold select for options")
    }

    /// The overlay's eyebrow while picking, "Changing tile 2 of 3".
    public static func changing(tile: Int, of count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Changing tile \(tile) of \(count)")
    }

    /// The overlay's Watch button while picking, "Show in tile 2".
    public static func showIn(tile: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Show in tile \(tile)")
    }

    /// The badge on a channel row already in a tile, "TILE 1".
    public static func tileBadge(_ tile: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("TILE \(tile)")
    }

    /// The badge over a full-screen tile, "Multi-view · tile 2 of 4".
    public static func enlargedBadge(tile: Int, of count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Multi-view · tile \(tile) of \(count)")
    }

    /// The Mac toolbar's name for the selected tile, "Tile 2 of 4".
    public static func selected(tile: Int, of count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Tile \(tile) of \(count)")
    }

    /// The actions menu's eyebrow, "Tile 2 · Sport One".
    public static func actionsTitle(tile: Int, name: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Tile \(tile) · \(words.source(name))")
    }

    /// A tile's spoken label, "104, Sport One, sound on".
    public static func spokenLabel(number: ChannelNumber?, name: String, audible: Bool, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return ([number.map(\.description), name].compactMap(\.self) + [audible ? words("sound on") : words("muted")]).joined(
            separator: ", ")
    }

    /// The Apple TV hint after entering, as key and what it does.
    public static func hints(_ locale: Locale = .autoupdatingCurrent) -> [(key: String, action: String)] {
        let words = Words(locale)
        return [
            (words("Select"), words("change channel")), (words("Hold select"), words("options")),
            (words("Play/Pause"), words("full screen")), (words("Menu"), words("leave multi-view")),
        ]
    }

    public static func enlargedHint(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Play/Pause to return")
    }

    /// The tile actions, in menu order.
    public static func fullScreen(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Full screen")
    }
    public static func changeChannel(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Change channel")
    }
    public static func remove(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Remove from multi-view")
    }
}
