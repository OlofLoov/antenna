import AntennaCore
import Foundation
import Network

/// How a send over the network went.
enum PlaySendOutcome: Equatable, Sendable {
    /// The TV answered.
    case answered(PlayAnswer.Result)
    /// The handshake failed: the TV does not know this device yet, or holds an old key.
    case refused
    /// No answer within the time allowed, or no connection.
    case noAnswer
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
    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> PlaySend
    /// Opens a link with no request on it, for reconnecting; nil when the
    /// handshake fails or nothing answers within `limit`.
    func connect(to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> (any PlayOnLinking)?
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

    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> PlaySend {
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
                case .ready: link.send(.play(request))
                case .ended(.refused): finish(.refused)
                case .ended: finish(.noAnswer)
                case .connecting: break
                }
            }
            link.received = { result in
                if case .success(.answer(let answer)) = result, answer.requestID == request.id { finish(.answered(answer.result)) }
            }
            link.start()
            Task {
                try? await Task.sleep(for: limit)
                finish(.noAnswer)
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
