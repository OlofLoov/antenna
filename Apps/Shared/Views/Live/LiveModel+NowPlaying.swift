import AntennaCore
import Foundation

extension LiveModel {
    /// The names the player's messages use for `channel`.
    func subject(for channel: Channel) -> PlayerSubject {
        PlayerSubject(
            channel: channel, source: sources.first { $0.id == channel.sourceID }?.name ?? PlayerModel.unnamedSource,
            number: RowKey(channel).flatMap(catalogue.number(for:)))
    }

    /// What the lock screen shows for the playing channel at `date`, nil
    /// with nothing playing
    /// (player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen).
    func nowPlayingInfo(at date: Date) -> NowPlayingInfo? {
        guard let channel = playing else { return nil }
        let text = nowText(for: channel, at: date)
        return NowPlayingInfo(
            title: text.times == nil ? channel.name : text.title, channelLine: subject(for: channel).line,
            isPlaying: !isPaused && player.failure == nil, artwork: NowPlayingArtwork.cached(channel.logoURL))
    }

    /// Turns on play and pause from the lock screen, then keeps the lock
    /// screen within `nowPlayingInterval` of the programme, the channel and
    /// play or pause, until the calling task ends.
    func publishNowPlaying() async {
        let sink = dependencies.nowPlaying ?? .system
        sink.listen(
            { [weak self] in
                guard let self, isPaused else { return }
                playPause()
            },
            { [weak self] in
                guard let self, !isPaused else { return }
                playPause()
            })
        var shown: NowPlayingInfo?
        var first = true
        while !Task.isCancelled {
            let info = nowPlayingInfo(at: .now)
            if first || info != shown {
                sink.publish(info)
                shown = info
                first = false
            }
            try? await Task.sleep(for: dependencies.nowPlayingInterval)
        }
    }
}
