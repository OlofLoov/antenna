import AntennaCore
import Foundation

/// The sources whose HLS did not start on this device when a channel went
/// to AirPlay, as JSON under `player.hlsFailures` in `UserDefaults`, never
/// synced (playback-engine/a-source-whose-hls-failed-cannot-airplay). It
/// holds source ids and dates, no address and no login.
struct HLSFailureStore: Sendable {
    static let key = "player.hlsFailures"

    /// The app's store. UI test launches get one emptied at launch, so one
    /// test's failure never stops the next test's AirPlay.
    static let shared: HLSFailureStore = {
        #if DEBUG
            if let testing = UITestingLive.failureStore() { return testing }
        #endif
        return HLSFailureStore()
    }()

    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var memory: HLSFailureMemory {
        guard let data = defaults.data(forKey: Self.key) else { return HLSFailureMemory() }
        return (try? JSONDecoder().decode(HLSFailureMemory.self, from: data)) ?? HLSFailureMemory()
    }

    /// Notes that `source`'s HLS failed at `date`.
    func record(_ source: UUID, at date: Date = .now) {
        var memory = self.memory
        memory.record(source, at: date)
        if let data = try? JSONEncoder().encode(memory) { defaults.set(data, forKey: Self.key) }
    }

    /// The HLS link `channel` would go to AirPlay on, nil when it has none
    /// or its source cannot send one (playback-engine/a-channel-goes-to-airplay-as-hls).
    func hlsAddress(for channel: Channel, offers: XtreamHLSOffers = .shared, now: Date = .now) -> URL? {
        let offersHLS = channel.sourceID.map(offers.offersHLS) ?? false
        return AirPlayHLS.hlsAddress(for: channel, offersHLS: offersHLS, memory: memory, now: now)
    }
}
