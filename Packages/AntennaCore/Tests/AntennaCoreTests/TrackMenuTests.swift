import AntennaCore
import Foundation
import Testing

@Suite struct TrackMenuTests {
    static let tracks = TrackList(
        audio: [
            MediaTrack(id: "audio-0", kind: .audio, languageCode: "en", name: nil, isDefault: true),
            MediaTrack(id: "audio-1", kind: .audio, languageCode: "en", name: "Commentary", isDefault: false),
            MediaTrack(id: "audio-2", kind: .audio, languageCode: nil, name: nil, isDefault: false),
        ],
        subtitles: [
            MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "en", name: nil, isDefault: false),
            MediaTrack(id: "subtitle-1", kind: .subtitle, languageCode: nil, name: "Forced", isDefault: false),
        ],
        selectedAudio: "audio-1", selectedSubtitle: nil)

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles audio rows name each track and tick the playing one")
    func audio() {
        let rows = TrackMenu.audio(Self.tracks, presentation: StreamLineTests.broadcast)
        #expect(rows.map(\.name) == ["English", "English (Commentary)", "Track 3"])
        #expect(rows.map(\.isSelected) == [false, true, false])
        #expect(rows.map(\.detail) == [nil, "AAC 5.1", nil])
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles subtitles start with Off, ticked while off")
    func subtitles() {
        let rows = TrackMenu.subtitles(Self.tracks)
        #expect(rows.map(\.name) == ["Off", "English", "Forced"])
        #expect(rows.map(\.isSelected) == [true, false, false])
        var on = Self.tracks
        on.selectedSubtitle = "subtitle-0"
        #expect(TrackMenu.subtitles(on).map(\.isSelected) == [false, true, false])
    }

    @Test("player-controls-and-playback-errors/choose-audio-and-subtitles one sound and no subtitles leaves nothing to choose")
    func nothingToChoose() {
        let single = TrackList(audio: [Self.tracks.audio[0]], subtitles: [], selectedAudio: "audio-0", selectedSubtitle: nil)
        #expect(TrackMenu.subtitles(single).isEmpty)
        #expect(!TrackMenu.hasChoices(single))
        #expect(TrackMenu.hasChoices(Self.tracks))
    }

    @Test(
        "player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv the container comes from the extension"
    )
    func container() {
        #expect(StreamLine.container(pathExtension: "ts", route: .demuxer) == "MPEG-TS")
        #expect(StreamLine.container(pathExtension: "m3u8", route: .system) == "HLS")
        #expect(StreamLine.container(pathExtension: "mp4", route: .system) == "MP4")
        #expect(StreamLine.container(pathExtension: "mkv", route: .demuxer) == "Matroska")
        #expect(StreamLine.container(pathExtension: "", route: .system) == "HLS", "handed over to Apple's player as HLS")
        #expect(StreamLine.container(pathExtension: "", route: .demuxer) == nil)
    }
}
