import AntennaCore
import Foundation

/// The channels this device has seen, one file per source at
/// `Caches/discover/channels-<source id>.json`, never synced
/// (new-channels/what-new-remembers-stays-on-the-device). The files hold
/// hashes of channel ids and dates, no link or login. A file that is
/// missing or cannot be read counts as no memory, so the next load is the
/// source's first.
struct SeenChannelsStore: Sendable {
    let directory: URL

    /// The app's own files in the caches folder.
    static let app = SeenChannelsStore(
        directory: (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appending(path: "discover", directoryHint: .isDirectory))

    /// A folder outside the app's own for tests and previews, empty at each launch.
    static let scratch: SeenChannelsStore = {
        let store = SeenChannelsStore(
            directory: FileManager.default.temporaryDirectory.appending(path: "antenna-scratch-discover", directoryHint: .isDirectory))
        try? FileManager.default.removeItem(at: store.directory)
        return store
    }()

    #if DEBUG
        /// Set by UI tests: a channel id the source's first load in this
        /// launch counts as gained since a load the day before.
        var gained: String?
    #endif

    private func file(_ source: UUID) -> URL {
        directory.appending(path: "channels-\(source.uuidString).json")
    }

    /// What the device remembers of `source`, nil when nothing can be read.
    func read(_ source: UUID) -> SeenChannels? {
        guard let data = try? Data(contentsOf: file(source)) else { return nil }
        return try? JSONDecoder().decode(SeenChannels.self, from: data)
    }

    /// Records a load of `source` with `channelIDs` at `now` and returns the
    /// memory after it. A failed write leaves the memory in use for this run.
    func record(_ source: UUID, channelIDs: [String], now: Date = .now) -> SeenChannels {
        var previous = read(source)
        #if DEBUG
            if previous == nil, let gained, channelIDs.contains(gained) {
                previous = SeenChannels(firstLoad: channelIDs.filter { $0 != gained }, now: now.addingTimeInterval(-86_400))
            }
        #endif
        let memory = SeenChannels.recording(previous, channelIDs: channelIDs, now: now)
        if let data = try? JSONEncoder().encode(memory) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: file(source), options: .atomic)
        }
        return memory
    }

    /// Forgets `source`'s channels, when the source is deleted.
    func remove(_ source: UUID) {
        try? FileManager.default.removeItem(at: file(source))
    }
}
