#if os(tvOS)
    import AntennaCore
    import Foundation

    /// Starting multi-view from the channel overlay (multi-view/start-multi-view-on-apple-tv,
    /// tvos-shell/the-shell-hosts-multi-view).
    extension ShellModel {
        /// True when the overlay offers "Add to multi-view" for `channel`:
        /// another channel than the one playing, while it plays.
        func offersMultiView(for channel: Channel) -> Bool {
            guard multiView == nil, engine is RoutedEngine, let tuned, channel != tuned, player.state == .playing else { return false }
            return RowKey(channel) != nil && RowKey(tuned) != nil
        }

        /// The overlay's "Add to multi-view" over full-screen live.
        var multiViewOffer: OverlayMultiView {
            OverlayMultiView(
                title: MultiViewText.addToMultiView,
                offered: { [weak self] channel in self?.offersMultiView(for: channel) ?? false },
                add: { [weak self] channel in Task { await self?.startMultiView(adding: channel) } })
        }

        /// Splits the screen into the playing channel and `channel`, with no
        /// reload of the playing one and no channel change.
        func startMultiView(adding channel: Channel) async {
            guard offersMultiView(for: channel), let single = engine as? RoutedEngine, let tuned else { return }
            let languages = self.languages
            var dependencies = self.dependencies.multiView
            dependencies.tiles.options = { languages.options(for: $0) }
            guard
                let model = MultiViewModel(
                    playing: tuned, adding: channel, single: single, dependencies: dependencies,
                    channel: { [weak self] key in self?.channels.first { RowKey($0) == key } },
                    sourceName: { [weak self] id in self?.sources.first { $0.id == id }?.name ?? PlayerModel.unnamedSource })
            else { return }
            model.ended = { [weak self] kept in Task { await self?.multiViewEnded(keeping: kept) } }
            closePicker()
            session.interrupt()
            multiView = model
            await model.begin()
        }

        /// A source refresh landed while multi-view is open.
        func multiViewChannelsChanged() async {
            guard let multiView else { return }
            let keys = Set(channels.compactMap(RowKey.init))
            await multiView.channelsChanged { keys.contains($0) }
        }
    }
#endif
