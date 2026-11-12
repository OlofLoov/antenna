import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// DVB picture subtitles in raw MPEG-TS, on `dvb-subtitles.ts`: German sound,
/// and German and English DVB subtitles, one bar each from 0.5 to 2 seconds
/// and the English one again from 3 to 4.5. The tests that decode need an
/// FFmpeg build with the DVB subtitle decoder (`ffmpeg-7.1.3-2` or later).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxDVBSubtitleTests {
    private func playing(options: PlaybackOptions) async throws -> (FixtureServer, DemuxEngine) {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "dvb-subtitles.ts"), options: options)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        return (server, engine)
    }

    @Test(
        "playback-engine/picture-subtitles-in-broadcast-streams a broadcast channel with picture subtitles",
        .enabled(if: DVBSubtitleDecoder.isAvailable))
    func listsAndShowsPictures() async throws {
        let english = PlaybackOptions(preferredAudioLanguages: ["en"], preferredSubtitleLanguages: ["en"], subtitleMode: .auto)
        let (server, engine) = try await playing(options: english)
        let cues = Recorded(await engine.subtitleCues())
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.subtitles.map(\.languageCode) == ["ger", "eng"])
        #expect(tracks.selectedSubtitle == "subtitle-1", "German sound starts English subtitles")

        #expect(await eventually(timeout: .seconds(5)) { cues.values.contains { $0.first?.image != nil } })
        let pictures: [SubtitleImage] = cues.values.compactMap { $0.first?.image }
        let picture = try #require(pictures.first)
        #expect(picture.width == 144)
        #expect(picture.height == 48)
        #expect(picture.rgba.count == 144 * 48 * 4)
        #expect(abs(picture.frame.x - 0.4) < 0.01)
        #expect(abs(picture.frame.width - 0.2) < 0.01)
        #expect(picture.frame.y > 0.7 && picture.frame.y + picture.frame.height <= 1)
        cues.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/picture-subtitles-in-broadcast-streams a subtitle clears", .enabled(if: DVBSubtitleDecoder.isAvailable))
    func pictureClears() async throws {
        let (server, engine) = try await playing(options: PlaybackOptions())
        let cues = Recorded(await engine.subtitleCues())
        // English has a second page from 3 to 4.5 seconds, so a slow start still sees one show and clear.
        await engine.selectSubtitle("subtitle-1")
        #expect(await eventually(timeout: .seconds(8)) { cues.values.last?.first?.image != nil })
        #expect(await eventually(timeout: .seconds(8)) { cues.values.last == [] }, "the empty page clears the picture")
        cues.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test(
        "playback-engine/picture-subtitles-in-broadcast-streams each page becomes pictures placed on the page, then an empty page",
        .enabled(if: DVBSubtitleDecoder.isAvailable))
    func decodesPages() throws {
        let bytes = BytesReader(try Data(contentsOf: FixtureServer.fixtures().appending(path: "dvb-subtitles.ts")))
        let demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        let english = try #require(demuxer.streams.first { $0.codec == DVBSubtitleDecoder.codec && $0.language == "eng" })
        let decoder = try #require(DVBSubtitleDecoder(stream: english))
        var pages: [DVBSubtitleDecoder.Page] = []
        while let packet = demuxer.nextPacket() {
            guard packet.streamIndex == english.index, let page = decoder.decode(packet.data, at: packet.presentationTime) else {
                continue
            }
            pages.append(page)
        }
        #expect(pages.map(\.images.count) == [1, 0, 1, 0])
        let picture = try #require(pages.first?.images.first)
        #expect((picture.width, picture.height) == (144, 48))
        #expect(abs(picture.frame.x - 0.4) < 0.01)
    }

    @Test("playback-engine/picture-subtitles-in-broadcast-streams teletext is not listed")
    func teletextIsLeftOut() {
        func stream(_ index: Int, _ codec: String) -> DemuxedStream {
            DemuxedStream(
                index: index, kind: .subtitle, codec: codec, extradata: Data(), width: 0, height: 0, sampleRate: 0, channels: 0,
                interlaced: false, language: "eng", frameRate: nil, isDefault: false)
        }
        let listed = DemuxStart.tracks(of: [stream(0, "dvb_teletext"), stream(1, "dvb_subtitle")], decodesPictures: true)
        #expect(listed.subtitles.map(\.stream.codec) == ["dvb_subtitle"])
        let withoutDecoder = DemuxStart.tracks(of: [stream(1, "dvb_subtitle")], decodesPictures: false)
        #expect(withoutDecoder.subtitles.isEmpty, "a build without the decoder lists no picture subtitles")
    }
}

/// Hands a file's bytes to the demuxer from memory.
private final class BytesReader: @unchecked Sendable {
    let data: Data
    var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    func read(into buffer: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let length = min(count, data.count - offset)
        guard length > 0 else { return 0 }
        data.copyBytes(to: buffer, from: offset..<(offset + length))
        offset += length
        return length
    }
}
