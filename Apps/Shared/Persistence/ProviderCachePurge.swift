import Foundation

/// Earlier versions fetched provider calls through the shared session, whose
/// URL cache kept replies on disk under addresses holding the password. The
/// first launch of this version empties that cache once
/// (source-management/provider-replies-are-not-kept-on-disk). Posters fill
/// it again as they load.
enum ProviderCachePurge {
    static let key = "sources.providerCachePurged"

    /// Empties `cache` unless `defaults` records that it was done before.
    static func run(_ defaults: UserDefaults = .standard, cache: URLCache = .shared) {
        guard !defaults.bool(forKey: key) else { return }
        cache.removeAllCachedResponses()
        defaults.set(true, forKey: key)
    }
}
