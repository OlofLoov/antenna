#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Multi-view on Apple TV (multi-view capability; boards `TV-MultiView`,
    /// `TV-MultiView-Two`, `TV-MultiView-Failed`, `TV-MultiView-Actions`,
    /// `TV-MultiView-Swap`, `TV-MultiView-Pick`): the tiles, the picker for
    /// a tile, its actions and the full-screen tile. Covers the shell, so
    /// Menu, play/pause, swipes and digits reach only this screen.
    struct MultiViewTVScreen: View {
        let model: MultiViewModel
        let catalogue: Catalogue<PersistentIdentifier>
        let guide: OverlayGuide
        let overlay: ChannelOverlayModel
        let toggleFavorite: (Channel, RowKey) -> Void
        @FocusState private var tileFocus: Int?
        @FocusState private var focus: ShellFocus?
        @FocusState private var actionFocus: TileAction?
        /// The tile focus goes back to after the actions close; focus the
        /// system moves elsewhere first is sent back without selecting.
        @State private var returning: Int?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        enum TileAction: Hashable { case retry, fullScreen, changeChannel, remove }

        var body: some View {
            GeometryReader { proxy in
                let frames = MultiViewLayout.television.frames(
                    count: model.session.tiles.count, width: proxy.size.width, height: proxy.size.height)
                ZStack(alignment: .topLeading) {
                    Palette.ground
                    ForEach(Array(model.session.tiles.enumerated()), id: \.element.id) { index, tile in
                        let frame = frame(of: tile.id, at: index, in: frames, size: proxy.size)
                        tileView(tile, number: index + 1)
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.x, y: frame.y)
                            .opacity(model.session.enlarged == nil || model.session.enlarged == tile.id ? 1 : 0)
                            .zIndex(model.session.enlarged == tile.id ? 1 : 0)
                    }
                    if let actions = model.actionsOpen, let index = actionsIndex(actions, frames: frames) {
                        actionsPanel(for: actions, number: index + 1)
                            .frame(width: 520)
                            .offset(x: frames[index].x + (frames[index].width - 520) / 2, y: frames[index].y + 60)
                            .zIndex(2)
                    }
                    overlays
                    #if DEBUG
                        VStack(alignment: .trailing) {
                            ForEach(Array(model.session.tiles.enumerated()), id: \.element.id) { index, tile in
                                UITestingShell.TileProbe(engine: model.engine(of: tile.id), identifier: "multiView.tile.\(index + 1)")
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .zIndex(5)
                    #endif
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.session.tiles.map(\.id))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.session.enlarged)
            }
            .ignoresSafeArea()
            .onExitCommand(perform: menu)
            .onPlayPauseCommand(perform: playPause)
            .onChange(of: tileFocus) { _, tile in
                guard let tile else { return }
                if let returning {
                    guard tile == returning else { return tileFocus = returning }
                    self.returning = nil
                }
                Task { await model.select(tile) }
            }
            .onChange(of: focus) { _, new in
                switch new {
                case .overlay(.channel(let key)): overlay.highlight(key)
                case .overlay(.group(let group)): overlay.show(group)
                default: break
                }
            }
            .onChange(of: model.session.selected, initial: true) { _, selected in
                guard model.picking == nil, model.actionsOpen == nil, tileFocus != selected else { return }
                tileFocus = selected
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("multiView.root")
        }

        // MARK: Tiles

        /// The place of the tile whose actions are open, while it has a frame.
        private func actionsIndex(_ id: Int, frames: [MultiViewLayout.Frame]) -> Int? {
            model.session.tiles.firstIndex { $0.id == id }.flatMap { $0 < frames.count ? $0 : nil }
        }

        private func frame(of id: Int, at index: Int, in frames: [MultiViewLayout.Frame], size: CGSize) -> MultiViewLayout.Frame {
            if model.session.enlarged == id { return .init(x: 0, y: 0, width: size.width, height: size.height) }
            return index < frames.count ? frames[index] : .init(x: 0, y: 0, width: 0, height: 0)
        }

        private func tileView(_ tile: MultiViewSession.Tile, number: Int) -> some View {
            let identifier = "multiView.tile.\(number)"
            let shown = model.channel(of: tile.id)
            let highlighted = tileFocus == tile.id
            return Button {
                openPicker(for: tile.id)
            } label: {
                ZStack(alignment: .bottomLeading) {
                    if let engine = model.engine(of: tile.id) {
                        PlayerSurfaceView(engine: engine)
                    } else {
                        MultiViewParts.tileFill
                    }
                    switch model.status(tile.id) {
                    case .waiting:
                        MultiViewParts.Waiting()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityIdentifier("\(identifier).buffering")
                    case .failed(let message):
                        MultiViewParts.Failure(
                            title: message.title, explanation: message.explanation, hint: MultiViewText.failedHint,
                            identifier: "\(identifier).failed"
                        ) { EmptyView() }
                    case .playing:
                        EmptyView()
                    }
                    MultiViewParts.Label(
                        number: shown?.channelNumber, name: shown?.name ?? "", audible: model.session.audible == tile.id,
                        highlighted: highlighted, identifier: identifier)
                }
                .clipShape(RoundedRectangle(cornerRadius: model.session.enlarged == tile.id ? 0 : 14))
                .overlay {
                    if highlighted, model.session.enlarged != tile.id {
                        RoundedRectangle(cornerRadius: 14).stroke(Palette.focus, lineWidth: 5)
                            .shadow(color: Palette.focusShadow, radius: 16, y: 12)
                    }
                }
            }
            .buttonStyle(HolderStyle())
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in openActions(for: tile.id) })
            // While the picker is open only its tile can take focus, so focus goes
            // straight back to it; the actions menu holds focus until it closes.
            .disabled(model.picking.map { $0 != tile.id } ?? (model.actionsOpen != nil))
            .focused($tileFocus, equals: tile.id)
            .accessibilityLabel(model.spokenLabel(tile.id))
            .accessibilityValue(model.statusText(tile.id))
            .accessibilityIdentifier(identifier)
            .accessibilityAction(named: MultiViewText.fullScreen) { Task { await model.enlarge(tile.id) } }
            .accessibilityAction(named: MultiViewText.changeChannel) { openPicker(for: tile.id) }
            .accessibilityAction(named: MultiViewText.remove) { Task { await model.remove(tile.id) } }
            .accessibilityAction(named: PlayerStatusText.tryAgain) { Task { await model.retry(tile.id) } }
        }

        // MARK: Hint, badge and picker

        @ViewBuilder private var overlays: some View {
            if model.hintShown, model.session.enlarged == nil, model.picking == nil {
                MultiViewParts.Hint(keys: MultiViewText.hints)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 96)
                    .allowsHitTesting(false)
                    .zIndex(3)
            }
            if let enlarged = model.session.enlarged, model.badgeShown, let number = model.session.number(of: enlarged) {
                MultiViewParts.Badge(
                    text: MultiViewText.enlargedBadge(tile: number, of: model.session.tiles.count), hint: MultiViewText.enlargedHint
                )
                .padding(.leading, 64)
                .padding(.top, 44)
                .allowsHitTesting(false)
                .zIndex(3)
            }
            if let tile = model.picking, let shown = model.channel(of: tile) {
                ChannelOverlayView(
                    catalogue: catalogue, playing: shown, guide: guide, model: overlay, focus: $focus,
                    pick: { channel, _ in Task { await pick(channel, for: tile) } },
                    toggleFavorite: toggleFavorite, openSearch: {}, multiView: pickOffer(for: tile)
                )
                .transition(reduceMotion ? .opacity : .move(edge: .leading))
                .zIndex(4)
            }
        }

        private func pickOffer(for tile: Int) -> OverlayMultiView {
            let number = model.session.number(of: tile) ?? 1
            return OverlayMultiView(
                title: MultiViewText.addAsNewTile,
                offered: { channel in
                    model.session.canAdd && RowKey(channel).flatMap(model.session.tile(showing:)) == nil
                },
                add: { channel in Task { await add(channel) } },
                pickTarget: MultiViewText.changing(tile: number, of: model.session.tiles.count),
                watchTitle: MultiViewText.showIn(tile: number),
                tileBadge: { model.tileNumber(showing: $0) })
        }

        // MARK: Actions

        private func actionsPanel(for tile: Int, number: Int) -> some View {
            let failed: Bool = {
                if case .failed = model.status(tile) { return true }
                return false
            }()
            return VStack(alignment: .leading, spacing: 4) {
                Text(MultiViewText.actionsTitle(tile: number, name: model.channel(of: tile)?.name ?? "").uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
                    .padding(EdgeInsets(top: 8, leading: 24, bottom: 12, trailing: 24))
                if failed {
                    actionRow(PlayerStatusText.tryAgain, .retry, "multiView.action.retry") {
                        returnFocus(to: tile)
                        Task { await model.retry(tile) }
                    }
                }
                actionRow(MultiViewText.fullScreen, .fullScreen, "multiView.action.fullScreen") {
                    returnFocus(to: tile)
                    Task { await model.enlarge(tile) }
                }
                actionRow(MultiViewText.changeChannel, .changeChannel, "multiView.action.changeChannel") {
                    model.actionsOpen = nil
                    openPicker(for: tile)
                }
                actionRow(MultiViewText.remove, .remove, "multiView.action.remove") { Task { await model.remove(tile) } }
            }
            .padding(14)
            .background(Palette.scrimTint.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
            .focusSection()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("multiView.actions")
            .onAppear { actionFocus = failed ? .retry : .fullScreen }
        }

        private func actionRow(_ title: String, _ action: TileAction, _ identifier: String, perform: @escaping () -> Void) -> some View {
            Button(title, action: perform)
                .buttonStyle(ActionRowStyle())
                .focused($actionFocus, equals: action)
                .accessibilityIdentifier(identifier)
        }

        // MARK: Input

        private func openPicker(for tile: Int) {
            guard let shown = model.channel(of: tile) else { return }
            model.picking = tile
            focus = .overlay(overlay.open(catalogue, playing: shown))
        }

        /// Closes the actions with focus back on `tile`.
        private func returnFocus(to tile: Int) {
            returning = tile
            model.actionsOpen = nil
            tileFocus = tile
        }

        private func openActions(for tile: Int) {
            guard model.picking == nil else { return }
            model.actionsOpen = tile
        }

        private func pick(_ channel: Channel, for tile: Int) async {
            tileFocus = tile
            await model.change(tile, to: channel)
            tileFocus = model.session.selected
        }

        private func add(_ channel: Channel) async {
            if let tile = model.picking { tileFocus = tile }
            await model.add(channel)
            tileFocus = model.session.selected
        }

        /// Menu closes the actions or the picker, then a full-screen tile,
        /// then leaves multi-view keeping the highlighted tile.
        private func menu() {
            if let tile = model.actionsOpen {
                returnFocus(to: tile)
            } else if let tile = model.picking {
                tileFocus = tile
                model.picking = nil
            } else if model.session.enlarged != nil {
                model.shrink()
            } else {
                Task { await model.leave() }
            }
        }

        /// Play/pause shows the highlighted tile full screen and back; it
        /// never pauses a tile.
        private func playPause() {
            guard model.picking == nil, model.actionsOpen == nil else { return }
            if model.session.enlarged != nil {
                model.shrink()
            } else {
                Task { await model.enlarge(model.session.selected) }
            }
        }
    }

    /// A row of the tile actions: the white card while focused.
    private struct ActionRowStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            ActionRowLabel(label: configuration.label)
        }
    }

    private struct ActionRowLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 29, weight: isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(isFocused ? Palette.focus : .clear, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }
#endif
