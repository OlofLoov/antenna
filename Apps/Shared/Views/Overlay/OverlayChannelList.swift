#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The shown group's channels in the overlay's middle column
    /// (tv-channel-overlay/picking-a-group-shows-its-channels,
    /// tv-channel-overlay/each-channel-shows-what-is-on). Each group gets a
    /// list of its own that opens at `entry`. The list is equal to the last
    /// one drawn while the catalogue, the group and the entry are the same,
    /// so a focus move elsewhere in the overlay does not walk every row of a
    /// large group again. The guide redraws its rows on its own.
    struct OverlayChannelList: View, Equatable {
        let catalogue: Catalogue<PersistentIdentifier>
        let group: CatalogueGroup
        /// The row the list opens at and focus enters on: the playing
        /// channel when the group holds it, else the first row.
        let entry: RowKey?
        let guide: OverlayGuide
        let focus: FocusState<ShellFocus?>.Binding
        var multiView: OverlayMultiView?
        let pick: (Channel) -> Void
        let toggleFavorite: (Channel, RowKey) -> Void

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.catalogue.revision == rhs.catalogue.revision && lhs.group == rhs.group && lhs.entry == rhs.entry
                && lhs.multiView == nil && rhs.multiView == nil
        }

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    // Rows move on to the next programme at the minute it starts.
                    TimelineView(.everyMinute) { context in
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(catalogue.rows(in: group), id: \.self) { key in
                                if let channel = catalogue.channel(for: key) {
                                    row(key, channel, line: guide.line(for: channel, at: context.date))
                                }
                            }
                        }
                    }
                }
                .scrollClipDisabled()
                .accessibilityIdentifier("overlay.channels")
                .onAppear {
                    if let entry { proxy.scrollTo(entry, anchor: .center) }
                }
            }
        }

        private func row(_ key: RowKey, _ channel: Channel, line: GuideLine) -> some View {
            let number = catalogue.channelNumber(for: key)
            let progress: Double?
            let remaining: String?
            switch line {
            case .programme(_, let fraction, let left):
                progress = fraction
                remaining = left
            case .message:
                progress = nil
                remaining = nil
            }
            let identifier = "overlay.channel.\(key.identifier)"
            return ChannelOverlay.ChannelRow(
                number: number, name: channel.name, detail: line.text, progress: progress, hasCatchUp: channel.catchUpBadge != nil,
                identifier: identifier, badge: multiView?.tileBadge(key).map(MultiViewText.tileBadge)
            ) {
                pick(channel)
            } logo: {
                OverlayLogo(channel: channel)
            }
            .focused(focus, equals: .overlay(.channel(key)))
            .contextMenu {
                // Held select (favorites/hold-select-to-favorite-on-apple-tv).
                Browse.FavoriteMenuButton(isFavorite: catalogue.isFavorite(channel)) { toggleFavorite(channel, key) }
                    .accessibilityIdentifier("overlay.menu.favorite")
            }
            .id(key)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel([number.map(String.init), channel.name, line.text, remaining].compactMap(\.self).joined(separator: ", "))
            .accessibilityActions([
                Browse.FavoriteMenuButton.action(isFavorite: catalogue.isFavorite(channel)) { toggleFavorite(channel, key) }
            ])
        }
    }

    /// A channel's logo in the overlay, or its initials while there is none.
    struct OverlayLogo: View {
        let channel: Channel

        var body: some View {
            LogoImage(url: channel.logoURL) { ChannelOverlay.Initials(text: Channel.initials(for: channel.name)) }
        }
    }
#endif
