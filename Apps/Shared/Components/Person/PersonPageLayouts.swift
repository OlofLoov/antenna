import AntennaCore
import SwiftUI

extension PersonPageLayout {
    #if os(iOS) || os(macOS)
        /// `iPhone-Person`: Back, the header, the rows and the note, in the
        /// Movies or Series tab with the tab bar kept.
        struct Phone: View {
            var body: some View {
                let type = Sizes.phone
                ScrollView {
                    VStack(alignment: .leading, spacing: type.spacing) {
                        Back(size: 17).padding(.horizontal, 8)
                        Header(type: type)
                        Rows(type: type)
                        Note(type: type)
                    }
                    .padding(.bottom, 24)
                }
                .environment(\.shelfMetrics, .phone)
                .background(Palette.ground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("person.root")
            }
        }

        /// `iPad-Person`: the same parts in the content column; the sidebar is the window's.
        struct Pad: View {
            var body: some View {
                let type = Sizes.pad
                VStack(alignment: .leading, spacing: 0) {
                    Back(size: 17).padding(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 24))
                    ScrollView {
                        VStack(alignment: .leading, spacing: type.spacing) {
                            Header(type: type)
                            Rows(type: type)
                            Note(type: type)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .environment(\.shelfMetrics, .pad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Palette.ground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("person.root")
            }
        }
    #endif

    #if os(tvOS)
        /// `TV-Person`: its own screen with no tab bar. The first poster of
        /// the first row has focus; Menu goes back.
        struct Television: View {
            var body: some View {
                let type = Sizes.tv
                ScrollView {
                    VStack(alignment: .leading, spacing: type.spacing) {
                        Header(type: type)
                        Rows(type: type)
                        Note(type: type)
                    }
                    .padding(.top, 90)
                    .padding(.bottom, 80)
                }
                .scrollClipDisabled()
                .environment(\.shelfMetrics, .tv)
                .background(Palette.ground)
                .ignoresSafeArea()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("person.root")
            }
        }
    #endif
}

#if os(iOS) || os(macOS)
    #Preview("Person, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        PersonPageLayout.Phone()
            .environment(\.personPage, .preview())
    }

    #Preview("Person with the note, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        PersonPageLayout.Phone()
            .environment(
                \.personPage, .preview(rows: [PersonPreviewFixtures.row("movies", "Movies", [ShelfFixtures.movie(0)])], note: true))
    }

    #Preview("Nothing in the sources, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        PersonPageLayout.Phone()
            .environment(\.personPage, .preview(empty: true))
    }

    #Preview("Person, Arabic, iPhone", traits: .fixedLayout(width: 390, height: 844)) {
        PersonPageLayout.Phone()
            .environment(\.personPage, .preview(note: true))
            .previewLanguage(.arabic)
    }

    #Preview("Person, iPad", traits: .fixedLayout(width: 914, height: 834)) {
        PersonPageLayout.Pad()
            .environment(\.personPage, .preview(note: true))
    }
#endif

#if os(tvOS)
    #Preview("Person, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        PersonPageLayout.Television()
            .environment(\.personPage, .preview(note: true))
    }

    #Preview("Nothing in the sources, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        PersonPageLayout.Television()
            .environment(\.personPage, .preview(empty: true))
    }
#endif
