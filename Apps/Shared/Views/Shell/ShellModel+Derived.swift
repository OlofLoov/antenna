#if os(tvOS)
    import AntennaCore
    import Foundation

    extension ShellModel {
        /// The bar shows when raised by Menu and always on Movies, Series and Search.
        var barVisible: Bool { barRaised || tab.isContent }

        /// The picture or guide is dimmed under the raised bar.
        var dimmed: Bool { barRaised && !tab.isContent }

        /// The tabs the bar lists: Movies and Series only with an Xtream source (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
        var tabs: [ShellTab] {
            ShellTab.allCases.filter { offersMovies || ($0 != .movies && $0 != .series) }
        }

        /// The navigator other screens use; `ShellView` provides it.
        var navigator: ShellNavigator { .forwarding(to: self) }

        /// The names the player's messages use for `channel`.
        func subject(for channel: Channel) -> PlayerSubject {
            PlayerSubject(
                channel: channel, source: sources.first { $0.id == channel.sourceID }?.name ?? PlayerModel.unnamedSource,
                number: channel.number)
        }

        /// Loads `channel` without telling the player or the info bar it
        /// changed, so Try again counts as no channel change.
        func load(_ channel: Channel) {
            Task {
                do {
                    try await engine.load(channel.streamURL, options: languages.options(for: channel))
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.info("tune failed, the stored channel is kept")
                    if let failure = error as? PlaybackFailure, tuned == channel { player.loadFailed(failure) }
                    return
                }
                guard tuned == channel else { return }
                // A pause from the timer while the load ran stands.
                if !pausedByShell { await engine.play() }
                if let key = LastChannelKey(channel) { dependencies.lastChannel.write(key) }
            }
        }

        /// Tunes `channel` from the picker and shows Live full screen.
        func pick(_ channel: Channel) async {
            if channel != tuned { tune(channel) }
            await showLive()
        }
    }
#endif
