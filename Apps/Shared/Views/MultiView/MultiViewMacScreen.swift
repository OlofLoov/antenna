import AntennaCore
import SwiftUI

#if os(macOS)

    /// Multi-view in the Mac window's detail column (multi-view capability;
    /// boards `iPad-MultiView`, `iPad-MultiView-Failed`): the toolbar with
    /// the count and Exit, then the tiles. A click selects a tile and moves
    /// the sound, a double-click enlarges it, Command-1 to 4 select,
    /// Command-Delete removes the selected tile, and Escape only undoes
    /// enlarge.
    struct MultiViewMacScreen: View {
        let model: MultiViewModel
        @State private var hovered: Int?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// The narrowest tile area that keeps the window at 1024 pt with the
        /// channel list beside it.
        static let minimumWidth: CGFloat = 1024 - 352 - 1

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
            .environment(\.multiViewMetrics, .mac)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("multiView.root")
        }

        private var toolbar: some View {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                Text(MultiViewText.title)
                    .font(.system(size: 17, weight: .semibold))
                Text(model.count)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("multiView.count")
                Text(model.selectedName)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("multiView.selected")
                Spacer(minLength: 0)
                Button(MultiViewText.exit) { Task { await model.leave() } }
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
                        Button(PlayerStatusText.tryAgain) { Task { await model.retry(tile.id) } }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("\(identifier).retry")
                    }
                case .playing:
                    EmptyView()
                }
                MultiViewParts.Label(
                    number: shown?.number, name: shown?.name ?? "", audible: model.session.audible == tile.id, highlighted: false,
                    identifier: identifier)
            }
            .clipShape(RoundedRectangle(cornerRadius: model.session.enlarged == tile.id ? 0 : 12))
            .overlay {
                if selected, model.session.enlarged != tile.id {
                    RoundedRectangle(cornerRadius: 12).stroke(Palette.focus, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selected || hovered == tile.id {
                    Button {
                        Task { await model.remove(tile.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Palette.scrimTint.opacity(0.72), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.text)
                    .accessibilityLabel(MultiViewText.remove)
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

        /// Command-1 to 4, Command-Delete and Escape, wherever focus is.
        private var shortcuts: some View {
            ZStack {
                ForEach(Array(model.session.tiles.enumerated()), id: \.element.id) { index, tile in
                    Button("Select tile \(index + 1)") { Task { await model.select(tile.id) } }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Button(MultiViewText.remove) { Task { await model.remove(model.session.selected) } }
                    .keyboardShortcut(.delete, modifiers: .command)
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

    /// The channel row's right-click item (multi-view/start-multi-view-on-a-mac,
    /// multi-view/add-more-tiles-up-to-the-limit): "Add to Multi-view", or a
    /// grayed "Multi-view is full" at the limit. Absent where Multi-view is not offered.
    struct LiveMultiViewMenuItem: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live

        var body: some View {
            switch live.multiViewMenu(for: channel) {
            case .add:
                Button(MultiViewText.addToMultiViewMenu) { Task { await live.addToMultiView(channel) } }
            case .full:
                Button(MultiViewText.full) {}
                    .disabled(true)
            case nil:
                EmptyView()
            }
        }
    }
#endif

/// The detail column in multi-view: the Mac grid, nothing on iPhone and
/// iPad, which never start it.
struct MultiViewWindow: View {
    let model: MultiViewModel

    var body: some View {
        #if os(macOS)
            MultiViewMacScreen(model: model)
        #endif
    }
}

/// Command-Shift-M adds the channel under the list's keyboard ring
/// (multi-view/start-multi-view-on-a-mac). Nothing on iPhone and iPad.
struct LiveMultiViewKey: View {
    let cursor: RowKey?
    @Environment(LiveModel.self) private var live

    var body: some View {
        #if os(macOS)
            Button(MultiViewText.addToMultiViewMenu) {
                guard let cursor, let channel = live.catalogue.channel(for: cursor) else { return }
                Task { await live.addToMultiView(channel) }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        #endif
    }
}

extension View {
    /// The channel row's right-click item for multi-view on a Mac.
    @ViewBuilder func liveMultiViewMenu(_ channel: Channel) -> some View {
        #if os(macOS)
            contextMenu { LiveMultiViewMenuItem(channel: channel) }
        #else
            self
        #endif
    }
}
