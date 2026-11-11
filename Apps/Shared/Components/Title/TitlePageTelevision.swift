#if os(tvOS)
    import AntennaCore
    import SwiftUI

    extension TitlePage {
        /// `TV-Title` and `TV-Series`: the backdrop full bleed, the copy
        /// column on the Movies banner's left edge, Play and My list, then
        /// what the screen adds below, such as the episodes. No tab bar and no
        /// clock. Play takes focus when the page opens; More sits above the
        /// buttons when the description is cut.
        struct Television<Below: View>: View {
            /// 4 for a movie, 2 for a series.
            let plotLines: Int
            /// The backdrop's height: full screen for a movie, the top 520 for a series.
            let artHeight: CGFloat
            @ViewBuilder var below: Below
            @FocusState private var focused: Part?

            enum Part: Hashable { case play }

            var body: some View {
                let type = Sizes.tv
                ZStack(alignment: .topLeading) {
                    Backdrop(poster: CGSize(width: 300, height: 450))
                        .frame(maxWidth: .infinity)
                        .frame(height: artHeight)
                        .overlay {
                            LinearGradient(
                                colors: [Palette.ground.opacity(0.95), Palette.ground.opacity(0.4), .clear], startPoint: .leading,
                                endPoint: .trailing)
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, Palette.ground], startPoint: .top, endPoint: .bottom).frame(height: 240)
                        }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: type.spacing) {
                                Eyebrow(type: type)
                                Name(type: type)
                                Meta(type: type)
                                Plot(type: type, lines: plotLines)
                                Credits(type: type)
                                HStack(spacing: type.spacing) {
                                    PlayButton(type: type)
                                        .fixedSize()
                                        .focused($focused, equals: .play)
                                    MyListButton(type: type)
                                }
                                .padding(.top, 8)
                                Progress(type: type)
                                Problem(type: type)
                            }
                            .frame(maxWidth: 1080, alignment: .leading)
                            .padding(.horizontal, 96)
                            .focusSection()
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("title.root")
                            below
                                .padding(.top, 48)
                        }
                        .padding(.top, 260)
                        .padding(.bottom, 80)
                    }
                    .scrollClipDisabled()
                }
                .background(Palette.ground)
                .ignoresSafeArea()
                .defaultFocus($focused, .play)
            }
        }
    }

    #Preview("Movie, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        TitlePage.Television(plotLines: 4, artHeight: 1080) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.full, play: TitlePreviewFixtures.resume, trailer: false))
            .environment(\.shelfMetrics, .tv)
    }

    #Preview("Missing details, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        TitlePage.Television(plotLines: 4, artHeight: 1080) { EmptyView() }
            .environment(\.titlePage, .preview(TitlePreviewFixtures.sparse, trailer: false))
            .environment(\.shelfMetrics, .tv)
    }
#endif
