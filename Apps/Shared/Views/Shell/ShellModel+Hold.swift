#if os(tvOS)
    import AntennaCore
    import Foundation

    /// The pause, then stop, behind Movies, Series and Search
    /// (tvos-shell/the-video-pauses-behind-movies-series-and-search), run by
    /// the `LiveHold` iPhone, iPad and Mac share.
    extension ShellModel {
        /// Pauses a channel that plays, loads or reconnects, at once, and
        /// stops it 30 seconds later while a content tab is still open.
        func holdBehindContent() async {
            await hold.begin { [weak self] in self?.tab.isContent == true }
        }

        /// Ends the shell's hold. A paused channel plays on from where it
        /// was; one that stopped, after 30 seconds or for a movie, tunes again
        /// at live. True when it tunes again.
        func resume() async -> Bool {
            guard await hold.end(), let tuned else { return false }
            tune(tuned)
            return true
        }

        /// A load that finished while Movies, Series or Search is open stays
        /// paused, as if it had been playing when the tab opened.
        func holdLoadedBehindContent() {
            guard tab.isContent else { return }
            hold.loadLanded()
        }
    }
#endif
