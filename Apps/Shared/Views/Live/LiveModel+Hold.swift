import AntennaCore
import Foundation

/// The pause, then stop, behind Movies, Series and Search on iPhone, iPad
/// and Mac (live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search),
/// on the `LiveHold` Apple TV uses too.
extension LiveModel {
    /// Runs tab changes one after another, so a quick Live, Movies, Live
    /// never leaves the channel paused on Live.
    func queue(_ work: @escaping @MainActor (LiveModel) async -> Void) {
        let previous = tabChange
        tabChange = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await work(self)
        }
    }

    /// Follows the Picture in Picture window. Call once, from `init`.
    func wireHold() {
        player.pictureInPictureChanged = { [weak self] active in
            if !active { self?.pictureInPictureEnded() }
        }
    }

    /// A channel picked behind Movies, Series or Search, as from Search, is
    /// on its way to Live and plays there.
    func endHoldForPick() {
        guard behindContent else { return }
        behindContent = false
        hold.cancel()
    }

    /// Movies, Series, Search and Settings hold the channel; Live and the
    /// Guide end the hold.
    func tabOpened(_ tab: LiveSession.Tab) async {
        switch tab {
        case .movies, .series, .search, .settings:
            guard !behindContent else { return }
            behindContent = true
            await holdBehindContent()
        case .live, .guide:
            guard behindContent else { return }
            behindContent = false
            await endHold()
        }
    }

    /// The Settings sheet over `tab` opened or closed. Open, it holds the
    /// channel as the Settings section does; closed, `tab` opens again, so
    /// over Live or the Guide the channel plays on and over Movies, Series
    /// or Search it stays held (live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search).
    /// The tab the next launch opens on stays `tab`.
    func settingsSheet(shown: Bool, over tab: LiveSession.Tab) {
        queue { await $0.tabOpened(shown ? .settings : tab) }
    }

    /// The Picture in Picture window ended. Brought back into the app
    /// behind Movies, Series or Search, the channel pauses as if the tab had
    /// just opened. A closed window has paused it already.
    func pictureInPictureEnded() {
        queue { live in
            guard live.behindContent, live.hold.kind == nil else { return }
            await live.holdBehindContent()
        }
    }

    /// A channel in Picture in Picture or on AirPlay keeps playing.
    /// Multi-view ends with the selected tile and full screen ends, so the
    /// section the user picked shows.
    private func holdBehindContent() async {
        guard !player.playsElsewhere else { return }
        if let multiView { await multiView.leave() }
        setFullScreen(false)
        hideControls()
        await hold.begin { [weak self] in self?.behindContent == true }
    }

    /// A paused channel plays on; a stopped one tunes again at live. A
    /// channel a movie stopped is left to Live, which tunes it as it appears.
    private func endHold() async {
        guard !suspended else { return hold.cancel() }
        guard await hold.end(), let playing else { return }
        tune(playing)
    }
}
