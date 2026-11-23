#if os(tvOS)
    import AntennaCore
    import Foundation

    extension ShellModel {
        /// The saved channel with its logins put back, when it is `key`'s and
        /// its source has a login here. Its source's User-Agent goes with it
        /// (session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads).
        func launchChannel(_ key: LastChannelKey) -> Channel? {
            guard let saved = savedLaunch, saved.key == key, let source = descriptors[key.sourceID], dependencies.hasLogin(source),
                let logins = dependencies.launchLogins?(source), let channel = saved.channel(logins: logins)
            else { return nil }
            StreamHeaderBook.shared.register(source.headers, server: channel.streamURL, source: source.id)
            return channel
        }

        /// `source`'s list arrived: the channel started at launch follows it.
        /// The same stream plays on with the list's details, a changed link or
        /// a failed start tunes again, and a channel the list lacks gives way
        /// to the first channel of the first source to load
        /// (session-restore-and-recently-watched/the-fresh-list-decides).
        func reconcileLaunch(_ source: UUID, fresh: [Channel]) {
            guard let started = launchStarted, started.sourceID == source else { return }
            launchStarted = nil
            guard let tuned, started.matches(tuned) else { return }
            guard let channel = fresh.first(where: started.matches) else {
                dropLaunchChannel()
                considerTune()
                if self.tuned == nil { Task { await engine.stop() } }
                return
            }
            let logins = descriptors[source].flatMap { dependencies.launchLogins?($0) } ?? []
            if player.failure == nil, SavedChannel.sameStream(tuned, channel, logins: logins) {
                adopt(channel)
            } else {
                tune(channel)
            }
        }

        /// Saves `channel`, the new last channel, for the next launch, or
        /// clears what was saved when it cannot be saved.
        func saveForLaunch(_ channel: Channel) {
            guard let launchLogins = dependencies.launchLogins else { return }
            let logins = channel.sourceID.flatMap { descriptors[$0] }.flatMap(launchLogins)
            session.store.saveLaunch(channel, logins: logins)
        }
    }
#endif
