import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// The sound formats films and channels carry beyond AAC, MP3 and Dolby:
/// each fixture's sound is built into buffers and decoded the way the
/// audio renderer takes them, by Apple's decoder or as PCM.
@Suite(.timeLimit(.minutes(2))) struct DemuxSoundFormatTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let file: String
        let codec: String
        let channels: Int
        let seconds: Double
        var testDescription: String { "\(codec) in \(file)" }
    }

    static let cases =
        [
            Case(file: "dts-5.1.m2ts", codec: "dts", channels: 6, seconds: 2),
            Case(file: "dts-and-ac3.mkv", codec: "dts", channels: 2, seconds: 2),
            Case(file: "truehd-5.1.mkv", codec: "truehd", channels: 6, seconds: 2),
            Case(file: "opus.ts", codec: "opus", channels: 2, seconds: 2),
            Case(file: "opus-5.1.mkv", codec: "opus", channels: 6, seconds: 2),
            Case(file: "flac.mp4", codec: "flac", channels: 2, seconds: 2),
            Case(file: "flac-5.1.mkv", codec: "flac", channels: 6, seconds: 2),
            Case(file: "s302m.ts", codec: "s302m", channels: 2, seconds: 0.5),
            Case(file: "aac-pce.ts", codec: "aac", channels: 4, seconds: 2),
            Case(file: "aac-pce.mkv", codec: "aac", channels: 4, seconds: 2),
            Case(file: "he-aac-v2.ts", codec: "aac", channels: 2, seconds: 2),
            Case(file: "latm.ts", codec: "aac_latm", channels: 2, seconds: 2),
        ]
        + ["pcm_s16le", "pcm_s24le", "pcm_s32le", "pcm_f32le"].map { Case(file: "pcm.mkv", codec: $0, channels: 2, seconds: 0.5) }
        + ["pcm_s16be", "pcm_s24be", "pcm_s32be", "pcm_f32be", "pcm_s16le"].map {
            Case(file: "pcm.mov", codec: $0, channels: 2, seconds: 0.5)
        }

    @Test("playback-engine/sound-in-every-common-format-plays each format decodes on all its channels", arguments: cases)
    func decodes(_ format: Case) throws {
        let file = try FixtureServer.fixtures().appending(path: format.file)
        let outcome = try SoundDecoding.decode(file) { $0.kind == .audio && $0.codec == format.codec }
        #expect(outcome.failures == 0)
        #expect(outcome.pieces.map(\.channels) == [format.channels])
        let piece = try #require(outcome.pieces.first)
        #expect(piece.sampleRate == 48000)
        #expect(abs(Double(piece.frames) / piece.sampleRate - format.seconds) < 0.15, "plays its \(format.seconds) seconds")
        #expect(piece.level > 0.01, "carries its tone")
    }
}
