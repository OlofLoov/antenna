import AntennaCore
import SwiftUI

#if os(iOS) || os(macOS)
    extension ShelfBanner {
        /// `iPhone-Movies`: the art fills the top 520 pt with `top` over it
        /// (the Movies | Series switch, search and genre chips), and the copy
        /// and buttons sit on a scrim at its foot. A swipe pages it.
        struct Phone<Top: View>: View {
            @ViewBuilder var top: Top
            @Environment(\.shelfBanner) private var banner
            @Environment(\.shelfPrefix) private var prefix

            var body: some View {
                ZStack(alignment: .bottom) {
                    Art()
                        .frame(height: 520)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    VStack(alignment: .leading, spacing: Sizes.phone.spacing) {
                        Eyebrow(type: .phone)
                        Title(type: .phone)
                        Facts(type: .phone)
                        Description(type: .phone, lines: 2)
                        HStack(spacing: 8) {
                            PlayButton(type: .phone)
                            InfoButton(type: .phone, title: "Info")
                                .fixedSize()
                            MyListButton(type: .phone)
                        }
                        .padding(.top, 6)
                        Dots(size: 5)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(EdgeInsets(top: 18, leading: 16, bottom: 4, trailing: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(ShelfBanner.crossfade, value: banner?.state.text)
                    .background(Palette.ground.opacity(0.78))
                }
                .frame(height: 520)
                .overlay(alignment: .top) { top }
                .contentShape(Rectangle())
                .gesture(Swipe.gesture(banner))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(prefix).hero")
            }
        }

        /// `iPad-Movies`: a 330 pt rounded card with the copy on a scrim to the
        /// left and the dots at the bottom right. The pointer over it or a
        /// finger on it holds the title; a swipe pages it.
        struct Pad: View {
            @Environment(\.shelfBanner) private var banner
            @Environment(\.shelfPrefix) private var prefix

            var body: some View {
                ZStack(alignment: .topLeading) {
                    Art()
                    Palette.ground.opacity(0.72).frame(width: 560)
                    VStack(alignment: .leading, spacing: Sizes.pad.spacing) {
                        Eyebrow(type: .pad)
                        Title(type: .pad)
                        Facts(type: .pad)
                        Description(type: .pad, lines: 3)
                        HStack(spacing: 10) {
                            PlayButton(type: .pad)
                                .fixedSize()
                            InfoButton(type: .pad, title: "More info")
                                .fixedSize()
                            MyListButton(type: .pad)
                        }
                        .padding(.top, 6)
                    }
                    .frame(width: 480, alignment: .leading)
                    .padding(EdgeInsets(top: 34, leading: 28, bottom: 20, trailing: 0))
                    .animation(ShelfBanner.crossfade, value: banner?.state.text)
                }
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    Dots(size: 5).padding(.trailing, 20).padding(.bottom, 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onHover { inside in banner?.actions.interacting(inside) }
                .gesture(Swipe.gesture(banner))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(prefix).hero")
            }
        }

        /// A sideways swipe of 40 pt or more pages the banner; while the finger
        /// is down the banner holds still.
        enum Swipe {
            @MainActor static func gesture(_ banner: BannerContext?) -> some Gesture {
                DragGesture(minimumDistance: 20)
                    .onChanged { _ in banner?.actions.interacting(true) }
                    .onEnded { value in
                        let distance = value.translation.width
                        if abs(distance) >= 40, abs(distance) > abs(value.translation.height) {
                            banner?.actions.page(distance < 0 ? 1 : -1)
                        }
                        banner?.actions.interacting(false)
                    }
            }
        }
    }
#endif

extension ShelfBanner {
    /// `TV-Movies`: the art full bleed 640 pt tall behind the tab bar, the
    /// copy from 180 pt down on a scrim to the left, the dots at the right.
    /// The screen passes the buttons so it can track their focus.
    struct Television<Buttons: View>: View {
        @ViewBuilder var buttons: Buttons
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            ZStack(alignment: .topLeading) {
                Art()
                    .frame(height: 640)
                    .frame(maxWidth: .infinity)
                Palette.ground.opacity(0.72).frame(width: 1100, height: 640)
                LinearGradient(colors: [.clear, Palette.ground], startPoint: .center, endPoint: .bottom)
                    .frame(height: 640)
                VStack(alignment: .leading, spacing: Sizes.tv.spacing) {
                    Eyebrow(type: .tv)
                    Title(type: .tv)
                    Facts(type: .tv)
                    Description(type: .tv, lines: 3)
                        .frame(maxWidth: 760, alignment: .leading)
                    HStack(spacing: 16) { buttons }
                        .padding(.top, 8)
                }
                .frame(width: 880, alignment: .leading)
                .padding(.leading, 64)
                .padding(.top, 180)
                .animation(ShelfBanner.crossfade, value: banner?.state.text)
            }
            .frame(height: 640, alignment: .top)
            .overlay(alignment: .bottomTrailing) {
                Dots(size: 6).padding(.trailing, 64).padding(.bottom, 20)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).hero")
        }
    }
}

extension BannerContext {
    /// The Long Harbor, first of four, for previews.
    static func preview(onMyList: Bool = false, kind: ShelfTitle.Kind = .movie, art: BannerArt? = nil) -> BannerContext {
        let title = kind == .movie ? ShelfFixtures.movie(0) : ShelfFixtures.series(0)
        let details =
            kind == .movie
            ? ShelfDetails(
                year: 2024, duration: 128 * 60,
                plot: "A harbour pilot uncovers a smuggling ring the night before the port is sold. One tide to decide who gets out.",
                ageRating: "15")
            : ShelfDetails(year: 2021, seasons: 3, plot: "Three sisters run a ferry line through a long winter.")
        return BannerContext(
            state: .init(text: BannerText(title, details: details), art: art, isOnMyList: onMyList, index: 0, count: 4),
            actions: .init(play: {}, moreInfo: {}, toggleMyList: {}, page: { _ in }, show: { _ in }, interacting: { _ in }))
    }
}

#if os(iOS) || os(macOS)
    #Preview("Banner, iPhone", traits: .fixedLayout(width: 390, height: 520)) {
        ShelfBanner.Phone { EmptyView() }
            .environment(\.shelfBanner, .preview())
            .background(Palette.ground)
    }

    #Preview("Banner, iPad, on My list", traits: .fixedLayout(width: 914, height: 330)) {
        ShelfBanner.Pad()
            .environment(\.shelfBanner, .preview(onMyList: true))
            .environment(\.shelfMetrics, .pad)
            .background(Palette.ground)
    }

    // A poster far taller than the banner stays inside the banner's frame,
    // with rows of ground color above and below to show any overflow.
    #Preview("Banner, iPhone, tall poster", traits: .fixedLayout(width: 390, height: 720)) {
        VStack(spacing: 0) {
            ShelfBanner.Phone { EmptyView() }
            Palette.ground.frame(height: 200)
        }
        .environment(\.shelfBanner, .preview(art: .poster(PreviewArt.address)))
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
        .background(Palette.ground)
    }

    #Preview("Banner, iPad, tall poster", traits: .fixedLayout(width: 914, height: 530)) {
        VStack(spacing: 0) {
            Palette.ground.frame(height: 100)
            ShelfBanner.Pad()
            Palette.ground.frame(height: 100)
        }
        .environment(\.shelfBanner, .preview(art: .poster(PreviewArt.address)))
        .environment(\.shelfMetrics, .pad)
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
        .background(Palette.ground)
    }

    #Preview("Banner, iPad, series", traits: .fixedLayout(width: 914, height: 330)) {
        ShelfBanner.Pad()
            .environment(\.shelfBanner, .preview(kind: .series))
            .environment(\.shelfPrefix, "series")
            .background(Palette.ground)
    }

