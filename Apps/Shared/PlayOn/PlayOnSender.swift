import AntennaCore
import Foundation
import Network

/// How a send over the network went.
enum PlaySendOutcome: Equatable, Sendable {
    /// The TV answered.
    case answered(PlayAnswer.Result)
    /// The handshake failed: the TV does not know this device yet, or holds an old key.
    case refused
    /// No connection within the time allowed, or it dropped before an answer.
    case unreachable
    /// The request reached the TV and no answer came in time.
    case noAnswer

    /// Why the send failed, nil when the TV answered.
    var failure: PlaySendFailure? {
        switch self {
        case .answered: nil
        case .refused: .refused
        case .unreachable: .unreachable
        case .noAnswer: .noAnswer
        }
    }
}

/// How long a send may take: `reach` to open the link, then `answer` for
/// the TV's answer once the request is on it, which covers a source still
/// loading on the TV (play-on-apple-tv/starts-at-once-on-the-same-network).
struct PlaySendLimits: Equatable, Sendable {
    var reach = Duration.seconds(3)
    var answer = Duration.seconds(12)
}

/// A send's outcome and, when the TV answered, the link still open to it,
/// which the phone keeps while it is connected
/// (play-on-apple-tv/connected-to-a-tv). Whoever does not keep it closes it.
struct PlaySend {
    var outcome: PlaySendOutcome
    var link: (any PlayOnLinking)?
}

/// Sends one request to a TV over the network, or opens a link to one.
/// `NetworkPlaySender` is the app's; tests and UI tests use a scripted one.
@MainActor
protocol PlayOnSending: AnyObject {
    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, limits: PlaySendLimits) async -> PlaySend
    /// Opens a link with no request on it, for reconnecting; nil when the
    /// handshake fails or nothing answers within `limit`.
    func connect(to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> (any PlayOnLinking)?
    /// Asks the TV to drop the request with `id`; true when it answers
    /// `canceled` (play-on-apple-tv/the-phone-can-take-a-request-back).
    func cancel(_ id: UUID, on tv: PlayDeviceInfo, at endpoint: NWEndpoint, limits: PlaySendLimits) async -> Bool
}

/// Connects with the key this device shares with the TV, sends `play` and
/// waits for the `answer` with the request's id
/// (play-on-apple-tv/starts-at-once-on-the-same-network). The link stays
/// open after an answer and closes when the time is up.
@MainActor
final class NetworkPlaySender: PlayOnSending {
    private let device: PlayOnDevice

    init(device: PlayOnDevice) {
        self.device = device
    }

    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, limits: PlaySendLimits) async -> PlaySend {
        await exchange(.play(request), id: request.id, to: tv, at: endpoint, limits: limits)
    }

    func cancel(_ id: UUID, on tv: PlayDeviceInfo, at endpoint: NWEndpoint, limits: PlaySendLimits) async -> Bool {
        let sent = await exchange(.cancel(id), id: id, to: tv, at: endpoint, limits: limits)
        sent.link?.close()
        return sent.outcome == .answered(.canceled)
    }

    /// Opens a link, sends `message` once it is ready and waits for the
    /// answer naming `id`: `limits.reach` for the link, then `limits.answer`.
    private func exchange(
        _ message: PlayMessage, id: UUID, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, limits: PlaySendLimits
    ) async -> PlaySend {
        guard let key = try? device.linkKey(sendingTo: tv) else { return PlaySend(outcome: .refused) }
        let link = PlayLink(to: endpoint, key: key, identity: PlayOnKey.identity(sender: device.id))
        let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<PlaySendOutcome, Never>) in
            var finished = false
            func finish(_ outcome: PlaySendOutcome) {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: outcome)
            }
            link.changed = { state in
                switch state {
                case .ready:
                    link.send(message)
                    Task {
                        try? await Task.sleep(for: limits.answer)
                        finish(.noAnswer)
                    }
                case .ended(.refused): finish(.refused)
                case .ended: finish(.unreachable)
                case .connecting: break
                }
            }
            link.received = { result in
                if case .success(.answer(let answer)) = result, answer.requestID == id { finish(.answered(answer.result)) }
            }
            link.start()
            Task {
                try? await Task.sleep(for: limits.reach)
                if link.state == .connecting { finish(.unreachable) }
            }
        }
        link.changed = { _ in }
        link.holds = true
        guard case .answered = outcome, link.state == .ready else {
            link.close()
            return PlaySend(outcome: outcome)
        }
        return PlaySend(outcome: outcome, link: link)
    }

    func connect(to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> (any PlayOnLinking)? {
        guard let key = try? device.linkKey(sendingTo: tv) else { return nil }
        let link = PlayLink(to: endpoint, key: key, identity: PlayOnKey.identity(sender: device.id))
        let ready = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var finished = false
            func finish(_ ready: Bool) {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: ready)
            }
            link.changed = { state in
                switch state {
                case .ready: finish(true)
                case .ended: finish(false)
                case .connecting: break
                }
            }
            link.holds = true
            link.start()
            Task {
                try? await Task.sleep(for: limit)
                finish(false)
            }
        }
        link.changed = { _ in }
        guard ready else {
            link.close()
            return nil
        }
        return link
    }
}
