import AntennaCore
import Foundation
import Observation

/// A link that carries frames; `PlayLink` is the app's, tests script one.
@MainActor
protocol PlayOnLinking: AnyObject {
    func listen(_ handler: @escaping @MainActor (Result<PlayMessage, PlayMessage.DecodeError>) -> Void)
    var changed: @MainActor (PlayLink.State) -> Void { get set }
    func send(_ message: PlayMessage)
    func close()
}

extension PlayLink: PlayOnLinking {}

/// The phone connected to one Apple TV after a request went over the
/// network (play-on-apple-tv/connected-to-a-tv): the open link, what the
/// TV says it plays, play and pause, handing the item back to the phone,
/// and Disconnect. It ends on Disconnect, a `stopped` status (after
/// "Stopped on Living Room" shows for three seconds), ten seconds without a
/// status, or a link that drops (play-on-apple-tv/the-connection-ends-cleanly).
@MainActor @Observable
final class PlayOnConnection {
    let tv: PlayTV
    /// What the TV last said it plays.
    private(set) var status: PlayStatus?
    /// True for the three seconds "Stopped on Living Room" shows.
    private(set) var stopped = false
    /// True once the connection is over.
    private(set) var isOver = false

    /// Told once when the connection ends.
    @ObservationIgnored var ended: @MainActor () -> Void = {}

    @ObservationIgnored let link: any PlayOnLinking
    @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
    @ObservationIgnored private let liveness: Duration
    @ObservationIgnored private let stoppedShows: Duration
    @ObservationIgnored private var answers: [UUID: @MainActor (PlayAnswer.Result?) -> Void] = [:]
    @ObservationIgnored private var handingOff: (@MainActor (PlayStatus?) -> Void)?
    @ObservationIgnored private var watchdog: Task<Void, Never>?

    init(
        tv: PlayTV, link: any PlayOnLinking,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        liveness: Duration = .seconds(10), stoppedShows: Duration = .seconds(3)
    ) {
        self.tv = tv
        self.link = link
        self.sleep = sleep
        self.liveness = liveness
        self.stoppedShows = stoppedShows
    }

    /// Starts reading the link and the liveness timer.
    func start() {
        link.listen { [weak self] result in
            guard let self, case .success(let message) = result else { return }
            receive(message)
        }
        link.changed = { [weak self] state in
            if case .ended = state { self?.finish() }
        }
        resetWatchdog()
    }

    /// True while the TV plays or has paused.
    var isPlaying: Bool { status?.state == .playing }

    // MARK: Sending

    /// Sends another request over the open link and waits for the TV's
    /// answer; nil when none comes within `limit`.
    func send(_ request: PlayRequest, within limit: Duration = .seconds(3)) async -> PlayAnswer.Result? {
        await ask(.play(request), id: request.id, within: limit)
    }

    /// Asks the TV to drop the request with `id`; true when it answers
    /// `canceled` (play-on-apple-tv/the-phone-can-take-a-request-back).
    func cancel(_ id: UUID, within limit: Duration = .seconds(3)) async -> Bool {
        await ask(.cancel(id), id: id, within: limit) == .canceled
    }

    /// Sends `message` and waits for the answer naming `id`, nil after `limit`.
    private func ask(_ message: PlayMessage, id: UUID, within limit: Duration) async -> PlayAnswer.Result? {
        guard !isOver else { return nil }
        return await withCheckedContinuation { continuation in
            var done = false
            let resolve: @MainActor (PlayAnswer.Result?) -> Void = { result in
                guard !done else { return }
                done = true
                continuation.resume(returning: result)
            }
            answers[id] = resolve
            link.send(message)
            Task { [weak self] in
                try? await self?.sleep(limit)
                self?.answers[id] = nil
                resolve(nil)
            }
        }
    }

    /// Plays or pauses on the TV; the button follows the TV's next status.
    func control(_ control: PlayControl) {
        guard !isOver else { return }
        link.send(.control(control))
    }

    /// Asks the TV to stop and say where it was, then ends the connection
    /// (play-on-apple-tv/play-on-this-iphone). Nil when the TV does not
    /// answer within `limit`.
    func handOff(within limit: Duration = .seconds(3)) async -> PlayStatus? {
        guard !isOver else { return nil }
        let answer = await withCheckedContinuation { continuation in
            var done = false
            let resolve: @MainActor (PlayStatus?) -> Void = { status in
                guard !done else { return }
                done = true
                continuation.resume(returning: status)
            }
            handingOff = resolve
            link.send(.control(.handOff))
            Task { [weak self] in
                try? await self?.sleep(limit)
                resolve(nil)
            }
        }
        handingOff = nil
        finish()
        return answer
    }

    /// Leaves the TV playing and forgets it.
    func disconnect() {
        guard !isOver else { return }
        link.send(.control(.disconnect))
        finish()
    }

    /// Closes the link without telling the TV, as when the phone goes to
    /// the background; the TV keeps playing and the phone may connect again.
    func disconnectQuietly() {
        finish()
    }

    /// Takes a status read before the connection started, as on reconnecting.
    func adopt(_ status: PlayStatus) {
        self.status = status
    }

    // MARK: Receiving

    private func receive(_ message: PlayMessage) {
        switch message {
        case .status(let status):
            self.status = status
            resetWatchdog()
            if let handingOff {
                self.handingOff = nil
                return handingOff(status)
            }
            if status.state == .stopped { stop() }
        case .answer(let answer):
            answers.removeValue(forKey: answer.requestID)?(answer.result)
        case .play, .control, .cancel:
            break
        }
    }

    /// The TV stopped: "Stopped on Living Room" for three seconds, then the end.
    private func stop() {
        guard !stopped else { return }
        stopped = true
        watchdog?.cancel()
        Task { [weak self] in
            guard let self else { return }
            try? await sleep(stoppedShows)
            finish()
        }
    }

    private func resetWatchdog() {
        watchdog?.cancel()
        let liveness = liveness
        watchdog = Task { [weak self] in
            do { try await self?.sleep(liveness) } catch { return }
            self?.finish()
        }
    }

    private func finish() {
        guard !isOver else { return }
        isOver = true
        watchdog?.cancel()
        handingOff?(nil)
        handingOff = nil
        for answer in answers.values { answer(nil) }
        answers = [:]
        link.close()
        ended()
    }
}
