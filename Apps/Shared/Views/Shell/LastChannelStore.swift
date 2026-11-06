#if os(tvOS)
    import AntennaCore
    import Foundation

    /// The channel last watched on this Apple TV, by source and channel id.
    /// Never carries a stream link (ADR-0003).
    struct LastChannelKey: Codable, Equatable, Sendable {
        var sourceID: UUID
        var channelID: String

        /// Nil when the channel has no source, or when its id contains `://`.
        /// M3U ids embed the stream link, so those channels are not stored
        /// until the 0001 follow-up that spec 0028 names.
        init?(_ channel: Channel) {
            guard let sourceID = channel.sourceID, !channel.id.contains("://") else { return nil }
            self.sourceID = sourceID
            self.channelID = channel.id
        }

        init(sourceID: UUID, channelID: String) {
            self.sourceID = sourceID
            self.channelID = channelID
        }

        func matches(_ channel: Channel) -> Bool {
            channel.sourceID == sourceID && channel.id == channelID
        }
    }

    /// Reads and writes `shell.lastChannel` in `UserDefaults`, on this device
    /// only and never synced (ADR-0009).
    struct LastChannelStore {
        static let defaultsKey = "shell.lastChannel"
        private let defaults: UserDefaults

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }

        /// Nil when nothing is stored or the stored value cannot be read.
        func read() -> LastChannelKey? {
            guard let data = defaults.data(forKey: Self.defaultsKey) else { return nil }
            return try? JSONDecoder().decode(LastChannelKey.self, from: data)
        }

        func write(_ key: LastChannelKey) {
            guard let data = try? JSONEncoder().encode(key) else { return }
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
#endif
