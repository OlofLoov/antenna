import AVFoundation
import AntennaTestSupport
import Foundation
import Testing

@MainActor
@Suite struct DiagFilePlaybackTests {
    @Test("diag: fixture files open from file URLs", arguments: ["film.mp4", "radio.mp3", "radio.aac", "hls/segment0.ts"])
    func opens(path: String) async throws {
        let url = try FixtureServer.fixtures().appending(path: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
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
        print("DIAG file:", path, item.status.rawValue, chain.joined(separator: " <- "))
        _ = player
    }
}
