import AntennaCore
import Foundation

extension DemuxEngine {
    // MARK: Drops and reconnects

    /// The bytes ran out. What was queued plays out first; `tick` then ends
    /// the film or treats the live stream as dropped.
    func bytesEnded(_ failure: PlaybackFailure?, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        current?.bytesEnded = .some(failure)
    }

    /// A stream that played lost its data: reconnect after the budget's
    /// wait, or fail with `failure` once the budget says so.
    func dropped(_ failure: PlaybackFailure) {
        guard hasPlayed, let request, let next = budget.dropped(failure, at: .now) else {
            close()
            set(.failed(failure))
            return
        }
        log("demux reconnect \(next.attempt)/\(budget.maxAttempts) \(redacted(request.url)) \(failure)")
        generation += 1
        let mine = generation
        release()
        set(.reconnecting(attempt: next.attempt, of: budget.maxAttempts))
        let sleep = self.sleep
        reconnect = Task { [weak self] in
            do {
                try await sleep(next.delay)
            } catch {
                return
            }
            await self?.reopen(generation: mine)
        }
    }

    func reopen(generation mine: Int) async {
        guard generation == mine, let request else { return }
        do {
            try await open(request.url, options: request.options, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            dropped(failure)
        } catch {
            return
        }
    }
}
