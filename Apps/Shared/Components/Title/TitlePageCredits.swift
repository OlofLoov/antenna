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
                        .font(.boardStyle(type.meta))
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

    /// One name on a bordered capsule, at least 44 pt tall (design-system/controls-use-system-styles).
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
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.boardStyle(type.chip))
                .castChipPadding(type.chip)
                .frame(minHeight: max(44, type.chipHeight))
            }
            .castChipStyle()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chip.role == .director ? Text("\(chip.name.display), Director") : Text(verbatim: chip.name.display))
            .accessibilityAddTraits(.isButton)
        }
    }
}

extension View {
    /// A cast chip on Apple TV is a focus card: a system bordered chip that
    /// opens the person's page, which replaces the title page, keeps focus
    /// from moving into the new page (refresh-visual-design, design.md
    /// decision 12). Elsewhere it is a system chip.
    @ViewBuilder fileprivate func castChipStyle() -> some View {
        #if os(tvOS)
            buttonStyle(FocusCardStyle(.capsule, resting: Palette.surface(0.08)))
        #else
            chipStyle(isPicked: false)
        #endif
    }

    /// The focus card's side padding on Apple TV, which the system chip
    /// draws itself elsewhere.
    @ViewBuilder fileprivate func castChipPadding(_ size: CGFloat) -> some View {
        #if os(tvOS)
            padding(.horizontal, size * 1.1)
        #else
            self
        #endif
    }
}
