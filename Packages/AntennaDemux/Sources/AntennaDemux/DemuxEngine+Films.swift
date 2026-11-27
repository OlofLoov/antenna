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

extension DemuxEngine {
    /// The bytes a film's first run reads: a read-ahead to disk when the
    /// server skips and gave the length and the device has room
    /// (playback-engine/films-read-ahead-to-disk), the connection otherwise.
    /// Live TV, and a load that does not say it is a film, read the connection.
    func filmSource(_ bytes: HTTPByteStream, url: URL, options: PlaybackOptions) -> any DemuxBytes {
        guard options.isLive == false,
            let film = FilmReadAhead.make(bytes, url: url, session: session, limits: filmLimits)
        else {
            return SeekableSource(bytes, url: url, session: session)
        }
        self.film = film
        return film.reader()
    }

    /// A reader over the film read ahead for `url`, for a skip or a
    /// reconnect. Nil when there is none, and after its download failed for
    /// good, which deletes it so the film starts over from a new connection.
    func filmReader(for url: URL, options: PlaybackOptions) -> FilmReader? {
        guard options.isLive == false, options.timeshift == nil, let film, film.url == url else { return nil }
        guard film.isUsable else {
            discardFilm()
            return nil
        }
        return film.reader()
    }

    /// Stops the film's download and deletes what it read ahead.
    func discardFilm() {
        film?.discard()
        film = nil
    }
}

extension Duration {
    /// The duration in seconds, as a Double.
    var inSeconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
