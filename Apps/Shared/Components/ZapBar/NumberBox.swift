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

        var body: some View {
            HStack(spacing: 18) {
                switch content {
                case .typing(let digits, let name):
                    Text("\(digits)\(Text("_").foregroundStyle(Palette.textMuted))")
                        .font(.system(size: 44, weight: .bold).monospacedDigit())
                        .tracking(2)
                        .accessibilityLabel(digits)
                        .accessibilityIdentifier("zapBar.digits")
                    if let name {
                        Text(name)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                            .accessibilityIdentifier("zapBar.match")
                    }
                case .noChannel(let digits):
                    Text("No channel \(digits)")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("zapBar.noChannel")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 22)
            .frame(minHeight: 73)
            .background(Palette.scrimTint.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
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
            .padding(.leading, 64)
            .padding(.top, 44)
    }
}

#Preview("Number box, no channel", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .topLeading) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ZapBar.NumberBox(content: .noChannel("999"))
            .padding(.leading, 64)
            .padding(.top, 44)
    }
}
