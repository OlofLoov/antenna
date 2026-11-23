import AntennaCore
import Foundation

/// The channel one profile starts at launch on this device, one file at
/// `Caches/launch/channel-<profile id>.json`, never synced or backed up
/// (session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login).
/// The file holds no login. A file that is missing or cannot be read counts
/// as nothing saved, and the launch waits for the list as before.
struct LaunchChannelStore: Sendable {
    let directory: URL
    let profile: UUID

    static let appDirectory =
        (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        .appending(path: "launch", directoryHint: .isDirectory)

    init(directory: URL = Self.appDirectory, profile: UUID = Profile.mainID) {
        self.directory = directory
        self.profile = profile
    }

    /// A folder outside the app's own for tests and previews, emptied once
    /// per launch.
    static let scratchDirectory: URL = {
        let directory = FileManager.default.temporaryDirectory.appending(path: "antenna-scratch-launch", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        return directory
    }()

    var file: URL {
        directory.appending(path: "channel-\(profile.uuidString).json")
    }

    func read() -> SavedChannel? {
        SavedChannel(data: try? Data(contentsOf: file))
    }

    /// Saves `channel`, or deletes the file when it is nil.
    func write(_ channel: SavedChannel?) {
        guard let data = channel?.data else {
            try? FileManager.default.removeItem(at: file)
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    /// Deletes the file when its channel belongs to `source`.
    func remove(source: UUID) {
        if read()?.sourceID == source { write(nil) }
    }

    /// Deletes the files of profiles not in `profiles`.
    static func prune(keeping profiles: [UUID], in directory: URL = appDirectory) {
        let kept = Set(profiles.map { "channel-\($0.uuidString).json" })
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !kept.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// The logins a source's links carry, the same answer when a channel is
/// saved for launch and when it is tuned at launch
/// (session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login).
struct LaunchLogins: Sendable {
    var credentials: any CredentialStoring = CredentialStore()

    /// Nil for a source whose channels are not saved for launch: a Stalker
    /// portal, a Jellyfin server, or a source whose Keychain item is missing
    /// or cannot be read.
    func logins(for source: SourceDescriptor) -> [SavedChannel.Login]? {
        switch source.kind {
        case .xtream:
            guard let key = source.credentialKey, let login = try? credentials.load(for: key) else { return nil }
            return [SavedChannel.Login(username: login.username, password: login.password)]
        case .m3u:
            return SavedChannel.Login(playlistLink: source.url).map { [$0] } ?? []
        case .m3uFile:
            guard let key = source.credentialKey else { return [] }
            guard let logins = try? StreamLoginStore(credentials: credentials).load(for: key) else { return nil }
            return logins.map { SavedChannel.Login(username: $0.username, password: $0.password) }
        case .channelsDVR:
            guard let key = source.credentialKey else { return [] }
            guard let login = try? credentials.load(for: key) else { return nil }
            return [SavedChannel.Login(username: login.username, password: login.password)]
        case .stalker, .jellyfin:
            return nil
        }
    }
}
