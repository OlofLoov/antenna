import AntennaCore
import Foundation

/// The sound and subtitle languages picked on each channel on this device,
/// as JSON under `player.languages` in `UserDefaults`, never synced
/// (playback-engine/audio-and-subtitle-languages). Keys are source and
/// channel ids; a channel whose id embeds its stream link is not kept.
struct ChannelLanguageStore: Sendable {
    static let key = "player.languages"

    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The key for `channel`, nil when it has no source or its id holds a link.
    static func key(for channel: Channel) -> String? {
        guard let source = channel.sourceID, !channel.id.contains("://") else { return nil }
        return "\(source.uuidString)/\(channel.id)"
    }

    var memory: LanguageMemory {
        guard let data = defaults.data(forKey: Self.key) else { return LanguageMemory() }
        return (try? JSONDecoder().decode(LanguageMemory.self, from: data)) ?? LanguageMemory()
    }

    func pick(for channel: Channel) -> LanguagePick? {
        Self.key(for: channel).flatMap(memory.pick)
    }

    func remember(_ pick: LanguagePick, for channel: Channel) {
        guard let key = Self.key(for: channel) else { return }
        var memory = self.memory
        memory.remember(pick, for: key)
        if let data = try? JSONEncoder().encode(memory) { defaults.set(data, forKey: Self.key) }
    }
}

/// Starts each channel with the languages last picked on it and keeps the
/// user's picks. A selection that changes after a channel's tracks first
/// arrive is a pick; the starting choice is not.
@MainActor
final class ChannelLanguages {
    private let store: ChannelLanguageStore
    private var channel: Channel?
    private var initial: TrackList?
    private var watch: Task<Void, Never>?

    /// With `engine`, starts following its tracks at once, as `watch(_:)` does.
    init(store: ChannelLanguageStore = ChannelLanguageStore(), watching engine: (any PlaybackEngine)? = nil) {
        self.store = store
        if let engine { watch(engine) }
    }

    /// The options to load `channel` with: the device's languages first for
    /// sound, and the pick last made on the channel.
    func options(for channel: Channel) -> PlaybackOptions {
        self.channel = channel
        initial = nil
        return PlaybackOptions(preferredAudioLanguages: Locale.preferredLanguages, remembered: store.pick(for: channel))
    }

    /// Follows `engine`'s tracks and keeps each pick for the channel last
    /// passed to `options(for:)`.
    func watch(_ engine: any PlaybackEngine) {
        watch?.cancel()
        watch = Task { [weak self] in
            for await tracks in await engine.tracks() {
                self?.tracksChanged(tracks)
            }
        }
    }

    func stopWatching() {
        watch?.cancel()
        watch = nil
    }

    private func tracksChanged(_ tracks: TrackList) {
        guard !tracks.audio.isEmpty || !tracks.subtitles.isEmpty else {
            initial = nil
            return
        }
        guard let first = initial else {
            initial = tracks
            return
        }
        guard let channel, tracks.selectedAudio != first.selectedAudio || tracks.selectedSubtitle != first.selectedSubtitle else { return }
        initial = tracks
        store.remember(LanguagePick(tracks), for: channel)
    }
}
