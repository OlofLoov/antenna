import AntennaCore
import SwiftUI

/// The Next episode button and the Up next card over the end of an episode
/// (up-next capability; `TV-Title-Player-NextButton`, `TV-Title-Player-UpNext`,
/// `TV-Title-Player-StillWatching`, `iPhone-Title-Player-UpNext`,
/// `iPad-Title-Player-UpNext`). They take values and closures; the player
/// decides when they show and where focus goes.
enum NextEpisode {
    /// What the card says about the next episode.
    struct Content: Equatable {
        /// "S2 E5 · The Long Night".
        var title: String
        /// "Next episode in 7" or "Still watching?".
        var heading: String
        /// What VoiceOver reads for the card.
        var spoken: String
        var picture: URL?
        /// Shown on the tile when there is no picture.
        var number: Int?
    }

    struct Sizes {
        var width: CGFloat
        var padding: CGFloat
        var corner: CGFloat
        var picture: CGSize
        var pictureCorner: CGFloat
        var heading: Font
        var title: Font
        var number: CGFloat
        var spacing: CGFloat

        #if os(tvOS)
            /// `TV-Title-Player-UpNext`: 640 pt wide, a 240 x 135 picture.
            static let current = Sizes(
                width: 640, padding: 32, corner: 28, picture: CGSize(width: 240, height: 135), pictureCorner: 14, heading: .callout,
                title: .headline, number: 32, spacing: 24)
        #else
            /// `iPad-Title-Player-UpNext`; the iPhone card is the same at 300 pt.
            static let current = Sizes(
                width: 340, padding: 14, corner: 20, picture: CGSize(width: 108, height: 61), pictureCorner: 10, heading: .footnote,
                title: .headline, number: 15, spacing: 12)
        #endif
    }

    /// "Next episode" with a forward glyph, in the corner from 60 seconds
    /// before the end (up-next/next-episode-near-the-end).
    struct Button: View {
        let action: () -> Void

        var body: some View {
            SwiftUI.Button(action: action) {
                Label(UpNextText.button(), systemImage: "forward.end.fill")
                    .font(.headline)
                    #if os(tvOS)
                        .padding(.horizontal, 12)
                    #endif
            }
            #if os(tvOS)
                .buttonBorderShape(.capsule)
            #else
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            #endif
            .accessibilityIdentifier("upNext.button")
        }
    }

    /// The card: the next episode's picture, the countdown or the
    /// question, its code and title, and the buttons under them
    /// (up-next/up-next-counts-down).
    struct Card<Actions: View>: View {
        let content: Content
        @ViewBuilder var actions: Actions
        private let sizes = Sizes.current

        var body: some View {
            VStack(alignment: .leading, spacing: sizes.spacing) {
                HStack(spacing: sizes.spacing) {
                    Picture(url: content.picture, number: content.number, sizes: sizes)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.heading)
                            .font(sizes.heading)
                            .foregroundStyle(Palette.textMuted)
                            .monospacedDigit()
                            .accessibilityIdentifier("upNext.countdown")
                        Text(content.title)
                            .font(sizes.title)
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                            .accessibilityIdentifier("upNext.title")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(content.spoken)
                    .accessibilityIdentifier("upNext.card")
                }
                HStack(spacing: 10) {
                    actions
                }
            }
            .padding(sizes.padding)
            .frame(width: sizes.width, alignment: .leading)
            .background(Palette.scrimTint.opacity(0.88), in: RoundedRectangle(cornerRadius: sizes.corner, style: .continuous))
            .accessibilityElement(children: .contain)
        }
    }

    /// Play now or Keep watching, filling the card's width.
    struct PlayNow: View {
        let title: String
        let action: () -> Void

        var body: some View {
            SwiftUI.Button(action: action) {
                Label(title, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            #if !os(tvOS)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            #endif
            .accessibilityIdentifier("upNext.playNow")
        }
    }

    #if !os(tvOS)
        /// Cancel on iPhone, iPad and Mac; Escape presses it.
        struct Cancel: View {
            let action: () -> Void

            var body: some View {
                SwiftUI.Button("Cancel", action: action)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("upNext.cancel")
            }
        }
    #endif

    /// The episode's picture, or its number on the placeholder.
    private struct Picture: View {
        let url: URL?
        let number: Int?
        let sizes: Sizes
        @Environment(\.posterLoader) private var loader
        @State private var poster: Poster?

        var body: some View {
            FilledArt(image: poster?.image, background: TitlePage.placeholder) {
                if let number {
                    Text("\(number)")
                        .font(.boardStyle(sizes.number, weight: .bold))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .frame(width: sizes.picture.width, height: sizes.picture.height)
            .clipShape(RoundedRectangle(cornerRadius: sizes.pictureCorner, style: .continuous))
            .accessibilityHidden(true)
            .task(id: url) {
                poster = nil
                guard let url, let loader else { return }
                poster = await loader.load(url)
            }
        }
    }
}

private let previewContent = NextEpisode.Content(
    title: "S2 E5 · The Long Night", heading: "Next episode in 7",
    spoken: "Up next, Season 2 Episode 5, The Long Night, next episode in 7 seconds", picture: nil, number: 5)

#Preview("Next episode button", traits: .fixedLayout(width: 500, height: 200)) {
    NextEpisode.Button {}
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.2))
}

#Preview("Up next card, counting down", traits: .fixedLayout(width: 900, height: 400)) {
    NextEpisode.Card(content: previewContent) {
        NextEpisode.PlayNow(title: UpNextText.playNow()) {}
        #if !os(tvOS)
            NextEpisode.Cancel {}
        #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.2))
}

#Preview("Up next card, still watching", traits: .fixedLayout(width: 900, height: 400)) {
    var asking = previewContent
    asking.heading = UpNextText.stillWatching()
    return NextEpisode.Card(content: asking) {
        NextEpisode.PlayNow(title: UpNextText.keepWatching()) {}
        #if !os(tvOS)
            NextEpisode.Cancel {}
        #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.2))
}
