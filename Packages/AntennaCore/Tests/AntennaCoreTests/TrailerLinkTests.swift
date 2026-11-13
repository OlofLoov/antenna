import Foundation
import Testing

@testable import AntennaCore

/// Which trailer links Apple TV can play in the app.
@Suite struct TrailerLinkTests {
    private func plays(_ link: String) throws -> Bool {
        TrailerLink.playsInApp(try #require(URL(string: link)))
    }

    @Test("title-detail-and-episode-picker/trailer video files and HLS playlists play in the app")
    func playable() throws {
        #expect(try plays("https://cdn.example/trailers/night-ferry.m3u8"))
        #expect(try plays("http://cdn.example/trailers/night-ferry.MP4"))
        #expect(try plays("https://cdn.example/t.m4v?token=1"))
        #expect(try plays("https://cdn.example/t.mov"))
    }

    @Test("title-detail-and-episode-picker/trailer web pages and YouTube do not")
    func webPages() throws {
        #expect(try !plays("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        #expect(try !plays("https://youtu.be/dQw4w9WgXcQ"))
        #expect(try !plays("https://m.youtube.com/v/clip.mp4"))
        #expect(try !plays("https://trailers.example/night-ferry"))
        #expect(try !plays("ftp://cdn.example/t.mp4"))
    }
}
