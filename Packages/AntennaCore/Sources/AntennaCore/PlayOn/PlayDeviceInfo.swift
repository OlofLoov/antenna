import Foundation

/// What one device running Antuna says about itself in the account's
/// private iCloud database (play-on-apple-tv/apple-tvs-on-the-same-icloud-account).
/// Only public data: a name, a kind and a key-agreement public key.
public struct PlayDeviceInfo: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case tv, phone, pad, mac
    }

    /// The format this build writes.
    public static let currentVersion = 1
    /// A device that has not opened Antuna for this long is not listed and is swept.
    public static let forgetAfter: TimeInterval = 60 * 86_400

    /// The device's own random id, made on its first launch.
    public var id: UUID
    public var kind: Kind
    /// The name the device gives itself, as "Living Room".
    public var name: String
    /// The P-256 key-agreement public key, X9.63, made fresh each launch.
    public var publicKey: Data
    /// When `publicKey` was made, in whole seconds.
    public var keyDate: Date
    public var lastSeen: Date
    /// When the record was first saved; orders TVs that share a name.
    public var created: Date?
    public var version: Int

    public init(
        id: UUID, kind: Kind, name: String, publicKey: Data, keyDate: Date, lastSeen: Date, created: Date? = nil,
        version: Int = Self.currentVersion
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.publicKey = publicKey
        self.keyDate = keyDate
        self.lastSeen = lastSeen
        self.created = created
        self.version = version
    }

    /// True once the device has not been seen for 60 days.
    public func isForgotten(at now: Date) -> Bool {
        now.timeIntervalSince(lastSeen) >= Self.forgetAfter
    }

    /// True when the device should write its record again on returning to
    /// the foreground: a new key, or a `lastSeen` older than a day.
    public func needsRefresh(keyDate current: Date, now: Date) -> Bool {
        keyDate != current || now.timeIntervalSince(lastSeen) >= 86_400
    }
}

/// An Apple TV as the Play on menu lists it.
public struct PlayTV: Sendable, Hashable, Identifiable {
    public var device: PlayDeviceInfo
    /// The name the menu shows, numbered when another TV shares it.
    public var name: String

    public var id: UUID { device.id }

    public init(device: PlayDeviceInfo, name: String) {
        self.device = device
        self.name = name
    }

    /// The Apple TVs on the account worth listing: kind `tv`, seen in the
    /// last 60 days. TVs that share a name are told apart by a number after
    /// it, "Apple TV", "Apple TV 2", in the order their records were made
    /// (play-on-apple-tv/apple-tvs-on-the-same-icloud-account).
    public static func listed(_ devices: [PlayDeviceInfo], now: Date, locale: Locale = .autoupdatingCurrent) -> [PlayTV] {
        let tvs = devices.filter { $0.kind == .tv && !$0.isForgotten(at: now) }
            .sorted { ($0.created ?? .distantFuture, $0.id.uuidString) < ($1.created ?? .distantFuture, $1.id.uuidString) }
        var seen: [String: Int] = [:]
        return tvs.map { device in
            let base = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = base.isEmpty ? "Apple TV" : base
            let count = (seen[name.lowercased()] ?? 0) + 1
            seen[name.lowercased()] = count
            return PlayTV(device: device, name: count == 1 ? name : "\(name) \(count.formatted(.number.locale(locale)))")
        }
    }

    /// `tvs` in the menu's order: those ready now first, then by name.
    public static func ordered(_ tvs: [PlayTV], ready: Set<UUID>, locale: Locale = .autoupdatingCurrent) -> [PlayTV] {
        tvs.sorted { first, second in
            let firstReady = ready.contains(first.id)
            let secondReady = ready.contains(second.id)
            if firstReady != secondReady { return firstReady }
            return first.name.compare(second.name, options: [.caseInsensitive, .numeric], locale: locale) == .orderedAscending
        }
    }
}
