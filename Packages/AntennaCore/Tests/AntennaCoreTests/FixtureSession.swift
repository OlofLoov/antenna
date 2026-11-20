import AntennaCore
import Foundation

extension PlaybackNetwork {
    /// The playback session with a 60 second request timeout, for tests
    /// against the local fixture server. The app's 8 seconds can pass on a
    /// loaded CI runner before the first request reaches the server.
    static func makeFixtureSession() -> URLSession {
        let configuration = makeSession().configuration
        configuration.timeoutIntervalForRequest = 60
        return URLSession(configuration: configuration)
    }
}
