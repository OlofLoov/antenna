import AntennaCore
import SwiftUI

extension TitlePage {
    /// "Cast and crew": every name the provider sent, at most 15, as chips
    /// that open the person's page (browse-by-person/pick-someone-in-the-cast).
    /// The cast first in the provider's order, then the directors with a
    /// muted "Director". Absent when the provider sent no names. One focus
    /// section on Apple TV, so Down from the buttons lands on the first name.
    struct CastChips: View {
        let type: Sizes
        @Environment(\.titlePage) private var page
        @FocusState private var focused: String?

        var body: some View {
            if let page, !page.state.chips.isEmpty {
                VStack(alignment: .leading, spacing: type.spacing / 2) {
                    Text("Cast and crew")
                        .font(.system(size: type.meta))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityAddTraits(.isHeader)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            HStack(spacing: type.spacing * 0.8) {
                                ForEach(Array(page.state.chips.enumerated()), id: \.element.id) { index, chip in
                                    Chip(type: type, chip: chip) { page.actions.openPerson(chip) }
                                        .focused($focused, equals: chip.id)
                                        .id(chip.id)
                                        .accessibilityIdentifier("title.cast.\(index)")
                                }
                            }
                            .padding(.vertical, type.spacing / 2)
                        }
                        .scrollIndicators(.hidden)
                        .scrollClipDisabled()
                        .task(id: page.state.returningChip) {
                            // Back from the person's page, the chip that opened it is in view and focused.
                            guard let chip = page.state.returningChip else { return }
                            proxy.scrollTo(chip)
                            await Task.yield()
                            focused = chip
                            page.actions.restored()
                        }
                    }
                }
                #if os(tvOS)
                    .focusSection()
                #endif
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("title.cast")
            }
        }
    }

    /// One name, a 44 pt capsule; the lifted white card when focused on Apple TV.
    struct Chip: View {
        let type: Sizes
        let chip: CastChip
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                HStack(spacing: type.chipGap) {
                    // Provider text: never translated, laid out in its own script's direction.
                    Text(verbatim: chip.name.display)
                        .lineLimit(1)
                    if chip.role == .director {
                        Text("Director")
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: type.chip))
                .padding(.horizontal, type.chip * 1.1)
                .frame(minHeight: max(44, type.chipHeight))
                .contentShape(Capsule())
            }
            .buttonStyle(ChipStyle(height: max(44, type.chipHeight)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chip.role == .director ? Text("\(chip.name.display), Director") : Text(verbatim: chip.name.display))
            .accessibilityAddTraits(.isButton)
        }
    }

    private struct ChipStyle: ButtonStyle {
        let height: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            ChipLabel(label: configuration.label, height: height, isPressed: configuration.isPressed)
        }
    }

    private struct ChipLabel<Label: View>: View {
        let label: Label
        let height: CGFloat
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .background {
                    Capsule()
                        .fill(isFocused ? Palette.focus : Palette.surface(0.08))
                        .frame(height: height)
                }
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .scaleEffect(isFocused ? 1.06 : 1)
                .opacity(isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}
