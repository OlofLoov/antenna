#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The offer for a request that waited in iCloud, over the first screen
    /// once any "Who's watching?" choice is made (`TV-FromIPhone-Offer`,
    /// play-on-apple-tv/the-tv-offers-a-waiting-request). Play has focus
    /// when it appears; Menu or Back closes it as Not now. It stays until the
    /// viewer chooses.
    struct ShellPlayOffer: View {
        /// The picture beside the words.
        enum Art {
            case logo(URL?)
            case poster(URL?)
        }

        let request: PlayRequest
        let art: Art
        let play: () -> Void
        let notNow: () -> Void
        @Environment(\.locale) private var locale
        @FocusState private var focused: Target?

        enum Target: Hashable {
            case play, notNow
        }

        var body: some View {
            FromDeviceOffer(
                eyebrow: PlayOnText.from(request.senderName, locale: locale), title: request.displayTitle,
                facts: PlayOnText.offerFacts(request, locale: locale)
            ) {
                picture
            } buttons: {
                Button("Play", systemImage: "play.fill", action: play)
                    .primaryActionStyle()
                    .focused($focused, equals: .play)
                    .accessibilityIdentifier("playOn.offer.play")
                Button("Not now", action: notNow)
                    .secondaryActionStyle()
                    .focused($focused, equals: .notNow)
                    .accessibilityIdentifier("playOn.offer.notNow")
            }
            .focusSection()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onExitCommand(perform: notNow)
            .defaultFocus($focused, .play)
            .task { focused = .play }
        }

        @ViewBuilder private var picture: some View {
            let initials = Channel.initials(for: request.displayTitle)
            switch art {
            case .logo(let url):
                ZStack {
                    FromDeviceOfferTile(initials: "")
                    LogoImage(url: url) { FromDeviceOfferTile(initials: initials) }
                        .padding(24)
                }
            case .poster(let url):
                ShelfView.PosterArt(name: request.displayTitle, url: url)
            }
        }
    }
#endif
