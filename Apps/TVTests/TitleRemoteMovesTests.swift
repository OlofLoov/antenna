import Testing

@testable import AntennaTV

/// Where up and down go in the Apple TV movie player.
struct TitleRemoteMovesTests {
    @Test("player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv down reaches the bar's button and up goes back")
    func downAndUp() {
        #expect(TitleRemoteMoves.down(from: .picture, nextEpisode: false, hasChoices: true) == .tracks)
        #expect(TitleRemoteMoves.up(from: .tracks, nextEpisode: false) == .picture)
        #expect(TitleRemoteMoves.down(from: .tracks, nextEpisode: false, hasChoices: true) == nil)
        #expect(TitleRemoteMoves.up(from: .picture, nextEpisode: false) == nil)
    }

    @Test("player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv a grayed-out button never takes focus")
    func noChoices() {
        #expect(TitleRemoteMoves.down(from: .picture, nextEpisode: false, hasChoices: false) == nil)
        #expect(TitleRemoteMoves.down(from: .nextEpisode, nextEpisode: true, hasChoices: false) == nil)
    }

    @Test("up-next/up-next-on-the-siri-remote the Next episode button comes before the bar's button")
    func nextEpisodeFirst() {
        #expect(TitleRemoteMoves.down(from: .picture, nextEpisode: true, hasChoices: true) == .nextEpisode)
        #expect(TitleRemoteMoves.down(from: .nextEpisode, nextEpisode: true, hasChoices: true) == .tracks)
        #expect(TitleRemoteMoves.up(from: .tracks, nextEpisode: true) == .nextEpisode)
        #expect(TitleRemoteMoves.up(from: .nextEpisode, nextEpisode: true) == .picture)
    }

    @Test("player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv the panel keeps its own moves")
    func panel() {
        #expect(TitleRemoteMoves.down(from: .segment(.audio), nextEpisode: false, hasChoices: true) == nil)
        #expect(TitleRemoteMoves.up(from: .track("off"), nextEpisode: false) == nil)
    }
}
