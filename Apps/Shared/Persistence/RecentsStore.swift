import AntennaCore
import Foundation

/// The recents, the session and the last channel of one profile on this
/// device, in `UserDefaults` and never synced
/// (session-restore-and-recently-watched capability). Keys are
/// `recents.list`, `recents.session` and `shell.lastChannel`, each with
/// `.<profile id>` appended for every profile but Main. A value that cannot
/// be read counts as absent.
struct RecentsStore: Sendable {
    static let lastChannelKey = "shell.lastChannel"
    static let listKey = "recents.list"
    static let sessionKey = "recents.session"
    static let bases = [lastChannelKey, listKey, sessionKey]

    nonisolated(unsafe) let defaults: UserDefaults
    let profile: UUID

    init(defaults: UserDefaults = .standard, profile: UUID = Profile.mainID) {
        self.defaults = defaults
        self.profile = profile
    }

    /// A store outside the app's own values, for tests and previews.
    static var scratch: RecentsStore {
        RecentsStore(defaults: UserDefaults(suiteName: "antenna.scratch") ?? .standard)
    }

    // MARK: Last channel

    /// Nil when nothing is stored or the stored value cannot be read.
    func read() -> LastChannelKey? {
        guard let data = defaults.data(forKey: key(Self.lastChannelKey)),
            let stored = try? JSONDecoder().decode(LastChannelKey.self, from: data),
            LastChannelKey.canStore(stored.channelID)
        else { return nil }
        return stored
    }

    /// Stores `channel` as the one to play at launch. An id holding a stream
    /// link is not stored.
    func write(_ channel: LastChannelKey) {
        guard LastChannelKey.canStore(channel.channelID), let data = try? JSONEncoder().encode(channel) else { return }
        defaults.set(data, forKey: key(Self.lastChannelKey))
    }

    // MARK: Recents

    var recents: RecentChannels {
        RecentChannels(data: defaults.data(forKey: key(Self.listKey)))
    }

    /// Puts `channel` on top of the recents and returns the new list.
    @discardableResult
    func record(_ channel: LastChannelKey) -> RecentChannels {
        var list = recents
        list.record(channel)
        defaults.set(list.data, forKey: key(Self.listKey))
        return list
    }

    // MARK: Session

    var session: LiveSession {
        LiveSession(data: defaults.data(forKey: key(Self.sessionKey)))
    }

    func write(_ session: LiveSession) {
        defaults.set(session.data, forKey: key(Self.sessionKey))
    }

    // MARK: Deleted sources

    /// Removes `source`'s channels from the recents, the session group and
    /// the last channel of every profile on this device
    /// (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
    static func remove(source: UUID, from defaults: UserDefaults = .standard) {
        for profile in profiles(in: defaults) {
            RecentsStore(defaults: defaults, profile: profile).remove(source: source)
        }
    }

    private func remove(source: UUID) {
        var list = recents
        list.remove(source: source)
        defaults.set(list.data, forKey: key(Self.listKey))
        var session = self.session
        session.remove(source: source)
        write(session)
        if read()?.sourceID == source { defaults.removeObject(forKey: key(Self.lastChannelKey)) }
    }

    /// Main, and every profile with a value under one of the keys.
    private static func profiles(in defaults: UserDefaults) -> Set<UUID> {
        var found: Set<UUID> = [Profile.mainID]
        for key in defaults.dictionaryRepresentation().keys {
            guard let base = bases.first(where: { key.hasPrefix($0 + ".") }) else { continue }
            if let id = UUID(uuidString: String(key.dropFirst(base.count + 1))) { found.insert(id) }
        }
        return found
    }

    private func key(_ base: String) -> String {
        ProfileKeys.key(base, for: profile)
    }
}
