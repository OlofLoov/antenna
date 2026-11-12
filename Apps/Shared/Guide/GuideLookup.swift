import AntennaCore
import Foundation

/// The one place the app asks for a channel's guide key, so a hand-picked
/// entry or a match by name applies on every screen, in reminders and in
/// Search (guide-data/programmes-land-on-the-right-channels). Without a
/// guide store, as in previews and some UI test launches, a channel's key is
/// its own guide id.
@MainActor
enum GuideLookup {
    /// The store the app runs on; set when it is made.
    static weak var store: AppGuideStore?

    static func key(for channel: Channel) -> GuideKey? {
        store?.key(for: channel) ?? GuideKey(channel: channel)
    }
}
