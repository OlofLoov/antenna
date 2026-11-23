#if os(tvOS)
    import AntennaCore
    import Foundation

    extension ShellModel {
        /// When the profile's last watch on this Apple TV was a movie or an
        /// episode, the launch tune waits for its page, at most until the
        /// launch deadline. A held shelf link wins
        /// (tvos-shell/back-to-the-last-channel-on-launch).
        func reopenLastTitle() {
            guard shelfItem == nil, let title = dependencies.recents.readLastWatched()?.title else { return }
            launchTitle.wait(for: title)
            launchTitle.start(sleep: dependencies.sleep)
        }

        /// The page of the title watched last opened over `tab`: once the tab
        /// holds the channel, the launch tune goes ahead behind it.
        func launchTitleOpened(in tab: ShellTab) async {
            _ = await select(tab)
            launchTitle.opened()
            considerTune()
        }

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
