import AntennaCore
import Foundation
import Network
import Observation

/// What finds the Apple TVs that are open on this network. `PlayOnBrowser`
/// is the app's; a Debug build's UI tests script one.
@MainActor
protocol PlayOnBrowsing: AnyObject {
    /// Each TV advertising now, by its device id.
    var endpoints: [UUID: NWEndpoint] { get }
    /// True once the user refused local network access.
    var denied: Bool { get }
    func start()
    func stop()
}

/// Browses for `_antenna-play._tcp` while the scene is active
/// (play-on-apple-tv/the-local-network-is-asked-for-only-when-needed).
/// Starting it is what makes iOS ask for local network access, so the
/// owner starts it only after the user opens Play on with a TV on the
/// account. A refused prompt leaves it waiting with a policy error, which
/// it reports as `denied`.
@MainActor @Observable
final class PlayOnBrowser: PlayOnBrowsing {
    private(set) var endpoints: [UUID: NWEndpoint] = [:]
    private(set) var denied = false
    @ObservationIgnored private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: PlayOnKey.serviceType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.changed(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated { self?.found(results) }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        endpoints = [:]
    }

    private func changed(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            denied = false
        case .waiting(let error), .failed(let error):
            denied = Self.isPolicyDenied(error)
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func found(_ results: Set<NWBrowser.Result>) {
        var endpoints: [UUID: NWEndpoint] = [:]
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint, let id = UUID(uuidString: name) else { continue }
            endpoints[id] = result.endpoint
        }
        self.endpoints = endpoints
    }

    /// The error a browser reports while local network access is refused.
    static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) }
        return false
    }
}
