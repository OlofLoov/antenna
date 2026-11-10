#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The info bar for the channel `ZapBarModel` describes, along the bottom
    /// of the full-screen picture. Loads the channel's logo and shows its
    /// initials until it arrives.
    struct ZapBarView: View {
        let channel: Channel

        var body: some View {
            ZapBar.Bar {
                ZapBar.ChannelIdentity(number: channel.number, name: channel.name) {
                    logo
                }
            } nowPlaying: {
                EmptyView()
            } status: {
                EmptyView()
            }
            .accessibilityLabel(channel.number.map { "\($0) \(channel.name)" } ?? channel.name)
        }

        @ViewBuilder private var logo: some View {
            let initials = ZapBar.Initials(text: Channel.initials(for: channel.name))
            if let url = channel.logoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
    }
#endif
