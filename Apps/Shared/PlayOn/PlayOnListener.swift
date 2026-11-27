import AntennaCore
import Foundation
import Network

/// The Apple TV's end of the link: a TLS-PSK listener on the home network,
/// advertised over Bonjour as `_antenna-play._tcp` under the TV's device id
/// alone, so the announcement carries no name, account or source
/// (play-on-apple-tv/a-request-holds-no-link-and-no-login). It accepts only
/// the devices in `accepted`, each with its own key, and hands every
/// `play` to `request` with a way to answer it
/// (play-on-apple-tv/only-the-same-account-can-send-over-the-network).
@MainActor
final class PlayOnListener {
    /// Answers one request on the link it came on.
    typealias Reply = @MainActor (PlayAnswer.Result) -> Void

    /// Told about each request a device on the account sends.
    var request: @MainActor (PlayRequest, @escaping Reply) -> Void = { _, reply in reply(.notFound) }
    /// Told when a handshake fails, which is how a device the TV does not
    /// know yet shows up; the owner fetches the device list again.
    var refused: @MainActor () -> Void = {}
    /// The port the listener got, once it is ready.
    private(set) var port: NWEndpoint.Port?

    private let device: PlayOnDevice
    private let advertises: Bool
    private var listener: NWListener?
    private var keys: [UUID: Data] = [:]
    private var links: [ObjectIdentifier: PlayLink] = [:]
    private var running = false

    /// `advertises` false skips Bonjour, for tests that connect by port.
    init(device: PlayOnDevice, advertises: Bool = true) {
        self.device = device
        self.advertises = advertises
    }

    /// The devices that may send: every phone, iPad and Mac record on the
    /// account, each with the key this TV derives for it. A change restarts
    /// the listener with the new keys; open links stay up.
    func accept(_ devices: [PlayDeviceInfo]) {
        var keys: [UUID: Data] = [:]
        for sender in devices where sender.kind != .tv && sender.id != device.id {
            if let key = try? device.linkKey(receivingFrom: sender) { keys[sender.id] = key }
        }
        guard keys != self.keys else { return }
        self.keys = keys
        if running { restart() }
    }

    func start() {
        guard !running else { return }
        running = true
        restart()
    }

    /// Stops listening and closes every link.
    func stop() {
        running = false
        listener?.cancel()
        listener = nil
        port = nil
        links.values.forEach { $0.close() }
        links = [:]
    }

    private func restart() {
        listener?.cancel()
        var entries = keys.map { (identity: PlayOnKey.identity(sender: $0.key), key: $0.value) }
        // TLS needs a key to start; one nobody holds keeps the listener up.
        if entries.isEmpty { entries = [(Data(UUID().uuidString.utf8), Data((0..<32).map { _ in UInt8.random(in: 0...255) }))] }
        guard let listener = try? NWListener(using: PlayLinkParameters.server(keys: entries), on: port ?? .any) else { return }
        if advertises {
            listener.service = NWListener.Service(
                name: device.id.uuidString.lowercased(), type: PlayOnKey.serviceType, txtRecord: NWTXTRecord(["v": "1"]))
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            MainActor.assumeIsolated {
                guard let self, let listener, self.listener === listener else { return }
                if case .ready = state { self.port = listener.port }
                if case .failed = state { self.listenerFailed() }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accepted(connection) }
        }
        self.listener = listener
        listener.start(queue: .main)
    }

    private func listenerFailed() {
        // The port may be taken after a restart; the next start picks another.
        port = nil
        guard running else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, running else { return }
            restart()
        }
    }

    private func accepted(_ connection: NWConnection) {
        let link = PlayLink(connection)
        let id = ObjectIdentifier(link)
        links[id] = link
        link.changed = { [weak self] state in
            guard let self, case .ended(let reason) = state else { return }
            links[id] = nil
            if reason == .refused { refused() }
        }
        link.received = { [weak self, weak link] result in
            guard let self, let link else { return }
            switch result {
            case .success(.play(let request)) where request.target == device.id:
                self.request(request) { [weak link] result in
                    link?.send(.answer(PlayAnswer(requestID: request.id, result: result)))
                }
            case .success(.play(let request)):
                link.send(.answer(PlayAnswer(requestID: request.id, result: .notFound)))
            case .failure(.unsupportedVersion(let requestID)):
                if let requestID { link.send(.answer(PlayAnswer(requestID: requestID, result: .unsupportedVersion))) }
            case .success, .failure:
                break
            }
        }
        link.start()
    }
}
