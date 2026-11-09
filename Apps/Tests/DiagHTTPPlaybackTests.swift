import AVFoundation
import AntennaTestSupport
import Foundation
import Testing

@MainActor
@Suite(.serialized) struct DiagHTTPPlaybackTests {
    nonisolated static let variants = ["plain", "public", "localhost", "noranges"]

    @Test("diag: plain AVPlayer over the fixture server", arguments: variants)
    func opens(variant: String) async throws {
        let server = try FixtureServer()
        var base = try await server.start()
        if variant == "localhost", let port = base.port {
            base = try #require(URL(string: "http://localhost:\(port)/"))
        }
        if variant == "noranges" { await server.always("/film.mp4", .ignoreRanges) }
        var url = base.appending(path: "film.mp4")
        if variant == "public" { url = try #require(URL(string: "https://www.w3schools.com/html/mov_bbb.mp4")) }
        let options: [String: Any] = [:]
        let item = AVPlayerItem(asset: AVURLAsset(url: url, options: options))
        let player = AVPlayer(playerItem: item)
        var waited = 0
        while item.status == .unknown, waited < 100 {
            try await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        var trace = item.error as NSError?
        var chain: [String] = []
        while let error = trace {
            chain.append("\(error.domain) \(error.code)")
            trace = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        print("DIAG http:", variant, item.status.rawValue, chain.joined(separator: " <- "))
        _ = player
        await server.stop()
    }
}
