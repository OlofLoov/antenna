import AntennaCore
import Foundation

/// Changing channel from the picture on iPhone, iPad and Mac.
extension LiveModel {
    /// Plays the channel `steps` places from the playing one in the list on
    /// screen, wrapping round, or in All channels when the list does not hold
    /// it (live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel).
    /// Positive steps go down the list, as a swipe up on Apple TV does.
    func zap(by steps: Int) {
        guard multiView == nil, let playing, let key = RowKey(playing) else { return }
        let shown = rows
        let list = shown.contains(key) ? shown : catalogue.rows(in: .all)
        guard let next = catalogue.neighbor(of: key, in: list, by: steps) else { return }
        pick(next)
    }

    /// The channel Previous channel plays: the one before the last change
    /// of channel, else the newest other channel in Recents
    /// (live-tv-on-iphone-ipad-mac/go-back-to-the-previous-channel).
    var previousChannel: Channel? {
        let playingKey = playing.flatMap(RowKey.init)
        if let key = lastChannel.flatMap(RowKey.init), key != playingKey, let channel = catalogue.channel(for: key) {
            return channel
        }
        return catalogue.mostRecent(otherThan: playingKey)
    }

    /// Plays `previousChannel`; pressing again flips back.
    func playPreviousChannel() {
        guard multiView == nil, let previous = previousChannel else { return }
        pick(previous)
    }
}
