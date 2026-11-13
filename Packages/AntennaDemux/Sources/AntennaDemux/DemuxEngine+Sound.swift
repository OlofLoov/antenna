@preconcurrency import AVFoundation
import AntennaCore
import CoreMedia
import Foundation

extension DemuxEngine {
    /// Times in a row the audio renderer may fail on one stream before it
    /// plays without sound.
    static let soundFailureLimit = 3

    /// Keeps the sound going when the audio renderer drops what it holds
    /// (playback-engine/sound-keeps-playing-when-its-format-changes). The
    /// renderer flushes itself when the output changes, as when a receiver
    /// switches to Dolby or headphones connect, and the sound from the flush
    /// time is queued again out of the run's ring.
    func watchSoundFlushes() -> SoundFlushWatch {
        let token = NotificationCenter.default.addObserver(
            forName: .AVSampleBufferAudioRendererWasFlushedAutomatically, object: audioRenderer, queue: .main
        ) { [weak self] note in
            let time = (note.userInfo?[AVSampleBufferAudioRendererFlushTimeKey] as? NSValue)?.timeValue ?? .invalid
            MainActor.assumeIsolated { self?.soundFlushed(at: time) }
        }
        return SoundFlushWatch(token)
    }

    func soundFlushed(at time: CMTime) {
        guard audioOnClock, let current, current.start != nil else { return }
        let from = time.isNumeric ? time : synchronizer.currentTime()
        log("demux audio output changed, sound queued again")
        current.run.resendSound(from: from)
    }

    /// Recovers from a failed audio renderer, which stays silent until it is
    /// flushed: the sound from now is queued again. A renderer that keeps
    /// failing on the stream is taken off the clock, and the stream plays
    /// without sound and says so.
    func checkSound() {
        guard audioOnClock, audioRenderer.status == .failed, var current, let start = current.start else { return }
        let code = audioRenderer.error.map { String(($0 as NSError).code) } ?? "none"
        current.soundFailures += 1
        self.current = current
        guard current.soundFailures <= Self.soundFailureLimit else {
            log("demux audio renderer failed again (\(code)), playing without sound")
            playWithoutSound()
            soundSwitched(
                PresentationInfo.Audio(codec: start.audio?.codec ?? "audio", channels: start.soundChannels, isDecodable: false),
                generation: generation)
            return
        }
        log("demux audio renderer failed (\(code)), sound queued again")
        current.audioFeed.flush()
        current.run.resendSound(from: synchronizer.currentTime())
    }
}

/// Removes the audio renderer's flush observer when the engine goes.
final class SoundFlushWatch: @unchecked Sendable {
    private let token: any NSObjectProtocol

    init(_ token: any NSObjectProtocol) {
        self.token = token
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
