import AntennaCore
import SwiftUI

/// What the Apple TV preview shows for the title the highlight rested on
/// (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
struct PreviewContext: Equatable {
    var text: BannerText
    /// The backdrop, else the poster, or nil while the info call is out and
    /// the picture already shown stays.
    var art: BannerArt?
    /// True when there is no picture to show at all: the picture fades to
    /// the ground color instead of keeping the previous title's.
    var bare = false
}

extension EnvironmentValues {
    /// Set by the Apple TV Movies and Series screen around the preview.
    @Entry var shelfPreview: PreviewContext?
}

/// The preview at the top of Movies and Series on Apple TV, one arrangement
/// per board (`TV-Movies-Preview`, `TV-Movies-Preview-Loading`,
/// `TV-Movies-Preview-Poster-Only`). It has no buttons and never takes focus.
enum ShelfPreview {
    /// The preview's height. The focused row's header sits 16 pt under it.
    static let height: CGFloat = 520

    /// The picture full width 520 pt tall, the banner's hero scrim,
    /// a fade to the ground over the last 140 pt, and the copy from x 64,
    /// y 150.
    struct Television: View {
        @Environment(\.shelfPreview) private var preview
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            ZStack(alignment: .topLeading) {
                Picture(art: preview?.art, bare: preview?.bare ?? false)
                    .frame(height: ShelfPreview.height)
                    .frame(maxWidth: .infinity)
                HeroScrim(copyEnd: 0.5).frame(height: ShelfPreview.height)
                LinearGradient(colors: [.clear, Palette.ground], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                if let text = preview?.text {
                    Copy(text: text)
                        .frame(width: 880, alignment: .leading)
                        .padding(.leading, 64)
                        .padding(.top, 150)
                        .animation(ShelfBanner.crossfade, value: text)
                }
            }
            .frame(height: ShelfPreview.height, alignment: .top)
            .clipped()
            .allowsHitTesting(false)
            .environment(\.shelfBanner, preview.map { BannerContext.still(text: $0.text, art: $0.art) })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).preview")
        }
    }

    /// The category, the name, the banner's facts and three lines of plot.
    private struct Copy: View {
        let text: BannerText
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                if !text.eyebrow.isEmpty {
                    Text(text.eyebrow.uppercased())
                        .font(.boardStyle(ShelfBanner.Sizes.tv.eyebrow, weight: .semibold))
                        .letterSpacing(2)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
                Text(text.title)
                    .font(.boardStyle(56, weight: .heavy))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(prefix).preview.title")
                ShelfBanner.Facts(type: .tv)
                    .accessibilityIdentifier("\(prefix).preview.facts")
                ShelfBanner.Description(type: .tv, lines: 3)
                    .frame(maxWidth: 880, alignment: .leading)
                    .accessibilityIdentifier("\(prefix).preview.plot")
            }
        }
    }

    /// The banner's picture rules: it keeps the picture it shows until the
    /// next has loaded, then fades across. With `bare` it fades to the
    /// ground color.
    private struct Picture: View {
        let art: BannerArt?
        let bare: Bool
        @Environment(\.posterLoader) private var loader
        @State private var shown: ShelfBanner.Art.Shown?

        private struct Want: Hashable {
            var art: BannerArt?
            var bare: Bool
        }

        var body: some View {
            Palette.ground
                .overlay {
                    if let shown {
                        ShelfBanner.Picture(shown: shown)
                            .id(shown.art)
                            .transition(.opacity)
                    }
                }
                .clipped()
                .accessibilityHidden(true)
                .task(id: Want(art: art, bare: bare)) {
                    if bare {
                        withAnimation(ShelfBanner.crossfade) { shown = nil }
                        return
                    }
                    guard let art, art != shown?.art else { return }
                    let image = await loader?.load(art.url, nil)?.image
                    guard !Task.isCancelled else { return }
                    withAnimation(ShelfBanner.crossfade) { shown = .init(art: art, image: image) }
                }
        }
    }
}

extension BannerContext {
    /// A banner context with no actions, so the preview can draw the
    /// banner's facts and plot.
    static func still(text: BannerText, art: BannerArt?) -> BannerContext {
        BannerContext(
            state: .init(text: text, art: art, isOnMyList: false, index: 0, count: 1),
            actions: .init(play: {}, moreInfo: {}, toggleMyList: {}, page: { _ in }, show: { _ in }, interacting: { _ in }))
    }
}

extension PreviewContext {
    /// Quiet Engines in Thriller, for previews. `loading` leaves out the
    /// facts and plot, as before the info call answers.
    static func preview(art: BannerArt?, loading: Bool = false) -> PreviewContext {
        let title = ShelfTitle(
            id: "xtream#preview#vod#5", kind: .movie, sourceID: ShelfFixtures.source, name: "Quiet Engines", category: "Thriller")
        let details = ShelfDetails(
            year: 2023, duration: 114 * 60,
            plot: "A night-shift mechanic finds a stolen prototype in a car left at her garage, and the people who want it back "
                + "know where she lives.",
            ageRating: "15")
        return PreviewContext(text: BannerText(preview: title, details: loading ? nil : details), art: art)
    }
}

#Preview("Preview, Apple TV, backdrop", traits: .fixedLayout(width: 1920, height: 520)) {
    ShelfPreview.Television()
        .environment(\.shelfPreview, .preview(art: .backdrop(PreviewArt.address)))
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.backdrop))
        .background(Palette.ground)
}

#Preview("Preview, Apple TV, loading", traits: .fixedLayout(width: 1920, height: 520)) {
    ShelfPreview.Television()
        .environment(\.shelfPreview, .preview(art: .backdrop(PreviewArt.address), loading: true))
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.backdrop))
        .background(Palette.ground)
}

#Preview("Preview, Apple TV, poster only", traits: .fixedLayout(width: 1920, height: 520)) {
    ShelfPreview.Television()
        .environment(\.shelfPreview, .preview(art: .poster(PreviewArt.address)))
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
        .background(Palette.ground)
}
