import SwiftUI

/// The Apple TV info bar over the full-screen picture
/// (tv-zap-bar-and-number-entry capability; `TV-ZapBar`). A strip 236 tall
/// along the bottom: the channel's identity, then what is on, then the
/// status badges. Compiles on every platform so the snapshot job renders its
/// previews. Never takes focus.
enum ZapBar {
    static let placeholder = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)

    /// The strip. `nowPlaying` and `status` fill the middle and the right.
    struct Bar<Identity: View, NowPlaying: View, Status: View>: View {
        @ViewBuilder var identity: Identity
        @ViewBuilder var nowPlaying: NowPlaying
        @ViewBuilder var status: Status

        var body: some View {
            HStack(alignment: .center, spacing: 40) {
                identity
                    .frame(width: 420, alignment: .leading)
                nowPlaying
                    .frame(maxWidth: .infinity, alignment: .leading)
                status
            }
            .padding(EdgeInsets(top: 32, leading: 64, bottom: 40, trailing: 64))
            .frame(maxWidth: .infinity)
            .frame(height: 236)
            .background(Palette.scrimTint.opacity(0.88))
            .foregroundStyle(Palette.text)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("zapBar.bar")
        }
    }

    /// Logo tile, number, name and the line under it.
    struct ChannelIdentity<Logo: View>: View {
        let number: Int?
        let name: String
        /// The current list and the channel's place in it, as in "Sport · 4 of 42".
        var position: String?
        @ViewBuilder var logo: Logo

        var body: some View {
            HStack(spacing: 24) {
                logo
                    .frame(width: 132, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    if let number {
                        Text(String(number))
                            .font(.system(size: 26).monospacedDigit())
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("zapBar.number")
                    }
                    Text(name)
                        .font(.system(size: 36, weight: .bold))
                        .lineLimit(1)
                        .accessibilityIdentifier("zapBar.name")
                    if let position {
                        Text(position)
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("zapBar.position")
                    }
                }
            }
        }
    }

    /// The tile drawn while a logo is missing, loading or failed
    /// (design-system/channels-without-a-logo-show-initials).
    struct Initials: View {
        let text: String

        var body: some View {
            ZStack {
                ZapBar.placeholder
                Text(text)
                    .font(.system(size: 28, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Palette.text)
            }
        }
    }
}

#Preview("Zap bar, channel only", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .bottom) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.Bar {
            ZapBar.ChannelIdentity(number: 104, name: "Sport One", position: "Sport · 4 of 42") {
                ZapBar.Initials(text: "S1")
            }
        } nowPlaying: {
            EmptyView()
        } status: {
            EmptyView()
        }
    }
}

#Preview("Zap bar, no number and a long name", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .bottom) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.Bar {
            ZapBar.ChannelIdentity(number: nil, name: "Nordic Documentary Channel Extra HD") {
                ZapBar.Initials(text: "NDCE")
            }
        } nowPlaying: {
            EmptyView()
        } status: {
            EmptyView()
        }
    }
}
