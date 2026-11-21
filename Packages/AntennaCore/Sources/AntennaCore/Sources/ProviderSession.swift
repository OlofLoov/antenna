import Foundation

extension URLSessionConfiguration {
    /// The configuration for every request that can carry a provider login
    /// in its address or headers: Xtream panel calls, playlist downloads and
    /// Jellyfin calls. It has no URL cache, so no reply is written to disk
    /// under an address that holds a password
    /// (source-management/provider-replies-are-not-kept-on-disk). Cookies
    /// stay in memory for the app's run, as some panels set one.
    public static var provider: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }
}

extension URLSession {
    /// The one session for provider requests, on `URLSessionConfiguration.provider`.
    public static let provider = URLSession(configuration: .provider)
}
