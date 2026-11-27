import Foundation

/// Moves the live channel playing between MPEG-TS on the device and HLS on
/// Apple's player as AirPlay comes and goes
/// (playback-engine/a-channel-goes-to-airplay-as-hls). It decides only; the
/// player carries out each `Step`. MPEG-TS keeps playing on the device until
/// a device is picked.
public struct AirPlayHandoff: Sendable, Equatable {
    public enum Event: Sendable, Equatable {
        /// The sound route changed; `airPlay` is true while it is an AirPlay
        /// device. iPhone and iPad report it; a Mac has no such route.
        case route(airPlay: Bool)
        /// The AirPlay list opened. `preparesPlayer` is true where the list
        /// routes one player rather than the app's sound, as on a Mac.
        case pickerOpened(preparesPlayer: Bool)
        /// The AirPlay list closed.
        case pickerClosed
        /// Apple's player started or stopped sending the picture to AirPlay.
        case externalPlayback(Bool)
        /// The wait after a switch to HLS or a prepared HLS link ran out.
        case waitEnded
        /// The HLS link did not start, and MPEG-TS plays in its place.
        case hlsFailed
    }

    public enum Step: Sendable, Equatable {
        /// Load the channel again as HLS on Apple's player.
        case playHLS
        /// Load the channel again as MPEG-TS on the device.
        case playTransportStream
        /// Open the HLS link on Apple's player, paused, silent and not drawn,
        /// for the AirPlay list to route while MPEG-TS plays on.
        case prepareHLS
        /// Close the prepared HLS link.
        case dropPreparedHLS
        /// Wait `waitFor`, then send `waitEnded`.
        case wait
        /// Say "AirPlay not available for this stream".
        case sayUnavailable
    }

    /// How long HLS may play before the picture reaches AirPlay, and how
    /// long a prepared link waits after the list closes. Past it an AirPlay
    /// route is taken for a speaker with no screen, and MPEG-TS comes back.
    public static let waitFor = Duration.seconds(8)

    /// True while the channel plays, or should play, as HLS.
    public private(set) var wantsHLS = false
    /// True while an HLS link waits, prepared, for a device to be picked.
    public private(set) var prepared = false
    private var airPlayRoute = false
    private var external = false
    /// The current AirPlay route showed no picture, so it is not tried again until the route changes.
    private var soundOnly = false
    private var pickerOpen = false

    public init() {}

    /// The steps for `event`. `canSendHLS` says whether the channel playing
    /// has an HLS link it may send.
    public mutating func handle(_ event: Event, canSendHLS: Bool) -> [Step] {
        switch event {
        case .route(let airPlay):
            guard airPlay != airPlayRoute else { return [] }
            airPlayRoute = airPlay
            soundOnly = false
            guard airPlay else { return leaveHLS() }
            guard canSendHLS, !wantsHLS else { return [] }
            wantsHLS = true
            prepared = false
            return [.playHLS, .wait]
        case .pickerOpened(let preparesPlayer):
            pickerOpen = true
            guard preparesPlayer, canSendHLS, !wantsHLS, !prepared else { return [] }
            prepared = true
            return [.prepareHLS]
        case .pickerClosed:
            pickerOpen = false
            return (prepared || wantsHLS) && !external ? [.wait] : []
        case .externalPlayback(true):
            external = true
            guard prepared, !wantsHLS else { return [] }
            prepared = false
            wantsHLS = true
            return [.playHLS]
        case .externalPlayback(false):
            guard external else { return [] }
            return leaveHLS()
        case .waitEnded:
            guard !pickerOpen, !external else { return [] }
            if prepared {
                prepared = false
                return [.dropPreparedHLS]
            }
            guard wantsHLS else { return [] }
            if airPlayRoute { soundOnly = true }
            return leaveHLS()
        case .hlsFailed:
            wantsHLS = false
            prepared = false
            external = false
            return [.sayUnavailable]
        }
    }

    /// Another channel is tuned; `wantsHLS` then says how it plays. A
    /// channel with no HLS link plays as MPEG-TS, and one with a link on an
    /// AirPlay route plays as HLS unless the route showed no picture.
    public mutating func tuned(canSendHLS: Bool) -> [Step] {
        let dropped: [Step] = prepared ? [.dropPreparedHLS] : []
        prepared = false
        guard canSendHLS else {
            wantsHLS = false
            return dropped
        }
        guard !wantsHLS, airPlayRoute, !soundOnly else { return dropped }
        wantsHLS = true
        return dropped + [.wait]
    }

    private mutating func leaveHLS() -> [Step] {
        external = false
        var steps: [Step] = []
        if prepared {
            prepared = false
            steps.append(.dropPreparedHLS)
        }
        guard wantsHLS else { return steps }
        wantsHLS = false
        return steps + [.playTransportStream]
    }
}
