@preconcurrency import AVFoundation
import CoreMedia
import Foundation

extension DemuxEngine {
    /// How long the clock may stand still while playing before the audio
    /// output counts as stalled.
    static let clockStallLimit = Duration.milliseconds(1500)

    /// Watches the clock while the engine plays. The synchronizer follows
    /// the audio output, so a stalled output (a hung audio service, an
    /// AirPlay speaker that went away) would freeze the picture too. When
    /// the clock stands still for `clockStallLimit`, the sound is taken off
    /// the clock and the picture plays on.
    func watchClock(_ now: CMTime) {
        guard audioOnClock, wantsPlay, synchronizer.rate > 0, current?.start != nil else {
            clockCheck = nil
            return
        }
        guard let check = clockCheck, check.time == now else {
            clockCheck = (now, .now)
            return
        }
        if ContinuousClock.now - check.since >= Self.clockStallLimit { playWithoutSound() }
    }

    /// Takes the audio renderer off the clock and plays the picture on the
    /// host clock from where it stood. Sound buffers are dropped from then on
    /// for this stream, so they cannot fill up and stop the picture.
    func playWithoutSound() {
        let at = synchronizer.currentTime()
        log("demux audio output stalled, playing without sound")
        audioOnClock = false
        clockCheck = nil
        current?.audioFeed.discard()
        synchronizer.removeRenderer(audioRenderer, at: at, completionHandler: nil)
        synchronizer.setRate(wantsPlay ? 1 : 0, time: at)
    }

    /// Puts the audio renderer back on the clock for a new stream.
    func restoreAudioClock() {
        clockCheck = nil
        guard !audioOnClock else { return }
        synchronizer.addRenderer(audioRenderer)
        audioOnClock = true
    }
}
