import AntennaCore
import Foundation

extension DemuxEngine {
    /// Call with true while the user scans through channels, as
    /// `ZapTracker` tells, and false once they settle. While scanning, each
    /// channel starts at its first picture without waiting for its sound,
    /// and format reports and TV mode changes wait; settling gives them to
    /// the channel the user stayed on (playback-engine/channel-switching-is-fast).
    public func setScanning(_ scanning: Bool) {
        let settled = isScanning && !scanning
        isScanning = scanning
        guard settled, let start = current?.start else { return }
        publishFormat(start)
        matchDisplay(start)
    }

    /// Keeps `urls` open ahead of a zap, from `ZapAhead`, and closes the
    /// streams kept open for addresses no longer listed. A later `load` of
    /// one of them starts from its newest bytes with no new connection.
    /// Each holds one of the account's connections until it is loaded,
    /// dropped from the list, or the engine stops or pauses live TV.
    public func openAhead(_ urls: [URL]) {
        for (url, task) in standby where !urls.contains(url) {
            standby[url] = nil
            Self.drop(task)
        }
        let session = self.session
        for url in urls where standby[url] == nil && url != request?.url {
            standby[url] = Task {
                let bytes = HTTPByteStream(url: url, session: session)
                bytes.standbyWindow = Self.standbyWindow
                try await bytes.open()
                return bytes
            }
        }
    }

    /// The addresses kept open ahead now.
    public var openAheadAddresses: Set<URL> { Set(standby.keys) }

    static func drop(_ task: Task<HTTPByteStream, any Error>) {
        task.cancel()
        Task { try? await task.value.cancel() }
    }
}