#endif

#Preview("Banner, Apple TV", traits: .fixedLayout(width: 1920, height: 640)) {
    ShelfBanner.Television {
        ShelfBanner.PlayButton(type: .tv).fixedSize()
        ShelfBanner.InfoButton(type: .tv, title: "More info").fixedSize()
        ShelfBanner.MyListButton(type: .tv)
    }
    .environment(\.shelfBanner, .preview())
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}

#Preview("Banner, Apple TV, tall poster", traits: .fixedLayout(width: 1920, height: 1040)) {
    VStack(spacing: 0) {
        ShelfBanner.Television {
            ShelfBanner.PlayButton(type: .tv).fixedSize()
            ShelfBanner.InfoButton(type: .tv, title: "More info").fixedSize()
            ShelfBanner.MyListButton(type: .tv)
        }
        Palette.ground.frame(height: 400)
    }
    .environment(\.shelfBanner, .preview(art: .poster(PreviewArt.address)))
    .environment(\.shelfMetrics, .tv)
    .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
    .background(Palette.ground)
}

#Preview("Banner, Apple TV, backdrop", traits: .fixedLayout(width: 1920, height: 640)) {
    ShelfBanner.Television {
        ShelfBanner.PlayButton(type: .tv).fixedSize()
        ShelfBanner.InfoButton(type: .tv, title: "More info").fixedSize()
        ShelfBanner.MyListButton(type: .tv)
    }
    .environment(\.shelfBanner, .preview(art: .backdrop(PreviewArt.address)))
    .environment(\.shelfMetrics, .tv)
    .environment(\.posterLoader, PreviewArt.loader(PreviewArt.backdrop))
    .background(Palette.ground)
}
