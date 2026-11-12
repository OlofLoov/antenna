import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The track lists, the info panel and the picker in the player model.
@MainActor
@Suite struct PlayerTracksTests {
    let engine = PlayerTestEngine()
    let player: PlayerModel

    static let tracks = TrackList(
        audio: [
            MediaTrack(id: "audio-0", kind: .audio, languageCode: "en", name: nil, isDefault: true),
            MediaTrack(id: "audio-1", kind: .audio, languageCode: "sv", name: nil, isDefault: false),
        ],
        subtitles: [MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "en", name: nil, isDefault: false)],
        selectedAudio: "audio-0", selectedSubtitle: nil)

    init() {
        player = PlayerModel(.init(engine: engine, network: .online, log: PlayerLog { _ in }))
    }

    private func tune(_ id: String = "news", file: String = "news.ts") {
        let channel = Channel(id: id, name: id, streamURL: URL(fileURLWithPath: "/\(file)"))
        player.tuned(PlayerSubject(channel: channel, source: "Home", number: 1))
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles a pick goes to the engine and the list follows it")
    func pick() async {
        tune()
        let task = Task { await player.observeDetails() }
        engine.send(Self.tracks)
        #expect(await eventually { player.audioRows.count == 2 })
        player.openPicker()
        #expect(player.pickerOpen)

        player.selectAudio("audio-1")
        player.selectSubtitle("subtitle-0")

        #expect(await eventually { player.audioRows[1].isSelected && player.subtitleRows[1].isSelected })
        #expect(engine.audioPicks == ["audio-1"])
        #expect(engine.subtitlePicks == ["subtitle-0"])
        #expect(player.pickerOpen, "the list stays open")

        player.selectSubtitle(TrackMenu.offID)
        #expect(await eventually { player.subtitleRows.first?.isSelected == true })
        task.cancel()
    }

    @Test("player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step the switch turns subtitles on and off")
    func switchSubtitles() async {
        tune()
        let task = Task { await player.observeDetails() }
        engine.send(Self.tracks)
        #expect(await eventually { player.canSwitchSubtitles })
        #expect(!player.subtitlesOn)

        player.switchSubtitles(languages: ["sv", "en"])
        #expect(await eventually { player.subtitlesOn })
        player.switchSubtitles(languages: ["sv", "en"])
        #expect(await eventually { !player.subtitlesOn })
        #expect(engine.subtitlePicks == ["subtitle-0", nil])

        var none = Self.tracks
        none.subtitles = []
        engine.send(none)
        #expect(await eventually { !player.canSwitchSubtitles })
        player.switchSubtitles()
        #expect(engine.subtitlePicks.count == 2, "with no subtitles the switch does nothing")
        task.cancel()
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles tracks changing while the list is open update it")
    func tracksChange() async {
        tune()
        player.tracksChanged(Self.tracks)
        player.openPicker()
        var more = Self.tracks
        more.audio.append(MediaTrack(id: "audio-2", kind: .audio, languageCode: "de", name: nil, isDefault: false))
        player.tracksChanged(more)
        #expect(player.audioRows.map(\.name) == ["English", "Swedish", "German"])
        #expect(player.pickerOpen)
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles one sound and no subtitles opens nothing")
    func grayedOut() {
        tune()
        player.tracksChanged(TrackList(audio: [Self.tracks.audio[0]], subtitles: [], selectedAudio: "audio-0", selectedSubtitle: nil))
        #expect(!player.hasTrackChoices)
        player.openPicker()
        #expect(!player.pickerOpen)
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles a new channel starts fresh")
    func newChannel() {
        tune()
        player.tracksChanged(Self.tracks)
        player.openPicker()
        player.openPanel(.audio)

        tune("sport", file: "sport.ts")

        #expect(player.tracks == .empty)
        #expect(!player.pickerOpen)
        #expect(player.panel == nil)
    }

    @Test("player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong the panel and the list close before the error")
    func failureClosesOverlays() {
        tune()
        player.tracksChanged(Self.tracks)
        player.openPicker()
        player.openPanel(.subtitles)

        player.stateChanged(.failed(.notFound))

        #expect(!player.pickerOpen)
        #expect(player.panel == nil)
        player.openPanel()
        #expect(player.panel == nil, "no panel over the error")
    }

    @Test(
        "player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv no stream line before a frame"
    )
    func streamLine() async {
        tune(file: "news.ts")
        #expect(player.streamLine == "Stream details not available yet")
        await player.presentationChanged(
            PresentationInfo(
                video: .init(width: 1920, height: 1080, frameRate: 50, dynamicRange: .sdr, codec: "h264"),
                audio: .init(codec: "aac", channels: 6, isDecodable: true)))
        #expect(player.streamLine == "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player")
    }
}
