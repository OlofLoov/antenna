import AntennaCore
import SwiftUI

extension ShelfView {
    /// The iPhone's Movies | Series switch over the banner
    /// (`iPhone-Movies`, `movies.kind`): the open kind takes the white fill.
    /// Series never gets a tab of its own on iPhone.
    struct KindSwitch: View {
        let selection: ShelfTitle.Kind
        let select: (ShelfTitle.Kind) -> Void

        var body: some View {
            HStack(spacing: 2) {
                segment(.movie)
                segment(.series)
            }
            .padding(4)
            .frame(height: 44)
            .background(Palette.scrimTint.opacity(0.6), in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("movies.kind")
        }

        private func segment(_ kind: ShelfTitle.Kind) -> some View {
            let selected = kind == selection
            return Button {
                select(kind)
            } label: {
                Text(kind.sectionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Palette.ground : Palette.text)
                    .padding(.horizontal, 18)
                    .frame(maxHeight: .infinity)
                    .background(selected ? Palette.text : .clear, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("movies.kind.\(kind.prefix)")
        }
    }
}

#Preview("Movies | Series switch", traits: .fixedLayout(width: 390, height: 64)) {
    HStack {
        ShelfView.KindSwitch(selection: .movie) { _ in }
        Spacer()
    }
    .padding(10)
    .background(Color(red: 0x22 / 255, green: 0x30 / 255, blue: 0x4A / 255))
}
