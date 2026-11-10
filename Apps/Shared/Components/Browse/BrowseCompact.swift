import SwiftUI

extension Browse {
    /// The horizontally scrolling group chips under the now-playing line on
    /// iPhone (`iPhone`, "Group chips").
    struct Chips<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            ScrollView(.horizontal) {
                HStack(spacing: 8) { content }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
            }
            .scrollIndicators(.hidden)
        }
    }

    /// One group chip; the open group is filled white.
    struct Chip: View {
        let title: String
        let isSelected: Bool
        let select: () -> Void
        @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.system(size: size, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(ChipStyle(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private struct ChipStyle: ButtonStyle {
        let isSelected: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isSelected ? Palette.ground : Palette.text)
                .background {
                    Capsule()
                        .fill(isSelected ? Palette.focus : Palette.surface(0.08))
                        .padding(.vertical, 6)
                }
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }

    /// The line under the picture on iPhone: the channel's tile, the
    /// programme on now, and a muted line with the number, name, times and
    /// what comes next (`iPhone`, "Now playing"). Trailing holds the star.
    struct NowPlaying<Logo: View, Trailing: View>: View {
        let title: String
        let detail: String
        @ViewBuilder var logo: Logo
        @ViewBuilder var trailing: Trailing

        var body: some View {
            HStack(spacing: 12) {
                logo
                    .frame(width: 56, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("browse.nowPlaying")
                trailing
            }
            .foregroundStyle(Palette.text)
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
            }
        }
    }
}

#Preview("Group chips") {
    Browse.Chips {
        Browse.Chip(title: "Favorites", isSelected: false) {}
        Browse.Chip(title: "All channels", isSelected: false) {}
        Browse.Chip(title: "Sport", isSelected: true) {}
        Browse.Chip(title: "News", isSelected: false) {}
        Browse.Chip(title: "Documentary", isSelected: false) {}
    }
    .frame(width: 390)
    .background(Palette.ground)
}

#Preview("Now playing") {
    Browse.NowPlaying(
        title: "Premier League: Arsenal v Liverpool", detail: "104 Sport One · 20:00 – 22:00 · Next: Match of the Day"
    ) {
        Browse.Initials(text: "S1", isSelected: true)
    } trailing: {
        EmptyView()
    }
    .frame(width: 390)
    .background(Palette.ground)
}
