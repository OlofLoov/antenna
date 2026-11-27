import Foundation

/// The sources whose HLS did not start on this device when a channel went
/// to AirPlay, and when (playback-engine/a-source-whose-hls-failed-cannot-airplay).
/// Each one is kept for `keptFor`, then HLS gets another try. It holds
/// source ids and dates only, never an address or a login, so it can sit in
/// `UserDefaults`.
public struct HLSFailureMemory: Codable, Sendable, Equatable {
    /// How long a source counts as unable to go to AirPlay after its HLS failed.
    public static let keptFor: TimeInterval = 7 * 86_400

    /// Source id, as its UUID string, to when its HLS last failed.
    private var failures: [String: Date]

    public init() {
        failures = [:]
    }

    /// True while `source`'s HLS failure is younger than `keptFor`.
    public func failedLately(_ source: UUID, now: Date) -> Bool {
        guard let failed = failures[source.uuidString] else { return false }
        return now.timeIntervalSince(failed) < Self.keptFor
    }

    /// Notes that `source`'s HLS failed at `date`, and drops every entry
    /// older than `keptFor`.
    public mutating func record(_ source: UUID, at date: Date) {
        failures = failures.filter { date.timeIntervalSince($0.value) < Self.keptFor }
        failures[source.uuidString] = date
    }
}

/// When a live channel plays as HLS so it can go to AirPlay
/// (playback-engine/a-channel-goes-to-airplay-as-hls).
public enum AirPlayHLS {
    /// The HLS link `channel` would go to AirPlay on: an Xtream live
    /// channel whose source offers HLS and whose HLS has not failed on this
    /// device lately. Nil for every other channel.
    public static func hlsAddress(for channel: Channel, offersHLS: Bool, memory: HLSFailureMemory, now: Date) -> URL? {
        guard offersHLS, let hls = XtreamLiveFormat.hlsAddress(for: channel) else { return nil }
        if let source = channel.sourceID, memory.failedLately(source, now: now) { return nil }
        return hls
    }

    /// What a live tune opens for `channel`, whose playable address is
    /// `resolved`. While the channel goes to AirPlay and has an HLS link,
    /// that link, with `resolved` as the fallback; otherwise `resolved`.
    public static func address(
        for channel: Channel, resolved: URL, toAirPlay: Bool, offersHLS: Bool, memory: HLSFailureMemory, now: Date
    ) -> LiveAddress {
        guard toAirPlay, let hls = hlsAddress(for: channel, offersHLS: offersHLS, memory: memory, now: now) else {
            return LiveAddress(url: resolved, fallback: nil)
        }
        return LiveAddress(url: hls, fallback: StreamFallback(url: resolved, source: channel.sourceID))
    }
}

/// The address a live tune opens and the one to try if it does not start.
/// Both hold the login: never log or store them.
public struct LiveAddress: Sendable, Equatable {
    public var url: URL
    public var fallback: StreamFallback?

    public init(url: URL, fallback: StreamFallback?) {
        self.url = url
        self.fallback = fallback
    }
}
