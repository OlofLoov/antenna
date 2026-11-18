#if os(tvOS)
    import AntennaCore
    import Foundation

    /// The pause, then stop, behind Movies, Series and Search
    /// (tvos-shell/the-video-pauses-behind-movies-series-and-search).
    extension ShellModel {
        /// Pauses a channel that plays, loads or reconnects, at once, so no
        /// sound carries on behind the tab, and stops it 30 seconds later to
        /// free the provider's connection
        /// (tvos-shell/the-video-pauses-behind-movies-series-and-search).
        func holdBehindContent() async {
            switch await engine.state {
            case .playing, .loading, .buffering, .reconnecting:
                player.timeshift.interrupted()
                await engine.pause()
                heldByShell = .paused
            case .idle, .paused, .ended, .failed:
                break
            }
            startStopTimer()
        }

        private func startStopTimer() {
            stopTimer?.cancel()
            stopTimer = Task { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.sleep(Self.stopDelay)
                } catch {
                    return
                }
                guard !Task.isCancelled, tab.isContent, heldByShell == .paused else { return }
                heldByShell = .stopped
                await engine.stop()
            }
        }

        /// Ends the shell's hold. A paused channel plays on from where it
        /// was; one that stopped, after 30 seconds or for a movie, tunes again
        /// at live. True when it tunes again.
        func resume() async -> Bool {
            stopTimer?.cancel()
            stopTimer = nil
            guard let held = heldByShell else { return false }
            heldByShell = nil
            // A movie played meanwhile stops the paused channel too.
            let state = await engine.state
            guard held == .stopped || state.hasStopped else {
                await player.timeshift.interruptionEnded()
                return false
            }
            guard let tuned else { return false }
            player.timeshift.channelChanged()
            tune(tuned)
            return true
        }

        /// A load that finished while Movies, Series or Search is open stays
        /// paused, as if it had been playing when the tab opened.
        func holdLoadedBehindContent() {
            guard tab.isContent, heldByShell == nil else { return }
            player.timeshift.interrupted()
            heldByShell = .paused
        }
    }
#endif
