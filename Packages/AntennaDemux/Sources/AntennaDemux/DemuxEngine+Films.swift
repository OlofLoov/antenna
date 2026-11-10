import AntennaCore
import CoreMedia
import Foundation

extension DemuxEngine {
    /// Moves a film to `time` from its start, landing on the keyframe at or
    /// before it (playback-engine/films-start-where-you-left-off-skip-and-end).
    /// A time past the end finishes the film and fetches nothing more until
    /// play starts it again from the beginning. Throws `SeekRefusal.live`
    /// for live TV and `.notSeekable` for a film whose server cannot skip.
    public func seek(to time: Duration) async throws {
        guard let start = current?.start, let request else { throw SeekRefusal.notSeekable }
        guard !isLive else { throw SeekRefusal.live }
        guard start.canSeek else { throw SeekRefusal.notSeekable }
        if let length = start.duration, time.inSeconds >= length.seconds {
            generation += 1
            release()
            set(.ended)
            return
        }
        generation += 1
        let mine = generation
        let playing = state == .playing || state == .buffering
        release()
        if playing { set(.buffering) }
        var options = request.options
        options.startPosition = time
        do {
            try await open(request.url, options: options, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            set(.failed(failure))
        } catch {
            return
        }
    }
}

extension Duration {
    /// The duration in seconds, as a Double.
    var inSeconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
