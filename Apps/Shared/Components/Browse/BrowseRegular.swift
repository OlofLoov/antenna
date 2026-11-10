import SwiftUI

extension Browse {
    /// The top of the iPad and Mac channel list: the group's name and
    /// count, with a leading slot for the sidebar button when the sidebar
    /// is folded, and the filter field under them.
    struct ListHeader<Leading: View, Filter: View>: View {
        let title: String
        let count: String
        @ViewBuilder var leading: Leading
        @ViewBuilder var filter: Filter

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    leading
                    Text(title)
                        .font(.title.weight(.bold))
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("browse.header.title")
                    Spacer(minLength: 8)
                    Text(count)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("browse.header.count")
                }
                filter
            }
            .foregroundStyle(Palette.text)
            .padding(EdgeInsets(top: 22, leading: 16, bottom: 10, trailing: 16))
        }
    }

    /// A 36 pt square button that shows a folded column, with a 44 pt hit area.
    struct ToggleButton: View {
        let title: String
        let systemImage: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 17))
                    .frame(width: 36, height: 36)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .accessibilityLabel(title)
        }
    }

    /// What the details under the picture say about the programme on now.
    struct PanelNow: Equatable, Sendable {
        /// The programme title, or "No programme information" or "Loading guide…".
        var title: String
        /// "20:00 – 22:00"; nil without a programme.
        var times: String?
        /// "Sport One · 104 · 26 min left".
        var meta: String
        var summary: String?
        /// How far into the programme, 0 to 1; nil without a programme.
        var progress: Double?
    }

    /// One programme after the current one.
    struct PanelNext: Equatable, Identifiable, Sendable {
        var id: String { time + title }
        var time: String
        var title: String
    }

    /// The playing channel's details under the picture on iPad and Mac
    /// (`iPad`, "Player + now/next"): logo, programme, times, the channel's
    /// name and number with the time left, the description and the star,
    /// then up to three programmes that follow.
    struct Panel<Logo: View, Trailing: View>: View {
        let channel: String
        let now: PanelNow
        let next: [PanelNext]
        @ViewBuilder var logo: Logo
        @ViewBuilder var trailing: Trailing

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    logo
                        .frame(width: 84, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .environment(\.browseMetrics, .panel)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(now.title)
                                .font(.title2.weight(.bold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let times = now.times {
                                Text(times)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Text(now.meta)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textMuted)
                        if let progress = now.progress {
                            ProgressBar(fraction: progress)
                                .frame(maxWidth: 240)
                        }
                        if let summary = now.summary {
                            Text(summary)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundStyle(Browse.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("browse.panel.now")
                    trailing
                }
                if !next.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(text: "Up next on \(channel)")
                            .padding(.bottom, 8)
                        ForEach(next) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(item.time)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textMuted)
                                    .frame(width: 52, alignment: .leading)
                                Text(item.title)
                                    .font(.callout)
                                    .lineLimit(1)
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                            .overlay(alignment: .top) {
                                Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("browse.panel.next")
                }
            }
            .foregroundStyle(Palette.text)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("browse.panel")
        }
    }
}

extension Browse.Metrics {
    /// The 84 by 56 tile in the details panel.
    static let panel = Browse.Metrics(rowHeight: 56, tile: CGSize(width: 84, height: 56), name: 16, detail: 13, tileText: 18)
}

#Preview("List header", traits: .fixedLayout(width: 352, height: 140)) {
    Browse.ListHeader(title: "Sport", count: "42 channels") {
        Browse.ToggleButton(title: "Show sidebar", systemImage: "sidebar.left") {}
    } filter: {
        EmptyView()
    }
    .background(Palette.ground)
}

#Preview("Details panel", traits: .fixedLayout(width: 590, height: 360)) {
    Browse.Panel(
        channel: "Sport One",
        now: .init(
            title: "Premier League: Arsenal v Liverpool", times: "20:00 – 22:00", meta: "Sport One · 104 · 26 min left",
            summary: "Second half from the Emirates. Commentary by the studio team, with analysis at full time.", progress: 0.78),
        next: [
            .init(time: "22:00", title: "Match of the Day"), .init(time: "23:15", title: "Sports Tonight"),
            .init(time: "00:00", title: "Replay: Premier League"),
        ]
    ) {
        Browse.Initials(text: "S1", isSelected: true)
    } trailing: {
        EmptyView()
    }
    .padding(20)
    .background(Palette.ground)
}

#Preview("Details panel, no programme", traits: .fixedLayout(width: 590, height: 200)) {
    Browse.Panel(
        channel: "Sport Two", now: .init(title: "No programme information", meta: "Sport Two · 105"), next: []
    ) {
        Browse.Initials(text: "S2", isSelected: true)
    } trailing: {
        EmptyView()
    }
    .padding(20)
    .background(Palette.ground)
}
