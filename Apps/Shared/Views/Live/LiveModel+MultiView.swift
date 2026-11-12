import AntennaCore
import Foundation

#if os(macOS)
    import AppKit
#endif

/// Multi-view in the Mac window (multi-view/start-multi-view-on-a-mac).
/// iPhone and iPad never offer it.
extension LiveModel {
    /// What a channel's right-click menu offers for multi-view.
    enum MultiViewMenu: Equatable {
        case add
        /// At the limit, grayed out.
        case full
    }

    /// True on a Mac whose screen is wide enough for the 1024 pt window.
    static var offersMultiView: Bool {
        #if os(macOS)
            (NSScreen.main?.frame.width ?? 0) >= 1024
        #else
            false
        #endif
    }

    /// The menu item for `channel`, nil when there is none: nothing
    /// playing, the playing channel itself, a channel already in a tile,
    /// a screen too narrow, or iPhone and iPad.
    func multiViewMenu(for channel: Channel, offered: Bool = LiveModel.offersMultiView) -> MultiViewMenu? {
        guard offered, let key = RowKey(channel) else { return nil }
        if let multiView {
            guard multiView.session.tile(showing: key) == nil else { return nil }
            return multiView.session.canAdd ? .add : .full
        }
        guard engine is RoutedEngine, let playing, channel != playing, RowKey(playing) != nil, playback == .playing else { return nil }
        return .add
    }

    /// Adds `channel` as a tile, starting multi-view with the playing
    /// channel as tile 1 when it is not open yet.
    func addToMultiView(_ channel: Channel, offered: Bool = LiveModel.offersMultiView) async {
        guard multiViewMenu(for: channel, offered: offered) == .add else { return }
        if let multiView { return await multiView.add(channel) }
        guard let single = engine as? RoutedEngine, let playing else { return }
        var tiles = dependencies.multiView
        let options = languageOptions
        tiles.tiles.options = options
        let level = player.volume
        let make = tiles.tiles.make
        // Tiles play at the window's level; mute alone picks the one heard.
        tiles.tiles.make = {
            let engine = make()
            engine.setVolume(level, muted: false)
            return engine
        }
        guard
            let model = MultiViewModel(
                playing: playing, adding: channel, single: single, dependencies: tiles,
                channel: { [weak self] key in self?.channels.first { RowKey($0) == key } },
                sourceName: { [weak self] id in self?.sources.first { $0.id == id }?.name ?? PlayerModel.unnamedSource })
        else { return }
        model.ended = { [weak self] kept in Task { await self?.multiViewEnded(keeping: kept) } }
        setFullScreen(false)
        hideControls()
        session.interrupt()
        multiView = model
        await model.begin()
    }

    /// The channel the list marks as selected: the selected tile's while
    /// multi-view is open, else the playing one.
    var listedChannel: Channel? {
        guard let multiView else { return playing }
        return multiView.channel(of: multiView.session.selected)
    }

    /// The sources' channels changed; tiles whose channel left go.
    func multiViewChannelsChanged() async {
        guard let multiView else { return }
        let keys = Set(channels.compactMap(RowKey.init))
        await multiView.channelsChanged { keys.contains($0) }
    }
}
