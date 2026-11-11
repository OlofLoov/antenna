import Foundation

/// The Mac's player volume on this device
/// (player-controls-and-playback-errors/the-mac-remembers-its-volume).
/// `player.volume` holds the level as last set, 0 while muted, and
/// `player.volume.beforeMute` the level mute hid. Each is a JSON number;
/// one that fails to decode reads as absent. Not synced.
struct PlayerVolumeStore {
    static let volumeKey = "player.volume"
    static let beforeMuteKey = "player.volume.beforeMute"
    /// How far Command-Up and Command-Down move the level.
    static let step: Float = 0.1

    var defaults: UserDefaults = .standard

    /// The store on a Mac; nil on iPhone, iPad and Apple TV, where the
    /// device's own volume buttons set the level.
    static var current: PlayerVolumeStore? {
        #if os(macOS)
            PlayerVolumeStore()
        #else
            nil
        #endif
    }

    /// The level to start with: the level before mute when the app quit
    /// muted, else the last level, else full.
    func restored() -> Float {
        let level = read(Self.beforeMuteKey) ?? read(Self.volumeKey) ?? 1
        return min(1, max(0, level))
    }

    /// Keeps `volume`, and `beforeMute` while muted.
    func write(volume: Float, muted: Bool) {
        store(muted ? 0 : volume, for: Self.volumeKey)
        if muted {
            store(volume, for: Self.beforeMuteKey)
        } else {
            defaults.removeObject(forKey: Self.beforeMuteKey)
        }
    }

    private func read(_ key: String) -> Float? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Float.self, from: data)
    }

    private func store(_ value: Float, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
