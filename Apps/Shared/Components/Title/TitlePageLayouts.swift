#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    extension TitlePage {
        /// `iPhone-Title` and `iPhone-Series`: the backdrop whole in a 16:9
        /// area under the status bar with Back over it, then the copy, the buttons and what the screen adds below,
        /// such as the episodes. The tab bar stays.
        struct Phone<Below: View>: View {
            /// 4 for a movie, 2 for a series.
            let plotLines: Int
            @ViewBuilder var below: Below
            @Environment(\.titlePage) private var page

            var body: some View {
                let type = Sizes.phone
                Reveal(mark: 96) {
                    BackButton().padding(.leading, 8)
                } content: {
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Backdrop(
                                    poster: CGSize(width: 140, height: 210),
                                    insets: EdgeInsets(top: proxy.safeAreaInsets.top, leading: 0, bottom: Self.fade, trailing: 0),
                                    alignment: .center, margin: 12
                                )
                                .frame(height: artHeight(width: proxy.size.width, top: proxy.safeAreaInsets.top))
                                .overlay(alignment: .bottom) { scrim(height: Self.fade) }
                                .overlay(alignment: .topLeading) {
                                    BackButton().padding(.top, proxy.safeAreaInsets.top).padding(.leading, 8)
                                }
                                VStack(alignment: .leading, spacing: type.spacing) {
                                    Eyebrow(type: type)
                                    Name(type: type)
                                    Meta(type: type)
                                    Plot(type: type, lines: plotLines)
                                    // Play across the width, then My list,
                                    // Trailer and Play on in words under it,
                                    // Play on on a row of its own when they do not fit.
                                    PlayButton(type: type)
                                        .padding(.top, 4)
                                    ViewThatFits(in: .horizontal) {
                                        HStack(spacing: type.spacing) {
                                            MyListButton(type: type).fixedSize()
                                            TrailerButton(type: type).fixedSize()
                                            PlayOnButton(type: type).fixedSize()
                                        }
                                        VStack(alignment: .leading, spacing: type.spacing) {
                                            HStack(spacing: type.spacing) {
                                                MyListButton(type: type).fixedSize()
                                                TrailerButton(type: type).fixedSize()
                                            }
                                            PlayOnButton(type: type).fixedSize()
                                        }
                                    }
                                    Progress(type: type)
                                    Scores(type: type)
                                    Problem(type: type)
                                    CastChips(type: type)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("title.root")
                                below
                                    .padding(.top, 20)
                            }
                            .padding(.bottom, 24)
                        }
                        .ignoresSafeArea(edges: .top)
                    }
                    .background(Palette.ground)
                }
            }

            /// The band under the picture where its blurred copy fades into
            /// the ground, so the scrim covers none of the picture.
            private static var fade: CGFloat { 24 }

            /// A 16:9 picture area under the status bar and the fade band
            /// below it, taller when only the poster shows.
            private func artHeight(width: CGFloat, top: CGFloat) -> CGFloat {
                guard page?.state.metadata.backdropURL != nil else { return top + 250 }
                return top + TitleArtPlacement.phoneArea(width: width, top: top).height + Self.fade
            }
        }

        /// `iPad-Title` and `iPad-Series`: the toolbar's Back, the backdrop
        /// card, 16:9 for its width between 380 and 560 tall, with the copy
        /// and buttons over the hero scrim, then the
        /// description, cast and director and what the screen adds below.
        /// The sidebar is the window's.
        struct Pad<Below: View>: View {
            /// 5 for a movie, 2 for a series.
            let plotLines: Int
            @ViewBuilder var below: Below

            var body: some View {
                let type = Sizes.pad
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            ToolbarBack()
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 24))
                        Reveal(mark: 112) {
                            EmptyView()
                        } content: {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    ZStack(alignment: .bottomLeading) {
                                        Backdrop(poster: CGSize(width: 160, height: 240))
                                        HeroScrim(copyEnd: 0.6)
                                        VStack(alignment: .leading, spacing: type.spacing) {
                                            Eyebrow(type: type)
                                            Name(type: type)
                                            Meta(type: type)
                                            HStack(spacing: type.spacing) {
                                                PlayButton(type: type).fixedSize()
                                                MyListButton(type: type).fixedSize()
                                                TrailerButton(type: type).fixedSize()
                                                PlayOnButton(type: type).fixedSize()
                                            }
                                            .padding(.top, 4)
                                            Progress(type: type)
                                            Scores(type: type)
                                        }
                                        .frame(maxWidth: 520, alignment: .leading)
                                        .padding(28)
                                    }
                                    .frame(height: TitleArtPlacement.cardHeight(width: proxy.size.width - 48))
                                    .clipShape(cornerShape(.large))
                                    VStack(alignment: .leading, spacing: type.spacing) {
                                        Problem(type: type)
                                        Plot(type: type, lines: plotLines)
                                        CastChips(type: type)
                                    }
                                    .frame(maxWidth: 720, alignment: .leading)
                                }
                                .padding(.horizontal, 24)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("title.root")
                                below
                                    .padding(.top, 20)
                                    .padding(.bottom, 24)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .background(Palette.ground)
            }
        }
    }

    extension TitlePage {
        /// The chevron back to the section, a glass circle over the art
        /// (design-system/liquid-glass-stays-on-the-navigation-layer).
        struct BackButton: View {
            @Environment(\.titlePage) private var page

            var body: some View {
                Button {
                    page?.actions.back()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.boardStyle(18, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Back to \(page?.state.section ?? "the section")")
                .accessibilityIdentifier("title.back")
            }
        }

        /// "‹ Movies" in the iPad and Mac toolbar, a 44 pt target.
        struct ToolbarBack: View {
            @Environment(\.accent) private var accent
            @Environment(\.titlePage) private var page

            var body: some View {
                Button {
                    page?.actions.back()
                } label: {
                    Label(page?.state.section ?? "Back", systemImage: "chevron.backward")
                        .font(.boardStyle(17, weight: .semibold))
                        .foregroundStyle(accent.color)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Back to \(page?.state.section ?? "the section")")
                .accessibilityIdentifier("title.back")
            }
        }
    }

    private func scrim(height: CGFloat) -> some View {
        LinearGradient(colors: [Palette.ground.opacity(0), Palette.ground], startPoint: .top, endPoint: .bottom)
            .frame(height: height)
            .accessibilityHidden(true)
    }

    #Preview("Movie, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.full, play: TitlePreviewFixtures.resume))
    }

    #Preview("Missing details, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.sparse, trailer: false))
    }

    #Preview("Could not load details, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(
                \.titlePage,
                .preview(TitleMetadata(title: TitlePreviewFixtures.movie), problem: "Could not load details", trailer: false))
    }

    #Preview("Scores, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.scored, trailer: false))
    }

    #Preview("Sample scores, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.sample, trailer: false))
    }

    #Preview("Scores, iPad", traits: .fixedLayout(width: 914, height: 1000)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.scored, play: TitlePreviewFixtures.resume))
            .environment(\.shelfMetrics, .pad)
    }

    #Preview("Movie, iPad", traits: .fixedLayout(width: 914, height: 1000)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.full, play: TitlePreviewFixtures.resume, onMyList: true))
            .environment(\.shelfMetrics, .pad)
    }

    #Preview("16:9 backdrop, iPhone", traits: .fixedLayout(width: 402, height: 874)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.withBackdrop))
            .environment(\.posterLoader, PreviewArt.loader(PreviewArt.wideSquare))
    }

    #Preview("Poster as backdrop, iPhone", traits: .fixedLayout(width: 402, height: 874)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.withBackdrop))
            .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallSquare))
    }

    #Preview("16:9 backdrop, iPad", traits: .fixedLayout(width: 914, height: 1000)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.withBackdrop))
            .environment(\.posterLoader, PreviewArt.loader(PreviewArt.wideSquare))
            .environment(\.shelfMetrics, .pad)
    }

    #Preview("Poster as backdrop, iPad", traits: .fixedLayout(width: 914, height: 1000)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.withBackdrop))
            .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallSquare))
            .environment(\.shelfMetrics, .pad)
    }

    #Preview("16:9 backdrop in a wide window, Mac", traits: .fixedLayout(width: 1400, height: 900)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.withBackdrop))
            .environment(\.posterLoader, PreviewArt.loader(PreviewArt.wideSquare))
            .environment(\.shelfMetrics, .pad)
    }
#endif
