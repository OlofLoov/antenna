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
        // While an earlier skip reopens the film, the start it had stands in.
        guard let start = current?.start ?? lastStart, let request else { throw SeekRefusal.notSeekable }
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
        let origin = start.origin
        release()
        if playing { set(.buffering) }
        var options = request.options
        options.startPosition = time
        log("demux seek \(redacted(request.url)) to \(Int(time.inSeconds))s")
        do {
            try await open(request.url, options: options, origin: origin, generation: mine)
            // Where the reopened film starts, so a skip that lands elsewhere shows in the log.
            if let landed = current?.start.map({ CMTimeSubtract($0.startTime, $0.origin).seconds }) {
                log("demux seek \(redacted(request.url)) ready at \(String(format: "%.1f", landed))s")
            }
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            log("demux seek \(redacted(request.url)) failed: \(failure)")
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
