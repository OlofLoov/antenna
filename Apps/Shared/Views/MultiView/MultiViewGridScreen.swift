import AntennaCore
import SwiftUI

#if os(macOS) || os(iOS)

    /// Multi-view in the detail column of the Mac window and the iPad's
    /// side-by-side layout (multi-view capability; boards `iPad-MultiView`,
    /// `iPad-MultiView-Failed`): the toolbar with the count and Exit, then
    /// the tiles. A click or tap selects a tile and moves the sound, a
    /// double-click or double-tap enlarges it, Option-Command-1 to 4
    /// select, Command-Delete removes the selected tile, and Escape only
    /// undoes enlarge.
    struct MultiViewGridScreen: View {
        let model: MultiViewModel
        @Environment(LiveModel.self) private var live
        @State private var hovered: Int?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// The narrowest tile area that keeps the Mac window at 1024 pt with
        /// the channel list beside it. An iPad window cannot be widened by
        /// the app, so there the tiles take what the column has.
        static var minimumWidth: CGFloat {
            #if os(macOS)
                1024 - 352 - 1
            #else
                0
            #endif
        }

        var body: some View {
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
                GeometryReader { proxy in
                    let frames = MultiViewLayout.mac.frames(
                        count: model.session.tiles.count, width: proxy.size.width, height: proxy.size.height)
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(model.session.tiles.enumerated()), id: \.element.id) { index, tile in
                            let frame = frame(of: tile.id, at: index, in: frames, size: proxy.size)
                            tileView(tile, number: index + 1)
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.x, y: frame.y)
                                .opacity(model.session.enlarged == nil || model.session.enlarged == tile.id ? 1 : 0)
                                .zIndex(model.session.enlarged == tile.id ? 1 : 0)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.session.tiles.map(\.id))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.session.enlarged)
                }
            }
            .frame(minWidth: Self.minimumWidth, maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .background { shortcuts }
            .menuCommand(\.tileCommands, tileCommands)
            .environment(\.multiViewMetrics, .mac)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("multiView.root")
        }

        private var toolbar: some View {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                Text(MultiViewText.title())
                    .font(.boardStyle(17, weight: .semibold))
                Text(model.count)
                    .font(.boardStyle(14))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("multiView.count")
                Text(model.selectedName)
                    .font(.boardStyle(14))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("multiView.selected")
                Spacer(minLength: 0)
                Button(MultiViewText.exit()) { Task { await model.leave() } }
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("multiView.exit")
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 16)
            .frame(height: 52)
        }

        private func frame(of id: Int, at index: Int, in frames: [MultiViewLayout.Frame], size: CGSize) -> MultiViewLayout.Frame {
            if model.session.enlarged == id { return .init(x: 0, y: 0, width: size.width, height: size.height) }
            return index < frames.count ? frames[index] : .init(x: 0, y: 0, width: 0, height: 0)
        }

        private func tileView(_ tile: MultiViewSession.Tile, number: Int) -> some View {
            let identifier = "multiView.tile.\(number)"
            let shown = model.channel(of: tile.id)
            let selected = model.session.selected == tile.id
            return ZStack(alignment: .bottomLeading) {
                if let engine = model.engine(of: tile.id) {
                    PlayerSurfaceView(engine: engine)
                } else {
                    MultiViewParts.tileFill
                }
                switch model.status(tile.id) {
                case .waiting:
                    MultiViewParts.Waiting()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    MultiViewParts.Failure(
                        title: message.title, explanation: message.explanation, hint: nil, identifier: "\(identifier).failed"
                    ) {
                        Button(PlayerStatusText.tryAgain()) { Task { await model.retry(tile.id) } }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("\(identifier).retry")
                    }
                case .playing:
                    EmptyView()
                }
                MultiViewParts.Label(
                    number: shown?.channelNumber, name: shown?.name ?? "", audible: model.session.audible == tile.id, highlighted: false,
                    identifier: identifier)
            }
            .clipShape(model.session.enlarged == tile.id ? AnyShape(Rectangle()) : AnyShape(cornerShape(.medium)))
            .overlay {
                if selected, model.session.enlarged != tile.id {
                    cornerShape(.medium).strokeBorder(Palette.focus, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selected || hovered == tile.id {
                    Button {
                        Task { await model.remove(tile.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.boardStyle(12, weight: .bold))
                            .foregroundStyle(Palette.text)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .padding(4)
                    .accessibilityLabel(MultiViewText.remove())
                    .accessibilityIdentifier("\(identifier).remove")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { Task { await toggleEnlarged(tile.id) } }
            .onTapGesture { Task { await model.select(tile.id) } }
            .onHover { inside in hovered = inside ? tile.id : (hovered == tile.id ? nil : hovered) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.spokenLabel(tile.id))
            .accessibilityValue(model.statusText(tile.id))
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        private func toggleEnlarged(_ id: Int) async {
            if model.session.enlarged == id {
                model.shrink()
            } else {
                await model.enlarge(id)
            }
        }

        /// Select Tile and Remove Tile in the Playback menu, Option-Command-1
        /// to 4 and Command-Delete. Remove Tile is dimmed while the channel
        /// filter has the keyboard (keyboard-commands/typing-is-never-taken-by-a-shortcut).
        private var tileCommands: TileCommands {
            TileCommands(
                select: model.session.tiles.prefix(4).enumerated().map { index, tile in
                    MenuCommand(title: KeyCommand.selectTile(index + 1).title) { Task { await model.select(tile.id) } }
                },
                remove: MenuCommand(title: KeyCommand.removeTile.title, isEnabled: !live.typing) {
                    Task { await model.remove(model.session.selected) }
                })
        }

        /// Escape back to the grid, wherever focus is.
        private var shortcuts: some View {
            ZStack {
                if model.session.enlarged != nil {
                    Button("Back to the grid") { model.shrink() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    /// The channel row's right-click or long-press item
    /// (multi-view/start-multi-view-on-a-mac, multi-view/start-multi-view-on-an-ipad,
    /// multi-view/add-more-tiles-up-to-the-limit): "Add to Multi-view", or a
    /// grayed "Multi-view is full" at the limit. Absent where Multi-view is not offered.
    struct LiveMultiViewMenuItem: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            switch live.multiViewMenu(for: channel, offered: offered) {
            case .add:
                Button(MultiViewText.addToMultiViewMenu()) { Task { await live.addToMultiView(channel, offered: offered) } }
                    .accessibilityIdentifier("browse.menu.multiView")
            case .full:
                Button(MultiViewText.full()) {}
                    .disabled(true)
            case nil:
                EmptyView()
            }
        }

        private var offered: Bool {
            #if os(iOS)
                LiveModel.offersMultiView(regularWidth: sizeClass == .regular)
            #else
                LiveModel.offersMultiView
            #endif
        }
    }
#endif

/// The detail column in multi-view: the grid on Mac and iPad, nothing on
/// Apple TV, which has its own screen.
struct MultiViewWindow: View {
    let model: MultiViewModel

    var body: some View {
        #if os(macOS) || os(iOS)
            MultiViewGridScreen(model: model)
        #endif
    }
}

/// Add to Multi-view in the Playback menu, Command-Shift-M, for the channel
/// under the list's keyboard ring
/// (multi-view/start-multi-view-on-a-mac, multi-view/start-multi-view-on-an-ipad).
/// Dimmed with no ring or where the channel row would offer no "Add to Multi-view".
enum LiveMultiViewKey {
    #if os(macOS) || os(iOS)
        @MainActor
        static func command(cursor: RowKey?, live: LiveModel) -> MenuCommand {
            let channel = cursor.flatMap { live.catalogue.channel(for: $0) }
            let offered = offered
            let enabled = channel.map { live.multiViewMenu(for: $0, offered: offered) == .add } ?? false
            return MenuCommand(title: KeyCommand.addToMultiView.title, isEnabled: enabled) {
                guard let channel else { return }
                Task { await live.addToMultiView(channel, offered: offered) }
            }
        }

        /// The menus show only in the iPad's regular width and on Mac.
        @MainActor private static var offered: Bool {
            #if os(iOS)
                LiveModel.offersMultiView(regularWidth: true)
            #else
                LiveModel.offersMultiView
            #endif
        }
    #endif
}

/// The channel row's menu item for multi-view on a Mac and an iPad, after
/// the favorite item; nothing on iPhone.
struct LiveMultiViewMenuExtra: View {
    let channel: Channel
    @Environment(\.playDestination) private var destination

    var body: some View {
        #if os(macOS) || os(iOS)
            // No multi-view while connected to an Apple TV
            // (play-on-apple-tv/the-phone-opens-no-stream-while-connected).
            if destination?.connection == nil {
                LiveMultiViewMenuItem(channel: channel)
            }
        #endif
    }
}
