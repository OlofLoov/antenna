import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The audio and subtitle lists of a playing movie or episode.
@MainActor
@Suite struct TitleTracksTests {
    let engine = PlayerTestEngine()

    static let tracks = TrackList(
        audio: [
            MediaTrack(id: "audio-0", kind: .audio, languageCode: "en", name: nil, isDefault: true),
            MediaTrack(id: "audio-1", kind: .audio, languageCode: "es", name: nil, isDefault: false),
        ],
        subtitles: [MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "en", name: nil, isDefault: false)],
        selectedAudio: "audio-0", selectedSubtitle: nil)

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode a pick reaches the engine")
    func pick() async {
        let tracks = TitleTracks(engine: engine, address: URL(fileURLWithPath: "/film.mp4"))
        let task = Task { await tracks.follow() }
        defer { task.cancel() }
        engine.send(Self.tracks)
        #expect(await eventually { tracks.audioRows.count == 2 })
        #expect(tracks.subtitleRows.first?.id == TrackMenu.offID, "Off comes first")
        tracks.openPicker()
        #expect(tracks.pickerOpen)

        tracks.selectAudio("audio-1")
        tracks.selectSubtitle("subtitle-0")

        #expect(await eventually { tracks.audioRows[1].isSelected && tracks.subtitleRows[1].isSelected })
        #expect(engine.audioPicks == ["audio-1"])
        #expect(engine.subtitlePicks == ["subtitle-0"])
        #expect(tracks.pickerOpen, "the list stays open")
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode the switch turns subtitles on and off")
    func switchSubtitles() async {
        let tracks = TitleTracks(engine: engine, address: URL(fileURLWithPath: "/film.mp4"))
        let task = Task { await tracks.follow() }
        defer { task.cancel() }
        engine.send(Self.tracks)
        #expect(await eventually { tracks.canSwitchSubtitles })

        tracks.switchSubtitles(languages: ["en"])
        #expect(await eventually { tracks.subtitlesOn })
        tracks.switchSubtitles(languages: ["en"])
        #expect(await eventually { !tracks.subtitlesOn })
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode one sound, nothing to pick")
    func noChoices() async {
        let tracks = TitleTracks(engine: engine, address: URL(fileURLWithPath: "/film.mp4"))
        let task = Task { await tracks.follow() }
        defer { task.cancel() }
        var single = Self.tracks
        single.audio = [single.audio[0]]
        single.subtitles = []
        engine.send(single)
        #expect(await eventually { tracks.audioRows.count == 1 })
        #expect(!tracks.hasTrackChoices)
        #expect(!tracks.canSwitchSubtitles)
        tracks.openPicker()
        #expect(!tracks.pickerOpen, "nothing opens with nothing to choose")
    }
}
