import Foundation

/// One person using Antenna (profiles capability). Profiles share the sources and
/// logins; each keeps its own favorites, history and hidden groups.
public struct Profile: Sendable, Hashable, Identifiable {
    /// The first profile's fixed id. Records with no profile id are Main's.
    public static let mainID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xA1, 0xA1))
    public static let mainName = "Main"
    /// The eight identity colors, in order, as RGB hex.
    public static let colors: [UInt32] = [0x5BB8FF, 0xFFB454, 0x4FD1C5, 0xC084FC, 0xF87171, 0xA3E635, 0xF472B6, 0x94A3B8]

    public var id: UUID
    public var name: String
    /// An index into `colors`; out of range reads as 0.
    public var colorIndex: Int
    public var sortOrder: Int
    public var createdAt: Date

    public init(id: UUID, name: String, colorIndex: Int, sortOrder: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// The implicit first profile before any profile is stored.
    public static func main(createdAt: Date = .distantPast) -> Profile {
        Profile(id: mainID, name: mainName, colorIndex: 0, sortOrder: 0, createdAt: createdAt)
    }

    /// The name's first letter or digit, uppercased; "?" without one.
    public var initial: String {
        name.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "?"
    }

    /// `colors[colorIndex]`, or the first color when the index is out of range.
    public var color: UInt32 {
        Profile.colors.indices.contains(colorIndex) ? Profile.colors[colorIndex] : Profile.colors[0]
    }
}

/// The user's profiles as every screen sees them
/// (profiles/who-s-watching-at-launch): duplicates resolved, in order, with
/// Main standing in while nothing is stored.
public struct ProfileList: Sendable, Equatable {
    public static let limit = 8
    public static let nameLimit = 30

    /// In the user's order, never empty.
    public let profiles: [Profile]
    /// True while no profile is stored and Main stands in.
    public let isImplicit: Bool

    /// Builds the list from the stored profiles. Two records with one id
    /// keep the earliest `createdAt` (profiles/profiles-sync-between-devices);
    /// order is `sortOrder`, then `createdAt`, then id.
    public init(stored: [Profile]) {
        let kept = Self.winners(stored)
        isImplicit = kept.isEmpty
        profiles = kept.isEmpty ? [.main()] : kept
    }

    /// The indices in `stored` of records that lose to another record with
    /// the same id, to delete. An exact copy loses to the first of its kind.
    public static func duplicates(in stored: [Profile]) -> [Int] {
        let kept = Set(winnerIndices(stored))
        return stored.indices.filter { !kept.contains($0) }
    }

    /// True with two or more profiles: the "Who's watching?" screen shows at launch.
    public var showsPicker: Bool { profiles.count >= 2 }

    public var canAdd: Bool { profiles.count < Self.limit }

    /// The trimmed name when it has 1 to 30 characters, else nil.
    public static func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...nameLimit).contains(name.count) ? name : nil
    }

    /// The profiles to store to add `name` (profiles/adding-a-profile): Main
    /// first while it is not stored yet, then the new profile after the
    /// last. Nil for an invalid name or when eight profiles exist.
    public func adding(name raw: String, colorIndex: Int, id: UUID = UUID(), now: Date = .now) -> [Profile]? {
        guard canAdd, let name = Self.validName(raw) else { return nil }
        let next = (profiles.map(\.sortOrder).max() ?? 0) + 1
        let added = Profile(id: id, name: name, colorIndex: colorIndex, sortOrder: next, createdAt: now)
        return isImplicit ? [.main(createdAt: now), added] : [added]
    }

    /// Whether `id` can be deleted (profiles/editing-and-deleting-a-profile):
    /// it exists and is not the last profile.
    public func canDelete(_ id: UUID) -> Bool {
        profiles.count > 1 && profiles.contains { $0.id == id }
    }

    /// The profile a device opens on, from the id it last stored: the only
    /// profile when there is one, the stored one while it exists, else nil,
    /// meaning the "Who's watching?" screen has to ask.
    public func current(stored id: UUID?) -> Profile? {
        guard showsPicker else { return profiles.first }
        return profiles.first { $0.id == id }
    }

    /// The profile a running device stays on after the profiles changed
    /// (profiles/editing-and-deleting-a-profile): `current` while it
    /// exists, the only profile when one is left, else nil, meaning "Who's
    /// watching?" has to ask again.
    public func staying(on current: UUID) -> UUID? {
        if profiles.contains(where: { $0.id == current }) { return current }
        return showsPicker ? nil : profiles[0].id
    }

    /// The profile the picker focuses first: the device's last one, else the first.
    public func focusedOnPicker(stored id: UUID?) -> Profile {
        profiles.first { $0.id == id } ?? profiles[0]
    }

    /// The id per-person records store for `profile`: nil for Main.
    public static func storedID(for profile: UUID) -> UUID? {
        profile == Profile.mainID ? nil : profile
    }

    /// True when a record's profile id belongs to `profile`.
    public static func owns(_ profile: UUID, recordProfile: UUID?) -> Bool {
        (recordProfile ?? Profile.mainID) == profile
    }

    /// For each id, the index of its earliest record, the first on a tie.
    private static func winnerIndices(_ stored: [Profile]) -> [Int] {
        var earliest: [UUID: Int] = [:]
        for index in stored.indices {
            if let kept = earliest[stored[index].id], stored[kept].createdAt <= stored[index].createdAt { continue }
            earliest[stored[index].id] = index
        }
        return Array(earliest.values)
    }

    private static func winners(_ stored: [Profile]) -> [Profile] {
        winnerIndices(stored).map { stored[$0] }.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
