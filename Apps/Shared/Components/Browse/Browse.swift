import SwiftUI

/// The Live screen's parts on iPhone, iPad and Mac (live-tv-on-iphone-ipad-mac
/// capability; boards `iPhone`, `iPad` and their states). Sizes come from
/// `Browse.Metrics` in the environment: the screen sets the regular metrics
/// on iPad and Mac and leaves the compact ones on iPhone.
enum Browse {
    static let tile = Color(red: 0x26 / 255, green: 0x34 / 255, blue: 0x4A / 255)
    static let tileSelected = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)
    static let textSecondary = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)
    /// The picture area before anything plays.
    static let picture = Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)

    /// Row and tile sizes, which differ between the iPhone and the iPad boards.
    struct Metrics: Equatable, Sendable {
        var rowHeight: CGFloat
        var tile: CGSize
        var name: CGFloat
        var detail: CGFloat
        var tileText: CGFloat

        /// `iPhone`: 60 pt rows, 52 by 34 tiles.
        static let compact = Metrics(rowHeight: 60, tile: CGSize(width: 52, height: 34), name: 15, detail: 12, tileText: 11)
        /// `iPad`: 64 pt rows, 56 by 36 tiles.
        static let regular = Metrics(rowHeight: 64, tile: CGSize(width: 56, height: 36), name: 16, detail: 13, tileText: 12)
    }

    /// The tile drawn while a logo is missing, loading or failed
    /// (design-system/channels-without-a-logo-show-initials).
    struct Initials: View {
        let text: String
        /// The playing channel's tile takes the brighter placeholder color.
        let isSelected: Bool
        @Environment(\.browseMetrics) private var metrics

        var body: some View {
            ZStack {
                isSelected ? Browse.tileSelected : Browse.tile
                Text(text)
                    .font(.system(size: metrics.tileText, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(isSelected ? Palette.text : Browse.textSecondary)
            }
            .accessibilityHidden(true)
        }
    }

    /// The channel's logo, with the initials tile until it loads.
    struct Logo: View {
        let url: URL?
        let initials: String
        let isSelected: Bool

        var body: some View {
            let tile = Initials(text: initials, isSelected: isSelected)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        tile
                    }
                }
            } else {
                tile
            }
        }
    }

    /// The 3 pt accent bar of a programme on now
    /// (design-system/a-current-programme-always-shows-its-progress).
    struct ProgressBar: View {
        let fraction: Double

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.16))
                    Capsule().fill(Palette.accent)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
    }

    /// The Antenna mark and "Select a channel" in the picture area before
    /// anything plays (live-tv-on-iphone-ipad-mac/sidebar-list-and-picture-side-by-side).
    struct NothingSelected: View {
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 34))
                    .accessibilityHidden(true)
                Text("Select a channel")
                    .font(.subheadline)
            }
            .foregroundStyle(Palette.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("browse.nothingSelected")
        }
    }

    /// The muted line in place of the list when the group has no channels.
    struct EmptyGroup: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("browse.emptyGroup")
        }

        /// What empty Favorites says, naming how a channel becomes a favorite
        /// on this platform (live-tv-on-iphone-ipad-mac/pick-a-group).
        static var noFavorites: String {
            #if os(macOS)
                "No favorites yet. Right-click a channel to add it."
            #else
                "No favorites yet. Touch and hold a channel, or swipe it right, to add it."
            #endif
        }
    }
}

extension View {
    /// The 2 pt ring in the Text color, with no fill, on the row the arrow
    /// keys moved to (`iPad-Focus`). Distinct from the playing row's fill.
    func browseFocusRing(_ shown: Bool) -> some View {
        overlay {
            if shown {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.text, lineWidth: 2)
            }
        }
    }
}

extension EnvironmentValues {
    /// Set by the Live screen: `.regular` on iPad and Mac.
    @Entry var browseMetrics = Browse.Metrics.compact
}

#Preview("Nothing selected") {
    Browse.NothingSelected()
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(width: 390)
}

#Preview("Empty Favorites") {
    Browse.EmptyGroup(text: Browse.EmptyGroup.noFavorites)
        .frame(width: 390, height: 300)
        .background(Palette.ground)
}
