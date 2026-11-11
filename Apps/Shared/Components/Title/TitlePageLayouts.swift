#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    extension TitlePage {
        /// `iPhone-Title` and `iPhone-Series`: the backdrop at 16:9 with Back
        /// over it, then the copy, the buttons and what the screen adds below,
        /// such as the episodes. The tab bar stays.
        struct Phone<Below: View>: View {
            /// 4 for a movie, 2 for a series.
            let plotLines: Int
            @ViewBuilder var below: Below
            @Environment(\.titlePage) private var page

            var body: some View {
                let type = Sizes.phone
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Backdrop(poster: CGSize(width: 140, height: 210))
                                .frame(height: artHeight(width: proxy.size.width, top: proxy.safeAreaInsets.top))
                                .overlay(alignment: .bottom) { scrim(height: 80) }
                                .overlay(alignment: .topLeading) {
                                    BackButton().padding(.top, proxy.safeAreaInsets.top).padding(.leading, 8)
                                }
                            VStack(alignment: .leading, spacing: type.spacing) {
                                Eyebrow(type: type)
                                Name(type: type)
                                Meta(type: type)
                                Plot(type: type, lines: plotLines)
                                HStack(spacing: type.spacing) {
                                    PlayButton(type: type)
                                    MyListButton(type: type)
                                    TrailerButton(type: type)
                                }
                                .padding(.top, 4)
                                Progress(type: type)
                                Problem(type: type)
                                Credits(type: type)
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

            /// 16:9 under the status bar, taller when only the poster shows.
            private func artHeight(width: CGFloat, top: CGFloat) -> CGFloat {
                page?.state.metadata.backdropURL == nil ? top + 250 : top + width * 9 / 16
            }
        }

        /// `iPad-Title` and `iPad-Series`: the toolbar's Back, the backdrop
        /// card with the copy and buttons over a left scrim, then the
        /// description, cast and director and what the screen adds below.
        /// The sidebar is the window's.
        struct Pad<Below: View>: View {
            /// 5 for a movie, 2 for a series.
            let plotLines: Int
            @ViewBuilder var below: Below

            var body: some View {
                let type = Sizes.pad
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        ToolbarBack()
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 24))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ZStack(alignment: .bottomLeading) {
                                Backdrop(poster: CGSize(width: 160, height: 240))
                                LinearGradient(
                                    colors: [Palette.scrimTint.opacity(0.92), Palette.scrimTint.opacity(0)], startPoint: .leading,
                                    endPoint: .trailing)
                                VStack(alignment: .leading, spacing: type.spacing) {
                                    Eyebrow(type: type)
                                    Name(type: type)
                                    Meta(type: type)
                                    HStack(spacing: type.spacing) {
                                        PlayButton(type: type).fixedSize()
                                        MyListButton(type: type)
                                        TrailerButton(type: type)
                                    }
                                    .padding(.top, 4)
                                    Progress(type: type)
                                }
                                .frame(maxWidth: 520, alignment: .leading)
                                .padding(28)
                            }
                            .frame(height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: type.spacing) {
                                Problem(type: type)
                                Plot(type: type, lines: plotLines)
                                Credits(type: type)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Palette.ground)
            }
        }
    }

    extension TitlePage {
        /// The chevron back to the section, a 44 pt target.
        struct BackButton: View {
            @Environment(\.titlePage) private var page

            var body: some View {
                Button {
                    page?.actions.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 36, height: 36)
                        .background(Palette.scrimTint.opacity(0.55), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Back to \(page?.state.section ?? "the section")")
                .accessibilityIdentifier("title.back")
            }
        }

        /// "‹ Movies" in the iPad and Mac toolbar, a 44 pt target.
        struct ToolbarBack: View {
            @Environment(\.titlePage) private var page

            var body: some View {
                Button {
                    page?.actions.back()
                } label: {
                    Label(page?.state.section ?? "Back", systemImage: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
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

    #Preview("Loading, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(\.titlePage, .preview(TitleMetadata(title: TitlePreviewFixtures.movie), loading: true, trailer: false))
    }

    #Preview("Could not load details, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        TitlePage.Phone(plotLines: 4) { EmptyView() }
            .environment(
                \.titlePage,
                .preview(TitleMetadata(title: TitlePreviewFixtures.movie), problem: "Could not load details", trailer: false))
    }

    #Preview("Movie, iPad", traits: .fixedLayout(width: 914, height: 1000)) {
        TitlePage.Pad(plotLines: 5) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.full, play: TitlePreviewFixtures.resume, onMyList: true))
            .environment(\.shelfMetrics, .pad)
    }
#endif
