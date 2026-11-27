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

/// Sends one request to a TV over the network. `NetworkPlaySender` is the
/// app's; tests and UI tests use a scripted one.
@MainActor
protocol PlayOnSending: AnyObject {
    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> PlaySendOutcome
}

/// Connects with the key this device shares with the TV, sends `play` and
/// waits for the `answer` with the request's id
/// (play-on-apple-tv/starts-at-once-on-the-same-network). The link closes
/// once the answer is in or the time is up.
@MainActor
final class NetworkPlaySender: PlayOnSending {
    private let device: PlayOnDevice

    init(device: PlayOnDevice) {
        self.device = device
    }

    func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> PlaySendOutcome {
        guard let key = try? device.linkKey(sendingTo: tv) else { return .refused }
        let link = PlayLink(to: endpoint, key: key, identity: PlayOnKey.identity(sender: device.id))
        defer { link.close() }
        return await withCheckedContinuation { continuation in
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
    }
}
