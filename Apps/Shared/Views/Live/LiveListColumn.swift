#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The channel list column: the group's name and count, then its channels.
    struct LiveListColumn<Leading: View>: View {
        @ViewBuilder var leading: Leading
        /// Called after a row is picked, so a list shown over the picture can close.
        let picked: () -> Void
        @Environment(LiveModel.self) private var live
        @FocusState private var filterFocused: Bool
        /// Where the arrow keys are in the list (live-tv-on-iphone-ipad-mac/keyboard-shortcuts).
        @State private var cursor: RowKey?

        var body: some View {
            @Bindable var live = live
            VStack(spacing: 0) {
                switch live.status {
                case .channels(let banner, _):
                    let count = live.catalogue.count(of: live.group)
                    if let banner {
                        Browse.FailureBanner(text: banner, retry: live.retry, dismiss: live.dismissBanner)
                            .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                    }
                    Browse.ListHeader(title: live.catalogue.label(of: live.group), count: "\(count) channels") {
                        leading
                    } filter: {
                        Browse.FilterField(text: $live.filter, takesKeyboardFocus: false)
                            .focused($filterFocused)
                    }
                    LiveChannelList(
                        picked: {
                            filterFocused = false
                            picked()
                        }, cursor: cursor)
                case let status:
                    HStack { leading }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                    LiveStatusMessage(status: status)
                }
            }
            .background { shortcuts }
            .menuCommand(\.findCommand, MenuCommand(title: KeyCommand.findTitle(on: .live)) { filterFocused = true })
            .menuCommand(\.addToMultiViewCommand, LiveMultiViewKey.command(cursor: cursor, live: live))
            .onChange(of: live.group) { _, _ in cursor = nil }
            .onChange(of: live.filter) { _, _ in cursor = nil }
            .onChange(of: filterFocused) { _, focused in live.typing = focused }
        }

        /// The list's keys as key commands. Outside the filter field, the arrows
        /// move the ring and Return plays its channel. Command-F, Space and
        /// Command-Shift-M are menu items (keyboard-commands capability).
        private var shortcuts: some View {
            ZStack {
                KeyboardAnchor(isActive: !filterFocused)
                FindKey { filterFocused = true }
                Group {
                    Button("Next channel") { move(1) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("Previous channel") { move(-1) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("Play the channel") { playCursor() }
                        .keyboardShortcut(.return, modifiers: [])
                }
                .disabled(filterFocused)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }

        private func playCursor() {
            guard let cursor, let channel = live.catalogue.channel(for: cursor) else { return }
            live.pick(channel)
            picked()
        }

        /// Moves the focus ring by `step` rows without switching channel,
        /// starting from the playing row or the top.
        private func move(_ step: Int) {
            let rows = live.rows
            guard !rows.isEmpty else { return }
            let start = cursor ?? live.playing.flatMap(RowKey.init)
            guard let start, let index = rows.firstIndex(of: start) else {
                cursor = rows[step > 0 ? 0 : rows.count - 1]
                return
            }
            cursor = rows[min(max(index + step, 0), rows.count - 1)]
        }
    }
#endif
