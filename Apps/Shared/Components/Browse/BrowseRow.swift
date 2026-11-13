import AntennaCore
import SwiftUI

extension Browse {
    /// The menu item and swipe button that add a channel to Favorites or
    /// remove it (favorites/favorite-from-a-channel-s-menu).
    struct FavoriteMenuButton: View {
        let isFavorite: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Label(Self.title(isFavorite: isFavorite), systemImage: isFavorite ? "star.slash" : "star")
            }
        }

        /// "Add to Favorites" or "Remove from Favorites", also the name of the VoiceOver action.
        static func title(isFavorite: Bool) -> String {
            isFavorite ? "Remove from Favorites" : "Add to Favorites"
        }
    }

    /// One channel row: logo tile, the name with the number trailing it,
    /// the programme line and its progress bar, and the catch-up mark at
    /// the trailing edge (design-system/channel-rows-share-one-anatomy, with
    /// the number after the name as design.md records). The playing row is
    /// highlighted. Rows grow with the text size.
    struct ChannelRow<Logo: View>: View {
        let number: ChannelNumber?
        let name: String
        /// The programme title or a state line such as "Loading guide…".
        let detail: String
        /// How far into the programme, 0 to 1; nil draws no bar.
        let progress: Double?
        let hasCatchUp: Bool
        let isPlaying: Bool
        let select: () -> Void
        @ViewBuilder var logo: Logo
        @Environment(\.browseMetrics) private var metrics
        /// Grows the text and the row with the text size.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                HStack(spacing: 12) {
                    logo
                        .frame(width: metrics.tile.width, height: metrics.tile.height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(name)
                                .font(.system(size: metrics.name * scale, weight: isPlaying ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let number {
                                Text(number.description)
                                    .font(.system(size: metrics.detail * scale))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textMuted)
                            }
                        }
                        Text(detail)
                            .font(.system(size: metrics.detail * scale))
                            .lineLimit(1)
                            .foregroundStyle(isPlaying ? Browse.textSecondary : Palette.textMuted)
                        if let progress {
                            ProgressBar(fraction: progress)
                        }
                    }
                    if hasCatchUp {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: (metrics.detail + 2) * scale))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight * scale, alignment: .leading)
                .background(isPlaying ? Palette.surface(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .accessibilityAddTraits(isPlaying ? .isSelected : [])
        }
    }
}

// MARK: Previews

private struct PreviewRow {
    let name: String
    let initials: String
    let detail: String
    let progress: Double?
}

private let previewRows = [
    PreviewRow(name: "Eurosport 1", initials: "EUR", detail: "Snooker: UK Championship", progress: 0.35),
    PreviewRow(name: "Sport One", initials: "S1", detail: "Premier League: Arsenal v Liverpool", progress: 0.78),
    PreviewRow(name: "Sport Two", initials: "S2", detail: "No programme information", progress: nil),
    PreviewRow(name: "Arena HD", initials: "ARN", detail: "Loading guide…", progress: nil),
]

private struct RowsPreview: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(previewRows.enumerated()), id: \.offset) { index, row in
                Browse.ChannelRow(
                    number: ChannelNumber(major: 101 + index), name: row.name, detail: row.detail, progress: row.progress,
                    hasCatchUp: index == 0,
                    isPlaying: index == 1, select: {}
                ) {
                    Browse.Initials(text: row.initials, isSelected: index == 1)
                }
            }
        }
        .padding(8)
        .background(Palette.ground)
    }
}

#Preview("Channel rows, iPhone") {
    RowsPreview()
        .frame(width: 390)
}

#Preview("Channel rows, iPad") {
    RowsPreview()
        .environment(\.browseMetrics, .regular)
        .frame(width: 352)
}

#Preview("Favorite menu items") {
    VStack(alignment: .leading, spacing: 12) {
        Browse.FavoriteMenuButton(isFavorite: false) {}
        Browse.FavoriteMenuButton(isFavorite: true) {}
    }
    .padding()
    .foregroundStyle(Palette.text)
    .background(Palette.ground)
}
