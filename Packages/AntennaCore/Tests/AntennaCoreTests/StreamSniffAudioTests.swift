import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

/// The first bytes of internet radio read as sound
/// (playback-engine/every-common-stream-type-plays).
@Suite struct StreamSniffAudioTests {
    private func head(_ fixture: String, skipping: Int = 0) throws -> Data {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: fixture))
        return Data(data.dropFirst(skipping).prefix(StreamProbe.headSize))
    }

    @Test(
        "playback-engine/every-common-stream-type-plays MP3 and AAC radio read as sound from the start or from mid-frame",
        arguments: [("radio.mp3", 0), ("radio.mp3", 1000), ("radio.mp3", 1001), ("radio.aac", 0), ("radio.aac", 333)])
    func radioIsSound(fixture: String, skipping: Int) throws {
        #expect(StreamSniff(try head(fixture, skipping: skipping)) == .audio)
    }

    @Test(
        "playback-engine/every-common-stream-type-plays video, pages and garbage do not read as sound",
        arguments: ["channel.ts", "channel.mkv", "film.mp4", "page.html", "garbage.bin", "hls/index.m3u8"])
    func othersAreNot(fixture: String) throws {
        #expect(StreamSniff(try head(fixture)) != .audio)
    }
}
