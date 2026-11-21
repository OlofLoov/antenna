#if DEBUG
    import AntennaCore
    import SwiftUI

    /// The board's sample rows for "north", for previews only.
    @MainActor private enum SearchSample {
        static let query = "north"

        static func ranges(_ text: String) -> [Range<String.Index>] {
            text.range(of: query, options: .caseInsensitive).map { [$0] } ?? []
        }

        /// Channels as the Live list draws them on iPhone, iPad and Mac.
        @ViewBuilder static var channels: some View {
            VStack(spacing: 2) {
                Browse.ChannelRow(
                    number: ChannelNumber(major: 201), name: "Northern News", detail: "Late Edition", progress: 0.4, hasCatchUp: true,
                    isPlaying: false, nameRanges: ranges("Northern News"), select: {}
                ) {
                    Browse.Initials(text: "NN", isSelected: false)
                }
                Browse.ChannelRow(
                    number: ChannelNumber(major: 301), name: "Nordic One", detail: "Matches Northern Report", progress: nil,
                    hasCatchUp: false, isPlaying: false, detailRanges: ranges("Matches Northern Report"), select: {}
                ) {
                    Browse.Initials(text: "NO", isSelected: false)
                }
            }
        }

        /// Channels as the Apple TV channel list draws them.
        @ViewBuilder static var televisionChannels: some View {
            HStack(spacing: 20) {
                ChannelOverlay.ChannelRow(
                    number: ChannelNumber(major: 201), name: "Northern News", detail: "Late Edition", progress: 0.4, hasCatchUp: true,
                    identifier: "preview.0", nameRanges: ranges("Northern News"), select: {}
                ) {
                    ChannelOverlay.Initials(text: "NN")
                }
                ChannelOverlay.ChannelRow(
                    number: ChannelNumber(major: 301), name: "Nordic One", detail: "Matches Northern Report", progress: nil,
                    hasCatchUp: false, identifier: "preview.1", detailRanges: ranges("Matches Northern Report"), select: {}
                ) {
                    ChannelOverlay.Initials(text: "NO")
                }
            }
        }

        @ViewBuilder static var programmes: some View {
            VStack(spacing: 6) {
                SearchRow.Programme(
                    lead: nil, title: "North Sea Patrol", ranges: ranges("North Sea Patrol"), detail: "Docu HD · 21:00 – 22:00",
                    hasCatchup: true, progress: 0.3
                ) {}
                SearchRow.Programme(
                    lead: "Tue 20:00", title: "Northern Soul Night", ranges: ranges("Northern Soul Night"), detail: "Music Box · Tomorrow",
                    hasCatchup: false
                ) {}
            }
        }

        /// The shelf's poster cards, SERIES on a series, the name under each.
        @ViewBuilder static var titles: some View {
            HStack(alignment: .top, spacing: 12) {
                ForEach([ShelfFixtures.series(0), ShelfFixtures.movie(1)]) { title in
                    VStack(alignment: .leading, spacing: 6) {
                        ShelfView.PosterCard(title: title, label: title.name, badged: [.series]) {}
                        PreviewName(name: title.name)
                    }
                }
            }
        }

        @ViewBuilder static var people: some View {
            HStack(spacing: 10) {
                PreviewPerson(name: "Northa Berg", detail: "Acting · 4 in your sources")
                PreviewPerson(name: "Lars North", detail: "Directing · 2 in your sources")
            }
        }
    }

    private struct PreviewName: View {
        let name: String
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            SearchRow.Highlighted(text: name, ranges: SearchSample.ranges(name))
                .font(.boardStyle(metrics.caption))
                .foregroundStyle(Browse.textSecondary)
                .lineLimit(1)
                .frame(width: metrics.poster.width, alignment: .leading)
        }
    }

    private struct PreviewPerson: View {
        let name: String
        let detail: String
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            TitlePage.Chip(type: metrics.chips, name: name, nameRanges: SearchSample.ranges(name)) {
            } trailing: {
                Text(verbatim: detail)
            }
        }
    }

    #Preview("Search rows, iPhone", traits: .fixedLayout(width: 402, height: 720)) {
        VStack(alignment: .leading, spacing: 12) {
            SearchSample.channels
            SearchSample.programmes
            SearchSample.titles.padding(.horizontal, 8)
            SearchSample.people
            SearchRow.Recent(text: "arsenal") {}
        }
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .phone)
        .environment(\.shelfMetrics, .phone)
        .environment(\.browseMetrics, .compact)
    }

    #Preview("Search rows, iPad", traits: .fixedLayout(width: 960, height: 720)) {
        VStack(alignment: .leading, spacing: 12) {
            SearchSample.channels
                .frame(width: 300)
            Browse.ChannelRow(
                number: ChannelNumber(major: 118), name: "North Sport", detail: "Ice Hockey", progress: 0.7, hasCatchUp: false,
                isPlaying: false, nameRanges: SearchSample.ranges("North Sport"), select: {}
            ) {
                Browse.Initials(text: "NS", isSelected: false)
            }
            .modifier(SearchRow.CursorRing(shape: cornerShape(.medium)))
            .environment(\.searchCursor, true)
            .frame(width: 300)
            SearchSample.programmes
                .frame(width: 440)
            SearchSample.titles
            SearchSample.people
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .pad)
        .environment(\.shelfMetrics, .pad)
        .environment(\.browseMetrics, .regular)
    }

    #Preview("Search rows, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        VStack(alignment: .leading, spacing: 20) {
            SearchSample.televisionChannels
            SearchSample.programmes
            SearchSample.titles
            SearchSample.people
            SearchRow.Recent(text: "snooker") {}
        }
        .padding(Metrics.televisionSafeArea)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .tv)
        .environment(\.shelfMetrics, .tv)
    }

    #Preview("Search parts", traits: .fixedLayout(width: 960, height: 640)) {
        @Previewable @State var text = "north"
        VStack(alignment: .leading, spacing: 16) {
            SearchParts.Field(text: $text, clear: {}, submit: {})
            HStack(spacing: 8) {
                SearchParts.Chip(title: "All · 21", isSelected: true, isEmpty: false) {}
                SearchParts.Chip(title: "Channels · 3", isSelected: false, isEmpty: false) {}
                SearchParts.Chip(title: "Series · 0", isSelected: false, isEmpty: true) {}
            }
            SearchParts.Header(title: "In the guide", count: "Next 7 days · 12") {
                SearchParts.SeeAll(count: 12) {}
            }
            SearchParts.CapNote(text: "Showing 500 of 612")
            SearchParts.SidebarRecent(text: "the long harbor", isCursor: true) {}
            HStack {
                SearchParts.SectionField(prompt: "Search movies", text: .constant(""))
                SearchParts.SectionButton {}
            }
            SearchParts.LaterRow(text: "Tomorrow 20:00 · Northern Soul Night")
            SearchParts.LaterLine(text: "Tomorrow 20:00 · Northern Soul Night")
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .pad)
    }
#endif
