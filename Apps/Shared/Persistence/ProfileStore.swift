import AntennaCore
import Foundation
import SwiftData
import SwiftUI

/// Reads and writes profiles (profiles capability). Every write resolves duplicate
/// records first and deletes the losers in the same save.
@MainActor
enum ProfileStore {
    /// The profiles in `records`, as `ProfileList` resolves them.
    static func list(_ records: [ProfileRecord]) -> ProfileList {
        ProfileList(stored: records.map(\.profile))
    }

    /// Adds a profile named `name`; adding the second also stores Main.
    /// Returns the new profile, or nil for an invalid name or a full list.
    @discardableResult
    static func add(name: String, colorIndex: Int, in context: ModelContext) -> Profile? {
        let records = fetch(context)
        guard let added = list(records).adding(name: name, colorIndex: colorIndex) else { return nil }
        added.forEach { context.insert(ProfileRecord($0)) }
        save(context, resolving: records)
        return added.last
    }

    /// Renames and recolors `id`. Main gets its record when it had none.
    @discardableResult
    static func edit(_ id: UUID, name: String, colorIndex: Int, in context: ModelContext) -> Bool {
        guard let name = ProfileList.validName(name) else { return false }
        let records = fetch(context)
        if let record = records.first(where: { $0.id == id }) {
            record.name = name
            record.colorIndex = colorIndex
        } else if id == Profile.mainID {
            context.insert(ProfileRecord(Profile(id: id, name: name, colorIndex: colorIndex, sortOrder: 0, createdAt: .now)))
        } else {
            return false
        }
        save(context, resolving: records)
        return true
    }

    /// Deletes `id` and its favorites everywhere
    /// (profiles/editing-and-deleting-a-profile). The last profile stays.
    @discardableResult
    static func delete(_ id: UUID, in context: ModelContext) -> Bool {
        let records = fetch(context)
        guard list(records).canDelete(id) else { return false }
        records.filter { $0.id == id }.forEach(context.delete)
        let favorites = (try? context.fetch(FetchDescriptor<FavoriteRecord>())) ?? []
        favorites.filter { ProfileList.owns(id, recordProfile: $0.profileID) }.forEach(context.delete)
        save(context, resolving: records.filter { $0.id != id })
        return true
    }

    private static func fetch(_ context: ModelContext) -> [ProfileRecord] {
        (try? context.fetch(FetchDescriptor<ProfileRecord>())) ?? []
    }

    private static func save(_ context: ModelContext, resolving records: [ProfileRecord]) {
        ProfileList.duplicates(in: records.map(\.profile)).forEach { context.delete(records[$0]) }
        try? context.save()
    }
}

/// The profile this device is on, kept in `UserDefaults` under
/// `profiles.current`, never synced. A value that fails to decode reads as absent.
struct CurrentProfileStore: Sendable {
    static let key = "profiles.current"

    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> UUID? {
        defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:))
    }

    func write(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Self.key)
    }
}

/// Per-device values kept per profile (profiles/what-each-profile-keeps): Main
/// keeps each key as it is, other profiles add `.<profile id>`.
enum ProfileKeys {
    /// The keys that hold one value per profile.
    static let bases = ["shell.lastChannel", "player.languages", "recents.list", "recents.session"]

    static func key(_ base: String, for profile: UUID) -> String {
        profile == Profile.mainID ? base : "\(base).\(profile.uuidString)"
    }

    /// Removes the values of profiles that no longer exist.
    static func prune(_ defaults: UserDefaults, keeping profiles: [UUID]) {
        let kept = Set(profiles.map(\.uuidString))
        for key in defaults.dictionaryRepresentation().keys {
            guard let base = bases.first(where: { key.hasPrefix($0 + ".") }) else { continue }
            let suffix = String(key.dropFirst(base.count + 1))
            if UUID(uuidString: suffix) != nil, !kept.contains(suffix) { defaults.removeObject(forKey: key) }
        }
    }
}

extension EnvironmentValues {
    /// The profile the screens show: its favorites, last channel and picks.
    @Entry var currentProfile: UUID = Profile.mainID
}
