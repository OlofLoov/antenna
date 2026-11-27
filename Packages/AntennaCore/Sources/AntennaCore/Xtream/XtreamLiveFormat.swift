import Foundation
import Synchronization

/// Whether an Xtream panel's live channels can play as HLS, and their HLS
/// links (xtream-live-source/the-account-says-whether-hls-is-offered).
///
/// Live channels play as MPEG-TS on the demuxer, which keeps the live rewind
/// buffer but cannot send video to AirPlay. Their HLS link plays on Apple's
/// player, which can, and is used only while the channel goes to AirPlay
/// (playback-engine/a-channel-goes-to-airplay-as-hls).
public enum XtreamLiveFormat {
    /// True when `allowedOutputFormats` lists `m3u8`, or when the panel
    /// sends no list or an empty one. False when it lists formats without
    /// `m3u8`. Entries are compared without case and surrounding spaces.
    public static func offersHLS(allowedOutputFormats: [String]?) -> Bool {
        let formats = (allowedOutputFormats ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return formats.isEmpty || formats.contains(XtreamClient.StreamContainer.m3u8.rawValue)
    }

    /// The HLS link of an Xtream live channel whose link is MPEG-TS, the same
    /// address with `.m3u8` in place of `.ts` and the login left encoded as
    /// it was. Nil for any other channel, M3U, movies and episodes included.
    public static func hlsAddress(for channel: Channel) -> URL? {
        let transportStream = "." + XtreamClient.StreamContainer.ts.rawValue
        guard let id = XtreamTitleID(parsing: channel.id), id.kind == .live,
            var components = URLComponents(url: channel.streamURL, resolvingAgainstBaseURL: false),
            components.percentEncodedPath.lowercased().hasSuffix(transportStream)
        else { return nil }
        components.percentEncodedPath =
            components.percentEncodedPath.dropLast(transportStream.count) + "." + XtreamClient.StreamContainer.m3u8.rawValue
        return components.url
    }
}

/// What `XtreamClient.liveLoad()` brings back.
public struct XtreamLiveLoad: Sendable {
    /// Every live channel, linked as MPEG-TS.
    public var channels: [Channel]
    /// The panel's time zone name, nil when the account call failed or named none.
    public var timeZoneName: String?
    /// True when the account lets its channels play as HLS.
    public var offersHLS: Bool

    public init(channels: [Channel], timeZoneName: String?, offersHLS: Bool) {
        self.channels = channels
        self.timeZoneName = timeZoneName
        self.offersHLS = offersHLS
    }
}

/// Which loaded Xtream sources offer HLS, by source id, as their last load
/// said. A source not loaded yet in this launch reads as not offering it.
public final class XtreamHLSOffers: Sendable {
    public static let shared = XtreamHLSOffers()

    private let offers = Mutex<[UUID: Bool]>([:])

    public init() {}

    public func loaded(_ source: UUID, offersHLS: Bool) {
        offers.withLock { $0[source] = offersHLS }
    }

    public func offersHLS(_ source: UUID) -> Bool {
        offers.withLock { $0[source] ?? false }
    }
}
