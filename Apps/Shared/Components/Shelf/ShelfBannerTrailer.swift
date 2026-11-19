import SwiftUI

extension ShelfBanner {
    /// "Trailer" with the trailer glyph, the title page's button at the
    /// banner's size, on Apple TV, iPad and Mac. Absent without a trailer
    /// (movies-and-series-browsing/rating-and-trailer-on-the-banner).
    struct TrailerButton: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            if let trailer = banner?.actions.trailer {
                Button(action: trailer) {
                    Label("Trailer", systemImage: "play.rectangle")
                        .font(.boardStyle(type.button, weight: .semibold))
                        .lineLimit(1)
                        .frame(minHeight: type.buttonHeight)
                }
                .secondaryActionStyle()
                .accessibilityIdentifier("\(prefix).hero.trailer")
            }
        }
    }

    /// The trailer glyph alone in a square like My list, for the iPhone's
    /// narrow row of buttons. Absent without a trailer.
    struct TrailerGlyphButton: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            if let trailer = banner?.actions.trailer {
                Button(action: trailer) {
                    Image(systemName: "play.rectangle")
                        .font(.boardStyle(type.button + 2, weight: .bold))
                        .frame(width: type.buttonHeight, height: type.buttonHeight)
                }
                .secondaryActionStyle()
                .accessibilityLabel("Trailer")
                .accessibilityIdentifier("\(prefix).hero.trailer")
            }
        }
    }
}
