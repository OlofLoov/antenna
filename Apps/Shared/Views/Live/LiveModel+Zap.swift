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

    /// The swipes and double-taps VoiceOver offers on the picture: Channel
    /// up and Channel down, then Back 15 seconds and Forward 15 seconds
    /// while the channel can rewind
    /// (live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel,
    /// live-tv-on-iphone-ipad-mac/double-tap-to-skip).
    var pictureActions: [NamedAction] {
        var actions = [
            NamedAction(name: "Channel up") { [weak self] in self?.zap(by: 1) },
            NamedAction(name: "Channel down") { [weak self] in self?.zap(by: -1) },
        ]
        let timeshift = player.timeshift
        if timeshift.canRewind {
            actions.append(NamedAction(name: "Back 15 seconds") { timeshift.doubleTapSkip(forward: false) })
            actions.append(NamedAction(name: "Forward 15 seconds") { timeshift.doubleTapSkip(forward: true) })
        }
        return actions
    }
}
