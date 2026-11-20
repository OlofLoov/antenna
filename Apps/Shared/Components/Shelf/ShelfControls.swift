import AntennaCore
import SwiftUI

extension ShelfView {
    /// The iPhone's Movies | Series switch over the banner
    /// (`iPhone-Movies`, `movies.kind`): two glass chips grouped in one
    /// container, since they float over the art. The open kind is glass
    /// prominent, with no fill or stroke of its own
    /// (design-system/liquid-glass-stays-on-the-navigation-layer).
    /// Series never gets a tab of its own on iPhone.
    struct KindSwitch: View {
        let selection: ShelfTitle.Kind
        let select: (ShelfTitle.Kind) -> Void

        var body: some View {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 8) {
                    segment(.movie)
                    segment(.series)
                }
            }
            .fixedSize()
            .controlSize(.large)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("movies.kind")
        }

        private func segment(_ kind: ShelfTitle.Kind) -> some View {
            let selected = kind == selection
            return Button {
                select(kind)
            } label: {
                Text(kind.sectionTitle)
                    .font(.boardStyle(15, weight: .semibold))
            }
            .chipStyle(isPicked: selected, on: .art)
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
