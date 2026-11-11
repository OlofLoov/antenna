#if DEBUG
    import AntennaCore
    import Foundation

    /// Recents, the session and the last channel for UI tests
    /// (session-restore-and-recently-watched capability), compiled into Debug builds only.
    ///
    /// Each launch starts with empty values in its own defaults suite, unless
    /// `-ui-testing-keep-session` is passed, so a test can quit and relaunch
    /// the app and see what it restores. `UITESTING_RECENTS` seeds the
    /// recents with channel ids, newest first, separated by commas.
    /// `UITESTING_WATCH_SECONDS` shortens the ten-second count. When
    /// `UITESTING_LAST_CHANNEL_FILE` names a file, each last-channel write
    /// puts the channel id in it, and `UITESTING_RECENTS_FILE` gets the
    /// recents' ids one per line, since a UI test cannot read the app's defaults.
    enum UITestingRecents {
        static let keepArgument = "-ui-testing-keep-session"
        static let recentsVariable = "UITESTING_RECENTS"
        static let watchVariable = "UITESTING_WATCH_SECONDS"
        static let mirrorVariable = "UITESTING_LAST_CHANNEL_FILE"
        static let recentsMirrorVariable = "UITESTING_RECENTS_FILE"
        static let suite = "ui-testing-recents"

        /// The store for this launch. `source` maps a seeded id to its source.
        static func store(source: (String) -> UUID) -> RecentsStore {
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            let environment = ProcessInfo.processInfo.environment
            guard !ProcessInfo.processInfo.arguments.contains(keepArgument) else { return RecentsStore(defaults: defaults) }
            defaults.removePersistentDomain(forName: suite)
            let store = RecentsStore(defaults: defaults)
            let seeded = (environment[recentsVariable] ?? "").split(separator: ",").map(String.init)
            for id in seeded.reversed() {
                store.record(LastChannelKey(sourceID: source(id), channelID: "fixture/\(id)"))
            }
            return store
        }

        /// Sleeps as asked, except the ten-second count, which takes
        /// `UITESTING_WATCH_SECONDS`. Unset, nothing counts as watched, so
        /// other screens' tests keep empty recents and their group positions.
        static var sleep: @MainActor (Duration) async throws -> Void {
            let watch = ProcessInfo.processInfo.environment[watchVariable].flatMap(Double.init).map { Duration.seconds($0) }
            return { duration in
                guard duration == SessionTracker.watchedAfter else { return try await Task.sleep(for: duration) }
                try await Task.sleep(for: watch ?? .seconds(86_400))
            }
        }

        /// Writes `channel`'s id to the mirror file, when the test asked for one.
        static func mirror(_ channel: LastChannelKey) {
            guard let path = ProcessInfo.processInfo.environment[mirrorVariable] else { return }
            try? Data(channel.channelID.utf8).write(to: URL(fileURLWithPath: path))
        }

        /// Writes the recents' ids to their mirror file, when the test asked for one.
        static func mirror(_ list: RecentChannels) {
            guard let path = ProcessInfo.processInfo.environment[recentsMirrorVariable] else { return }
            try? Data(list.entries.map(\.channelID).joined(separator: "\n").utf8).write(to: URL(fileURLWithPath: path))
        }
    }
#endif
