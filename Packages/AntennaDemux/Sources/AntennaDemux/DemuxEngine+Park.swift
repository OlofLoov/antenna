import AntennaCore
import Foundation

/// The live buffer set aside while Start over plays catch-up
/// (timeshift-catch-up-and-start-over/when-the-provider-s-catch-up-fails):
/// it keeps recording until catch-up plays, and comes back if catch-up
/// fails to start.
extension DemuxEngine {
    public func parkTimeshift() async {
        guard let session = timeshift, session.recordingBuffer != nil else { return }
        parked?.discard()
        session.reader?.cancel()
        session.reader = nil
        session.runStart = nil
        parked = session
        timeshift = nil
        timeshiftCast.send(.off)
    }

    public func resumeParkedTimeshift(at date: Date?) async throws {
        guard let session = parked, let buffer = session.recordingBuffer,
            let reader = buffer.reader(at: date.map { buffer.window?.clamped($0) ?? $0 })
        else { throw SeekRefusal.live }
        parked = nil
        generation += 1
        let mine = generation
        close()
        retireTimeshift()
        timeshift = session
        let options = PlaybackOptions(timeshift: session.request)
        request = (session.url, options)
        wantsPlay = true
        reopensOnPlay = false
        budget = ReconnectBudget(refusalsAreFinal: refusalsAreFinal)
        set(.loading)
        session.reader = reader
        do {
            try await startRun(TimeshiftBytes(reader), url: session.url, options: options, origin: nil, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { throw CancellationError() }
            close()
            set(.failed(failure))
            throw failure
        }
        guard generation == mine else { throw CancellationError() }
        publishTimeshift()
    }

    public func dropParkedTimeshift() async {
        parked?.discard()
        parked = nil
    }
}
