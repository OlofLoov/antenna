#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The rows on screen and one more, each with its channel cell and the
    /// blocks in the window (tv-guide-grid/one-row-per-channel-in-the-current-group,
    /// tv-guide-grid/programmes-are-drawn-to-scale). Takes no focus; the
    /// screen's holder does.
    struct GuideRows: View {
        let data: GuideData
        let model: GuideModel
        let catalogue: Catalogue<PersistentIdentifier>
        let playing: RowKey?
        let now: Date

        var body: some View {
            let window = model.window(data)
            let highlighted = model.highlightedCell(data)
            let highlightedRow = model.highlightedRow(data)
            VStack(alignment: .leading, spacing: GuideGrid.rowSpacing) {
                ForEach(Array(model.rowWindow.drawn(of: data.rows.count)), id: \.self) { index in
                    let key = data.rows[index]
                    if let channel = catalogue.channel(for: key) {
                        row(key, channel, cells: data.cells(index, window), in: window, focus: highlightedRow == index ? highlighted : nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }

        private func row(_ key: RowKey, _ channel: Channel, cells: [GuideCell], in window: DateInterval, focus: GuideCell?) -> some View {
            let look: GuideGrid.ChannelLook = key == playing ? .playing : .plain
            let visible = cells.filter { $0.stop > window.start && $0.start < window.end }
            let blocks = GuideRowLayout.blocks(visible.map(\.segment), in: window, now: now)
            return GuideGrid.Row {
                GuideGrid.ChannelCell(number: catalogue.number(for: key) ?? channel.number, name: channel.name, look: look) {
                    GuideLogo(channel: channel, look: look)
                }
                .accessibilityIdentifier("guide.channel.\(key.identifier)")
            } blocks: {
                ForEach(Array(zip(visible, blocks)), id: \.0.start) { cell, block in
                    self.block(cell, block, key: key, channel: channel, isHighlighted: cell == focus)
                        .offset(x: block.leading)
                }
            }
        }

        @ViewBuilder
        private func block(_ cell: GuideCell, _ block: GuideBlock, key: RowKey, channel: Channel, isHighlighted: Bool) -> some View {
            let content = Self.content(cell, block)
            Group {
                if isHighlighted && model.area == .grid {
                    GuideGrid.HighlightedBlock(
                        content: content, times: cell.placeholder == nil ? GuideText.times(cell.start, cell.stop) : nil, width: block.width)
                } else {
                    GuideGrid.Block(content: content, width: block.width)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GuideText.spoken(cell, channel: channel, now: now))
            .accessibilityAddTraits(isHighlighted ? .isSelected : [])
            .accessibilityIdentifier(GuideText.identifier(cell, key: key))
        }

        static func content(_ cell: GuideCell, _ block: GuideBlock) -> GuideGrid.BlockContent {
            if let placeholder = cell.placeholder { return .placeholder(placeholder.text) }
            guard let programme = cell.programme else { return .gap }
            return .programme(title: GuidePanelText.title(programme), timing: block.timing, startedEarlier: block.startedEarlier)
        }
    }

    /// A channel's logo, or its initials while there is none.
    struct GuideLogo: View {
        let channel: Channel
        let look: GuideGrid.ChannelLook

        var body: some View {
            let initials = GuideGrid.Initials(text: Channel.initials(for: channel.name), look: look)
            if let url = channel.logoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
    }
#endif
