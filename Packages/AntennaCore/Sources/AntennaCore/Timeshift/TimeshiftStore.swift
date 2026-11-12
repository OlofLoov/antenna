import Foundation

/// The folder the buffers live in, one session folder per tuned channel
/// (timeshift-catch-up-and-start-over/changing-channel-starts-fresh).
///
/// Session folders are named by a new UUID, never by the channel or its
/// address, and are excluded from backup. Retiring one renames it at once
/// and deletes it on a background queue, so a channel change never waits
/// for the delete.
public struct TimeshiftStore: Sendable {
    public let root: URL
    private static let retiredPrefix = "retired-"

    public init(root: URL) {
        self.root = root
    }

    /// `<Caches>/se.codecrave.antenna.timeshift`.
    public static var standard: TimeshiftStore {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return TimeshiftStore(root: caches.appending(path: "se.codecrave.antenna.timeshift", directoryHint: .isDirectory))
    }

    /// Makes a new, empty session folder.
    public func makeSession() throws -> URL {
        var folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        return folder
    }

    /// Renames `session` out of the way now and deletes it in the background.
    /// `deleted` runs once it is gone; tests wait on it.
    public func retire(_ session: URL, deleted: (@Sendable () -> Void)? = nil) {
        let retired = root.appending(path: Self.retiredPrefix + UUID().uuidString, directoryHint: .isDirectory)
        let target = (try? FileManager.default.moveItem(at: session, to: retired)) != nil ? retired : session
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: target)
            deleted?()
        }
    }

    /// Deletes every folder and file left in the root, without opening any.
    /// Each is renamed out of the way before this returns and deleted in
    /// the background, so a session made right after is safe. Call once at
    /// launch, before the first session. `deleted` runs once they are gone.
    public func clearLeftovers(deleted: (@Sendable () -> Void)? = nil) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        var doomed: [URL] = []
        for name in names {
            let entry = root.appending(path: name)
            if name.hasPrefix(Self.retiredPrefix) {
                doomed.append(entry)
                continue
            }
            let retired = root.appending(path: Self.retiredPrefix + UUID().uuidString)
            doomed.append((try? FileManager.default.moveItem(at: entry, to: retired)) != nil ? retired : entry)
        }
        DispatchQueue.global(qos: .utility).async {
            for entry in doomed { try? FileManager.default.removeItem(at: entry) }
            deleted?()
        }
    }

    /// Bytes free for important use on the volume holding the root, nil when unknown.
    public func freeBytes() -> Int? {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(tvOS)
            return (try? root.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity
        #else
            let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
            if let important = values?.volumeAvailableCapacityForImportantUsage, important > 0 { return Int(important) }
            return values?.volumeAvailableCapacity
        #endif
    }
}
