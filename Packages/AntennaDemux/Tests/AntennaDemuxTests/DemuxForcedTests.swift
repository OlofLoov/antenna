import AntennaCore
import Foundation
import Testing

@testable import AntennaDemux

/// Forced subtitle streams on the FFmpeg path.
@Suite struct DemuxForcedTests {
    private func stream(_ index: Int, kind: DemuxedStream.Kind, codec: String, language: String, forced: Bool) -> DemuxedStream {
        DemuxedStream(
            index: index, kind: kind, codec: codec, extradata: Data(), width: 0, height: 0, sampleRate: 0, channels: 0,
            interlaced: false, language: language, frameRate: nil, isDefault: false, isForced: forced)
    }

    @Test("playback-engine/forced-subtitles-in-your-language-show a stream marked forced is a forced track")
    func forcedStreams() {
        let streams = [
            stream(0, kind: .audio, codec: "aac", language: "eng", forced: false),
            stream(1, kind: .subtitle, codec: "subrip", language: "eng", forced: false),
            stream(2, kind: .subtitle, codec: "subrip", language: "eng", forced: true),
        ]
        let tracks = DemuxStart.tracks(of: streams)
        #expect(tracks.subtitles.map(\.track.isForced) == [false, true])
        #expect(tracks.audio.map(\.track.isForced) == [false])
    }
}
