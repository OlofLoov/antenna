import AntennaCore
import SwiftUI

extension ZapBar {
    /// The channel number box at the top left (`TV-ZapBar-PillNoMatch`,
    /// `TV-ZapBar-PillZeros`, `TV-ZapBar-PillNoChannel`): the digits typed
    /// with a cursor and the matching channel's name, or "No channel n" at
    /// the same height so the box does not jump.
    struct NumberBox: View {
        enum Content: Equatable {
            /// The name is nil when nothing matches.
            case typing(digits: String, name: String?)
            case noChannel(String)
        }

        let content: Content
        @Environment(\.locale) private var locale

        var body: some View {
            HStack(spacing: 18) {
                switch content {
                case .typing(let typed, let name):
                    let digits = ChannelNumber.digits(typed, locale: locale)
                    Text("\(digits)\(Text("_").foregroundStyle(Palette.textMuted))")
                        .font(.system(size: 44, weight: .bold).monospacedDigit())
                        .letterSpacing(2)
                        .accessibilityLabel(digits)
                        .accessibilityIdentifier("zapBar.digits")
                    if let name {
                        Text(name)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                            .accessibilityIdentifier("zapBar.match")
                    }
                case .noChannel(let typed):
                    Text("No channel \(ChannelNumber.digits(typed, locale: locale))")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("zapBar.noChannel")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 22)
            .frame(minHeight: 73)
            .background(Palette.scrimTint.opacity(0.82), in: cornerShape(.medium))
            .foregroundStyle(Palette.text)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("zapBar.numberBox")
        }
    }
}

#Preview("Number box, typing a match", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .topLeading) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.NumberBox(content: .typing(digits: "10", name: "Sport Two"))
            .padding(.leading, Metrics.televisionSafeArea.leading)
            .padding(.top, Metrics.televisionSafeArea.top)
    }
}

#Preview("Number box, no channel", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .topLeading) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.NumberBox(content: .noChannel("999"))
            .padding(.leading, Metrics.televisionSafeArea.leading)
            .padding(.top, Metrics.televisionSafeArea.top)
    }
}
