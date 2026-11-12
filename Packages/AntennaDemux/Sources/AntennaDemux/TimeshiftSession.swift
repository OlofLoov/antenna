import AntennaCore
import CoreMedia
import Foundation

/// The buffer of one tuned channel and what records into it. A new address
/// gets a new session; loading the same address again, as Try again does,
/// keeps it (timeshift-catch-up-and-start-over/changing-channel-starts-fresh).
@MainActor
final class TimeshiftSession {
    let url: URL
    let request: TimeshiftRequest
    private(set) var folder: URL?
    private(set) var buffer: TimeshiftBuffer?
    var recording: TimeshiftStatus.Recording
    var recorder: TimeshiftRecorder?
    /// True once a recorder started at a start point, so the next one starts after a gap.
    var hasRecorded = false
    /// The reader of the run playing, and where on the stream's clock its
    /// first frame is, for the playhead.
    var reader: TimeshiftReader?
    var runStart: (date: Date, time: CMTime)?
    /// The playhead last worked out, kept while no run plays.
    var playhead: Date?
    var notice: TimeshiftNotice?
    var noticeCount = 0
    /// Reconnects of the recorder while playback is behind live.
    var reconnect: Task<Void, Never>?
    var budget = ReconnectBudget()

    /// A session that records into `buffer` in `folder`.
    init(url: URL, request: TimeshiftRequest, folder: URL, buffer: TimeshiftBuffer) {
        self.url = url
        self.request = request
        self.folder = folder
        self.buffer = buffer
        recording = .recording
    }

    /// A session for an address that is not recorded, and why.
    init(url: URL, request: TimeshiftRequest, recording: TimeshiftStatus.Recording) {
        self.url = url
        self.request = request
        self.recording = recording
    }

    /// The buffer when it still records.
    var recordingBuffer: TimeshiftBuffer? {
        recording == .recording ? buffer : nil
    }

    func say(_ notice: TimeshiftNotice) {
        self.notice = notice
        noticeCount += 1
    }

    /// Stops recording for good with `reason` and deletes the buffer.
    func stopRecording(_ reason: TimeshiftStatus.Recording) {
        recording = reason
        discard()
    }

    /// Stops the recorder and the reader and deletes the buffer off the main path.
    func discard() {
        reconnect?.cancel()
        reconnect = nil
        recorder?.cancel()
        recorder = nil
        reader?.cancel()
        reader = nil
        runStart = nil
        buffer?.finish()
        buffer = nil
        if let folder { request.store.retire(folder) }
        folder = nil
    }
}
