import AntennaCore
import Foundation
import Network
import Security

/// TLS over TCP with pre-shared keys, the PSK cipher suite and TLS 1.2 at
/// most, as Apple's peer-to-peer sample sets it up
/// (play-on-apple-tv/only-the-same-account-can-send-over-the-network).
/// The TV holds one key per device on the account and picks it by the
/// identity the sender offers; an unknown identity or a wrong key fails the
/// handshake before any frame is read.
enum PlayLinkParameters {
    /// A sender's parameters: its one key for one TV.
    static func client(key: Data, identity: Data) -> NWParameters {
        parameters([(identity, key)])
    }

    /// The TV's parameters: a key for every device it accepts.
    static func server(keys: [(identity: Data, key: Data)]) -> NWParameters {
        parameters(keys)
    }

    private static func parameters(_ keys: [(identity: Data, key: Data)]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for entry in keys {
            sec_protocol_options_add_pre_shared_key(
                options, dispatchData(entry.key) as __DispatchData, dispatchData(entry.identity) as __DispatchData)
        }
        if let suite = tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256)) {
            sec_protocol_options_append_tls_ciphersuite(options, suite)
        }
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        tcp.noDelay = true
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = false
        return parameters
    }

    private static func dispatchData(_ data: Data) -> DispatchData {
        data.withUnsafeBytes { DispatchData(bytes: $0) }
    }
}

/// Why a link ended or never opened.
enum PlayLinkError: Error, Equatable, Sendable {
    /// The handshake failed: the TV does not know this device, or the keys differ.
    case refused
    /// The other end could not be reached, or the connection dropped.
    case unreachable
    /// A frame did not decode, or was too long.
    case garbled
}

/// One TLS connection carrying `PlayMessage` frames, on the main queue.
/// Frames are read with `PlayFrames.Reader` from the stream as it arrives.
@MainActor
final class PlayLink {
    enum State: Equatable {
        case connecting, ready
        case ended(PlayLinkError?)
    }

    private(set) var state: State = .connecting
    /// Told about each frame the other end sends.
    var received: @MainActor (Result<PlayMessage, PlayMessage.DecodeError>) -> Void = { _ in }
    /// Told when the link opens and when it ends.
    var changed: @MainActor (State) -> Void = { _ in }

    private let connection: NWConnection
    private var reader = PlayFrames.Reader()

    init(_ connection: NWConnection) {
        self.connection = connection
    }

    /// A sender's link to `endpoint` with `key`.
    convenience init(to endpoint: NWEndpoint, key: Data, identity: Data) {
        self.init(NWConnection(to: endpoint, using: PlayLinkParameters.client(key: key, identity: identity)))
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.connectionChanged(state) }
        }
        connection.start(queue: .main)
    }

    /// Sends one frame; a message that does not encode is dropped.
    func send(_ message: PlayMessage) {
        guard let frame = try? PlayFrames.frame(message) else { return }
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    /// Ends the link; the other end sees it close.
    func close() {
        end(nil)
    }

    private func connectionChanged(_ state: NWConnection.State) {
        switch state {
        case .ready:
            guard self.state == .connecting else { return }
            self.state = .ready
            changed(.ready)
            receive()
        case .waiting(let error), .failed(let error):
            end(Self.reason(error))
        case .cancelled:
            end(nil)
        case .setup, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] content, _, complete, error in
            MainActor.assumeIsolated {
                guard let self, case .ready = self.state else { return }
                if let content, !content.isEmpty {
                    for result in self.reader.append(content) {
                        if case .failure(.tooLong) = result { return self.end(.garbled) }
                        self.received(result)
                    }
                }
                if let error { return self.end(Self.reason(error)) }
                if complete { return self.end(.unreachable) }
                self.receive()
            }
        }
    }

    private func end(_ reason: PlayLinkError?) {
        if case .ended = state { return }
        state = .ended(reason)
        connection.stateUpdateHandler = nil
        connection.cancel()
        changed(state)
    }

    /// A TLS error is a refused handshake; anything else, an unreachable end.
    static func reason(_ error: NWError) -> PlayLinkError {
        if case .tls = error { return .refused }
        return .unreachable
    }
}
