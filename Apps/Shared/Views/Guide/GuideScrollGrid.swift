#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Where the grid is scrolled, as the scroll view reports it. Views that
    /// follow every frame read `x` and `y`; the rows read only `viewport`,
    /// which changes when a row or a column comes into view.
    @MainActor @Observable
    final class GuideGridScroll {
        var x = 0.0
        var y = 0.0
        var size = CGSize.zero
        private(set) var viewport: GuideViewport?

        func update(_ rect: CGRect, rowPitch: Double, rowCount: Int, timeline: GuideTimeline, scale: GuideScale) {
            if x != rect.minX { x = rect.minX }
            if y != rect.minY { y = rect.minY }
            if size != rect.size { size = rect.size }
            refresh(rowPitch: rowPitch, rowCount: rowCount, timeline: timeline, scale: scale)
        }

        func refresh(rowPitch: Double, rowCount: Int, timeline: GuideTimeline, scale: GuideScale) {
            let next = GuideViewport(
                x: x, y: y, width: max(0, size.width - scale.channelColumn), height: size.height, rowPitch: rowPitch,
                rowCount: rowCount, timeline: timeline, scale: scale)
            if next != viewport { viewport = next }
        }

        /// The time at the grid's left edge, just right of the channel column.
        func leadingTime(_ timeline: GuideTimeline, _ scale: GuideScale) -> Date {
            scale.date(at: x, from: timeline.bounds.start)
        }
    }

    /// The iPad and Mac grid (guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac;
    /// `iPad-Guide`): channel names pinned on the left and time labels on
    /// top while the programmes scroll both ways under them, with the now
    /// line over the rows. Only the rows and half hours in view, plus one
    /// each way, are built.
    struct GuideScrollGrid: View {
        let data: GuideData
        let now: Date
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @State private var scroll = GuideGridScroll()
        @State private var position = ScrollPosition(x: 0, y: 0)
        @State private var opened = false
        @ScaledMetric(relativeTo: .subheadline) private var rowHeight = GuideBoard.rowHeight

        private var scale: GuideScale { model.zoom.scale }
        private var pitch: Double { rowHeight + GuideBoard.rowGap }
        private var reading: GuideBoardReading { GuideBoardReading(live: live, model: model) }

        var body: some View {
            VStack(alignment: .leading, spacing: GuideBoard.rowGap) {
                GuideGridHeader(
                    scroll: scroll, timeline: data.timeline, scale: scale, now: now, title: live.catalogue.label(of: live.group),
                    count: data.rows.count)
                if data.rows.isEmpty {
                    GuideBoard.Empty(text: "No channels in \(live.catalogue.label(of: live.group))")
                        .accessibilityIdentifier("guide.empty")
                } else {
                    grid
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.grid")
        }

        /// The scroll view appears once the space it has is known, already
        /// at the place the guide opens at.
        private var grid: some View {
            Group {
                if opened {
                    scrollView
                } else {
                    Color.clear
                }
            }
            .onGeometryChange(for: CGSize.self, of: \.size) { size in
                guard !opened, size.width > 0 else { return }
                scroll.size = size
                let opening = place(
                    model.time.map { .time($0, row: model.details?.key ?? model.cursor?.key) } ?? .now(row: reading.playingKey))
                position = ScrollPosition(point: opening.point)
                model.scrolled(to: opening.time)
                opened = true
            }
        }

        private var scrollView: some View {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(width: scale.channelColumn + data.timeline.width(at: scale), height: Double(data.rows.count) * pitch)
                    if let viewport = scroll.viewport {
                        GuideGridRows(data: data, viewport: viewport, scroll: scroll, now: now, scale: scale, rowHeight: rowHeight)
                        GuideGridChannels(data: data, viewport: viewport, scroll: scroll, rowHeight: rowHeight)
                    }
                }
            }
            .scrollPosition($position)
            .defaultScrollAnchor(.topLeading)
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGRect.self, of: \.visibleRect) { _, rect in
                scroll.update(rect, rowPitch: pitch, rowCount: data.rows.count, timeline: data.timeline, scale: scale)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .idle { model.scrolled(to: scroll.leadingTime(data.timeline, scale)) }
            }
            .overlay(alignment: .topLeading) {
                GuideGridNowLine(scroll: scroll, timeline: data.timeline, scale: scale, now: now)
            }
            .onChange(of: model.jump) { _, jump in
                if let jump { perform(jump.place) }
            }
            .onChange(of: model.zoom) { old, new in rezoom(from: old.scale, to: new.scale) }
            .onChange(of: data.rows.count) { _, count in
                scroll.refresh(rowPitch: pitch, rowCount: count, timeline: data.timeline, scale: scale)
            }
            .onChange(of: data.timeline.bounds.start) { old, new in
                // A guide that loads or refreshes keeps the same time in view.
                scrollTo(x: scroll.x + scale.offset(of: old, from: new), y: scroll.y)
            }
            .modifier(GuidePinch(channelColumn: scale.channelColumn) { magnification, x in model.pinched(by: magnification, at: x) })
        }

        // MARK: Scrolling

        private func perform(_ place: GuideJump.Place) {
            let target = self.place(place)
            scrollTo(x: target.point.x, y: target.point.y)
            model.scrolled(to: target.time)
        }

        /// Where `place` puts the grid's top left corner, and the time then
        /// at its left edge.
        private func place(_ place: GuideJump.Place) -> (point: CGPoint, time: Date) {
            let visibleWidth = max(0, scroll.size.width - scale.channelColumn)
            let time: Date
            let row: RowKey?
            switch place {
            case .reveal(let target):
                let left = scroll.leadingTime(data.timeline, scale)
                let right = scale.date(at: scroll.x + visibleWidth, from: data.timeline.bounds.start)
                let inView = target.start >= left && target.start < right.addingTimeInterval(-GuideTimeline.column / 2)
                time = inView ? left : data.timeline.scrollClamp(data.timeline.halfHour(atOrBefore: target.start))
                row = target.key
            case .now(let key):
                time = data.timeline.regularOpening(at: now, visibleWidth: visibleWidth, scale: scale)
                row = key
            case .time(let date, let key):
                time = data.timeline.scrollClamp(data.timeline.halfHour(atOrBefore: date))
                row = key
            }
            var y = scroll.y
            if let row, let index = data.rows.firstIndex(of: row) {
                let top = Double(index) * pitch
                if top < scroll.y || top + pitch > scroll.y + scroll.size.height {
                    y = top - max(0, (scroll.size.height - pitch) / 2)
                }
            }
            let x = time == scroll.leadingTime(data.timeline, scale) ? scroll.x : scale.offset(of: time, from: data.timeline.bounds.start)
            return (clamped(x: x, y: y), time)
        }

        /// Keeps the time under the now line, or under the pinch, in place
        /// (guide-on-iphone-ipad-and-mac/zoom). With the now line out of
        /// view, the time at the left edge stays.
        private func rezoom(from old: GuideScale, to new: GuideScale) {
            let origin = data.timeline.bounds.start
            let visibleWidth = max(0, scroll.size.width - new.channelColumn)
            let nowX = old.offset(of: now, from: origin) - scroll.x
            let anchorX: Double =
                switch model.zoomAnchor {
                case .point(let x): x
                case .nowLine, nil: (0...visibleWidth).contains(nowX) ? nowX : 0
                }
            let time = old.date(at: scroll.x + anchorX, from: origin)
            let x = GuideZoom.offset(keeping: time, at: anchorX, origin: origin, scale: new)
            scroll.refresh(rowPitch: pitch, rowCount: data.rows.count, timeline: data.timeline, scale: new)
            scrollTo(x: x, y: scroll.y)
        }

        private func scrollTo(x: Double, y: Double) {
            position.scrollTo(point: clamped(x: x, y: y))
        }

        private func clamped(x: Double, y: Double) -> CGPoint {
            let maxX = max(0, scale.channelColumn + data.timeline.width(at: scale) - scroll.size.width)
            let maxY = max(0, Double(data.rows.count) * pitch - scroll.size.height)
            return CGPoint(x: min(max(x, 0), maxX), y: min(max(y, 0), maxY))
        }
    }

    /// The blocks of the rows in view.
    private struct GuideGridRows: View {
        let data: GuideData
        let viewport: GuideViewport
        let scroll: GuideGridScroll
        let now: Date
        let scale: GuideScale
        let rowHeight: Double
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        var body: some View {
            let reading = GuideBoardReading(live: live, model: model)
            let window = viewport.time
            let originX = scale.channelColumn + scale.offset(of: window.start, from: data.timeline.bounds.start)
            ForEach(Array(viewport.rows.clamped(to: data.rows.indices)), id: \.self) { index in
                let key = data.rows[index]
                if let channel = reading.channel(key) {
                    let cells = data.cells(index, window).filter { $0.stop > window.start && $0.start < window.end }
                    let blocks = GuideRowLayout.blocks(cells.map(\.segment), in: window, now: now, scale: scale)
                    ForEach(Array(zip(cells, blocks)), id: \.0.start) { cell, block in
                        GuideGridBlock(
                            cell: cell, block: block, key: key, channel: channel, now: now, scroll: scroll, scale: scale,
                            x: originX + block.leading, y: Double(index) * (rowHeight + GuideBoard.rowGap), height: rowHeight)
                    }
                }
            }
        }
    }

    /// One block, a button that opens its details, at its place in the grid.
    private struct GuideGridBlock: View {
        let cell: GuideCell
        let block: GuideBlock
        let key: RowKey
        let channel: Channel
        let now: Date
        let scroll: GuideGridScroll
        let scale: GuideScale
        let x: Double
        let y: Double
        let height: Double
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        var body: some View {
            let target = GuideTarget(key: key, start: cell.start)
            let isSelected = model.details == target || model.cursor == target
            Button {
                model.open(target)
            } label: {
                GuideBoard.Block(content: content, width: block.width, isSelected: isSelected, titleInset: titleInset)
                    .frame(height: height)
            }
            .buttonStyle(.plain)
            .disabled(cell.programme == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GuideText.spoken(cell, channel: channel, now: now))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier(GuideText.identifier(cell, key: key))
            .popover(isPresented: presented(target)) {
                GuideDetailsPopover(target: target)
            }
            .padding(.leading, x)
            .padding(.top, y)
        }

        private var content: GuideBoard.BlockContent {
            if let placeholder = cell.placeholder { return .placeholder(placeholder.text) }
            guard let programme = cell.programme else { return .gap }
            return .programme(title: GuidePanelText.title(programme), timing: block.timing, startedEarlier: block.startedEarlier)
        }

        /// Keeps the title of a programme whose start is scrolled off on
        /// screen. Only blocks starting in the viewport's first two columns
        /// can reach past the left edge, so only they follow every frame.
        private var titleInset: Double {
            guard cell.programme != nil, block.leading < scale.columnWidth * 2 else { return 0 }
            let hidden = scroll.x + scale.channelColumn - x
            return min(max(0, hidden), max(0, block.width - 80))
        }

        private func presented(_ target: GuideTarget) -> Binding<Bool> {
            Binding {
                model.details == target
            } set: { shown in
                guard !shown, model.details == target else { return }
                // A popover also goes when the grid gives way to the rows on
                // a size change; the details stay open for the sheet then.
                Task { @MainActor in
                    if !model.compact, model.details == target { model.closeDetails() }
                }
            }
        }
    }

    /// The channel column, pinned to the left edge as the grid scrolls sideways.
    private struct GuideGridChannels: View {
        let data: GuideData
        let viewport: GuideViewport
        let scroll: GuideGridScroll
        let rowHeight: Double
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive

        var body: some View {
            let reading = GuideBoardReading(live: live, model: model)
            let playing = reading.playingKey
            ZStack(alignment: .topLeading) {
                Palette.ground
                    .frame(width: GuideZoom.channelColumn, height: Double(data.rows.count) * (rowHeight + GuideBoard.rowGap))
                ForEach(Array(viewport.rows.clamped(to: data.rows.indices)), id: \.self) { index in
                    let key = data.rows[index]
                    if let channel = reading.channel(key) {
                        let look: GuideBoard.ChannelLook = key == playing ? .playing : .plain
                        Button {
                            reading.watch(key, programme: nil, now: .now)
                            openLive()
                        } label: {
                            GuideBoard.ChannelCell(number: reading.number(key), name: channel.name, look: look) {
                                GuideBoardLogo(channel: channel, look: look)
                            }
                            .frame(height: rowHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel([reading.number(key).map(String.init), channel.name].compactMap(\.self).joined(separator: " "))
                        .accessibilityValue(look == .playing ? "playing" : "")
                        .accessibilityHint("Plays the channel")
                        .modifier(LiveFavoriteMenu(channel: channel, identifier: "guide.menu.favorite") { EmptyView() })
                        .modifier(LiveFavoriteAction(channel: channel))
                        .accessibilityIdentifier("guide.channel.\(key.identifier)")
                        .padding(.top, Double(index) * (rowHeight + GuideBoard.rowGap))
                    }
                }
            }
            .offset(x: scroll.x)
        }
    }

    /// The group title and the half-hour labels, which follow the grid sideways.
    private struct GuideGridHeader: View {
        let scroll: GuideGridScroll
        let timeline: GuideTimeline
        let scale: GuideScale
        let now: Date
        let title: String
        let count: Int

        var body: some View {
            HStack(spacing: 0) {
                GuideBoard.GroupTitle(title: title, count: count)
                    .accessibilityIdentifier("guide.groupTitle")
                GeometryReader { proxy in
                    let start = scale.date(at: scroll.x, from: timeline.bounds.start)
                    let visible = DateInterval(start: start, duration: proxy.size.width / scale.columnWidth * GuideTimeline.column)
                    ZStack(alignment: .topLeading) {
                        ForEach(timeline.columns(in: visible), id: \.self) { column in
                            GuideBoard.ColumnLabel(text: GuideText.time(column), width: scale.columnWidth)
                                .offset(x: scale.offset(of: column, from: start))
                                .accessibilityIdentifier("guide.column")
                        }
                        if visible.contains(now) {
                            GuideBoard.NowPill(time: GuideText.time(now))
                                .offset(x: scale.offset(of: now, from: start) - 24, y: 6)
                                .accessibilityIdentifier("guide.nowLine")
                        }
                    }
                }
                .clipped()
            }
            .frame(height: GuideBoard.headerHeight)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.header")
        }
    }

    /// The now line over the rows, kept right of the channel column.
    private struct GuideGridNowLine: View {
        let scroll: GuideGridScroll
        let timeline: GuideTimeline
        let scale: GuideScale
        let now: Date

        var body: some View {
            let x = scale.channelColumn + scale.offset(of: now, from: timeline.bounds.start) - scroll.x
            if x >= scale.channelColumn, x <= scroll.size.width {
                GuideBoard.NowLine()
                    .offset(x: x - 1)
                    .accessibilityHidden(true)
            }
        }
    }

    /// A channel's logo, or its initials while there is none.
    struct GuideBoardLogo: View {
        let channel: Channel
        let look: GuideBoard.ChannelLook

        var body: some View {
            let initials = GuideBoard.Initials(text: Channel.initials(for: channel.name), look: look)
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

    /// Pinch to zoom on iPad; a Mac trackpad pinch does nothing
    /// (guide-on-iphone-ipad-and-mac/zoom).
    private struct GuidePinch: ViewModifier {
        let channelColumn: Double
        let ended: (Double, Double) -> Void

        func body(content: Content) -> some View {
            #if os(iOS)
                content.simultaneousGesture(
                    MagnifyGesture().onEnded { value in
                        ended(value.magnification, max(0, value.startLocation.x - channelColumn))
                    })
            #else
                content
            #endif
        }
    }
#endif
