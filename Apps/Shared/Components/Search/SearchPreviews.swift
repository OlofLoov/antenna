#if DEBUG
    import SwiftUI

    /// The board's sample rows for "north", for previews only.
    @MainActor private enum SearchSample {
        static func ranges(_ text: String, _ word: String = "North") -> [Range<String.Index>] {
            text.range(of: word, options: .caseInsensitive).map { [$0] } ?? []
        }

        @ViewBuilder static var rows: some View {
            SearchRow.Channel(
                name: "Northern News", nameRanges: ranges("Northern News"), detail: "201 · Now: Late Edition", detailRanges: [],
                initials: "NN", logo: nil
            ) {}
            SearchRow.Channel(
                name: "Nordic One", nameRanges: [], detail: "301 · Matches Northern Report",
                detailRanges: ranges("301 · Matches Northern Report"), initials: "NO", logo: nil
            ) {}
            SearchRow.Programme(
                lead: nil, title: "North Sea Patrol", ranges: ranges("North Sea Patrol"), detail: "Docu HD · 21:00 – 22:00",
                hasCatchup: true
            ) {}
            SearchRow.Programme(
                lead: "Tue 20:00", title: "Northern Soul Night", ranges: ranges("Northern Soul Night"), detail: "Music Box · Tomorrow",
                hasCatchup: false
            ) {}
        }

        @ViewBuilder static var titles: some View {
            HStack(alignment: .top, spacing: 12) {
                SearchRow.Title(name: "Northern Lights", ranges: ranges("Northern Lights"), isSeries: true) {
                } poster: {
                    PosterTile(name: "Northern Lights", image: nil)
                }
                SearchRow.Title(name: "Northbound", ranges: ranges("Northbound"), isSeries: false) {
                } poster: {
                    PosterTile(name: "Northbound", image: nil)
                }
            }
        }
    }

    #Preview("Search rows, iPhone", traits: .fixedLayout(width: 402, height: 640)) {
        VStack(alignment: .leading, spacing: 0) {
            SearchSample.rows
            SearchSample.titles.padding(8)
            SearchRow.Recent(text: "arsenal") {}
        }
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .phone)
    }

    #Preview("Search rows, iPad", traits: .fixedLayout(width: 960, height: 640)) {
        VStack(alignment: .leading, spacing: 10) {
            SearchSample.rows
                .environment(\.searchCursor, false)
            SearchRow.Channel(
                name: "North Sport", nameRanges: SearchSample.ranges("North Sport"), detail: "118 · Now: Ice Hockey", detailRanges: [],
                initials: "NS", logo: nil
            ) {}
            .environment(\.searchCursor, true)
            SearchSample.titles
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .pad)
    }

    #Preview("Search rows, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        VStack(alignment: .leading, spacing: 20) {
            SearchSample.rows
            SearchSample.titles
            SearchRow.Recent(text: "snooker") {}
        }
        .padding(64)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .tv)
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
            SearchParts.Message(
                title: "No results for “norhtern”",
                lines: ["Check the spelling or try a channel number.", "Some sources are still loading."])
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.ground)
        .environment(\.searchMetrics, .pad)
    }
#endif
