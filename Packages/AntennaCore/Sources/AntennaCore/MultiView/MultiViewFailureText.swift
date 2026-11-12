import Foundation

/// What a failed tile says (multi-view/a-tile-that-fails-says-why). A
/// provider refusing another stream and a device out of decoders get
/// their own words; every other reason reads as the player's usual
/// message. Built from the reason and the source's name only.
public enum MultiViewFailureText {
    /// `sharesSource` is true while another tile plays a channel of the
    /// same source. `source` is the source's display name.
    public static func message(
        _ failure: PlaybackFailure, sharesSource: Bool, source: String, device: FailureMessage.Device
    ) -> FailureMessage {
        let refusal = failure == .serverBusy || failure == .serverError || failure == .notAllowed
        switch failure {
        case .noDecoderFree:
            let name = device == .appleTV ? "This Apple TV" : "This Mac"
            return FailureMessage(
                title: "\(name) can't play another stream", explanation: "Remove a tile or pick a lower-resolution channel.")
        case _ where refusal && sharesSource:
            var explanation = "Many providers allow one or two streams per account at a time."
            if failure == .notAllowed {
                explanation +=
                    device == .appleTV
                    ? " If the login changed, sign in again on this Apple TV."
                    : " If the login changed, check it in Settings."
            }
            return FailureMessage(title: "Your provider refused another stream", explanation: explanation)
        default:
            return FailureMessage(failure, source: source, device: device)
        }
    }
}

/// The other words multi-view shows.
public enum MultiViewText {
    /// The overlay button over full-screen live.
    public static let addToMultiView = "Add to multi-view"
    /// The overlay button while picking a channel for a tile.
    public static let addAsNewTile = "Add as new tile"
    /// The Mac's channel menu item, and its grayed form at the cap.
    public static let addToMultiViewMenu = "Add to Multi-view"
    public static let full = "Multi-view is full"
    public static let exit = "Exit multi-view"
    public static let title = "Multi-view"
    /// Under a failed tile on Apple TV.
    public static let failedHint = "Hold select for options"

    /// The overlay's eyebrow while picking, "Changing tile 2 of 3".
    public static func changing(tile: Int, of count: Int) -> String {
        "Changing tile \(tile) of \(count)"
    }

    /// The overlay's Watch button while picking, "Show in tile 2".
    public static func showIn(tile: Int) -> String {
        "Show in tile \(tile)"
    }

    /// The badge on a channel row already in a tile, "TILE 1".
    public static func tileBadge(_ tile: Int) -> String {
        "TILE \(tile)"
    }

    /// The badge over a full-screen tile, "Multi-view · tile 2 of 4".
    public static func enlargedBadge(tile: Int, of count: Int) -> String {
        "Multi-view · tile \(tile) of \(count)"
    }

    /// The Mac toolbar's name for the selected tile, "Tile 2 of 4".
    public static func selected(tile: Int, of count: Int) -> String {
        "Tile \(tile) of \(count)"
    }

    /// The actions menu's eyebrow, "Tile 2 · Sport One".
    public static func actionsTitle(tile: Int, name: String) -> String {
        "Tile \(tile) · \(name)"
    }

    /// A tile's spoken label, "104, Sport One, sound on".
    public static func spokenLabel(number: Int?, name: String, audible: Bool) -> String {
        ([number.map(String.init), name].compactMap(\.self) + [audible ? "sound on" : "muted"]).joined(separator: ", ")
    }

    /// The Apple TV hint after entering, as key and what it does.
    public static let hints: [(key: String, action: String)] = [
        ("Select", "change channel"), ("Hold select", "options"), ("Play/Pause", "full screen"), ("Menu", "leave multi-view"),
    ]

    public static let enlargedHint = "Play/Pause to return"

    /// The tile actions, in menu order.
    public static let fullScreen = "Full screen"
    public static let changeChannel = "Change channel"
    public static let remove = "Remove from multi-view"
}
